import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/settings.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/prayer_service.dart';

enum LoadState { loading, ready, needsLocation, error }

/// عدّاد تنازلي يعرف إن كان أحد يراقبه، فيعمل المؤقت كل ثانية فقط عند الحاجة.
class Countdown extends ValueNotifier<Duration> {
  Countdown() : super(Duration.zero);
  VoidCallback? onFirstListener;

  bool get watched => hasListeners;

  @override
  void addListener(VoidCallback listener) {
    final first = !hasListeners;
    super.addListener(listener);
    if (first) onFirstListener?.call();
  }
}

class PrayerController extends ChangeNotifier with WidgetsBindingObserver {
  PrayerController(this._s, this._svc, this._notif, this._loc);
  final AppSettings _s;
  final PrayerService _svc;
  final NotificationService _notif;
  final LocationService _loc;

  LoadState status = LoadState.loading;
  String? error;
  DayTimes today = const {};
  PrayerKind next = PrayerKind.fajr;
  tz.TZDateTime? nextTime;
  tz.TZDateTime? prevTime;
  final remaining = Countdown();
  VoidCallback? onTimesChanged;

  late tz.Location _zone;
  Timer? _timer;
  String _sig = '';
  int _day = 0;
  bool _busy = false;
  bool _foreground = true;
  VoidCallback? _settingsListener;

  static const _locationTtl = Duration(hours: 6);

  String _makeSig() => '${_s.lat}|${_s.lng}|${_s.tzName}|${_s.method}|${_s.madhab}|${_s.notify}|${_s.voice}';
  static int _dayKey(tz.TZDateTime t) => t.year * 10000 + t.month * 100 + t.day;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    remaining.onFirstListener = () => scheduleMicrotask(() {
          if (status == LoadState.ready) {
            _tick();
            _schedule();
          }
        });
    _settingsListener = () {
      if (!_busy && _makeSig() != _sig) refresh();
    };
    _s.addListener(_settingsListener!);
    await refresh();
  }

  bool get _locationStale =>
      DateTime.now().millisecondsSinceEpoch - _s.locStamp > _locationTtl.inMilliseconds;

  /// [relocate] يفرض طلب الموقع الآن؛ وإلا يُستخدم الموقع المحفوظ ما دام حديثًا (6 ساعات).
  Future<void> refresh({bool relocate = false, bool silent = false}) async {
    if (_busy) return;
    _busy = true;
    if (!silent) {
      status = LoadState.loading;
      error = null;
      notifyListeners();
    }
    try {
      if (_s.auto && (relocate || !_s.hasLocation || _locationStale)) {
        try {
          await _locate();
        } catch (_) {
          if (!_s.hasLocation) rethrow;
        }
      }
      if (!_s.hasLocation) {
        status = LoadState.needsLocation;
        error = 'حدد موقعك لعرض أوقات الصلاة.';
        return;
      }
      _load();
      status = LoadState.ready;
      _schedule();
      _scheduleNotifications();
    } on LocationException catch (e) {
      status = LoadState.needsLocation;
      error = e.message;
    } catch (_) {
      status = LoadState.error;
      error = 'تعذر حساب أوقات الصلاة. حاول مرة أخرى.';
    } finally {
      _sig = _makeSig();
      _busy = false;
      notifyListeners();
    }
  }

  /// لا يُغيَّر الموقع المحفوظ إلا إذا انتقل المستخدم فعلًا (> ~5 كم) فلا تُعاد الجدولة بلا داعٍ.
  Future<void> _locate() async {
    final p = await _loc.current();
    final lat = _s.lat, lng = _s.lng;
    final moved = lat == null || lng == null || (p.$1 - lat).abs() > .05 || (p.$2 - lng).abs() > .05;
    if (moved || !_s.auto || _s.place != 'موقعك الحالي') {
      await _s.setLocation(p.$1, p.$2, tz.local.name, 'موقعك الحالي', auto: true);
    } else {
      await _s.prefs.setInt('loc_ts', DateTime.now().millisecondsSinceEpoch);
    }
  }

  void _load() {
    _zone = tz.getLocation(_s.tzName);
    final now = tz.TZDateTime.now(_zone);
    today = _svc.today(_s);
    _day = _dayKey(now);
    _computeNext(now);
    remaining.value = nextTime!.difference(now);
    onTimesChanged?.call();
  }

  void _computeNext(tz.TZDateTime now) {
    tz.TZDateTime? prev;
    for (final k in PrayerKind.values) {
      if (k == PrayerKind.sunrise) continue;
      final t = today[k]!;
      if (t.isAfter(now)) {
        next = k;
        nextTime = t;
        prevTime = prev ?? _svc.compute(_s, -1, loc0: _zone)[PrayerKind.isha];
        return;
      }
      prev = t;
    }
    next = PrayerKind.fajr;
    nextTime = _svc.compute(_s, 1, loc0: _zone)[PrayerKind.fajr];
    prevTime = prev;
  }

  bool isNextKind(PrayerKind k) => nextTime != null && today[k] != null && today[k]!.isAtSameMomentAs(nextTime!);
  bool isPassed(PrayerKind k) => nextTime != null && today[k] != null && today[k]!.isBefore(nextTime!);

  /// مؤقت واحد متكيّف: كل ثانية (مضبوط على حدّ الثانية) فقط إذا كان العدّاد ظاهرًا،
  /// وإلا يستيقظ عند موعد الصلاة القادمة أو منتصف الليل فقط.
  void _schedule() {
    _timer?.cancel();
    if (status != LoadState.ready || nextTime == null || !_foreground) return;
    final now = tz.TZDateTime.now(_zone);
    Duration wait;
    if (remaining.watched) {
      wait = Duration(milliseconds: 1005 - now.millisecond);
    } else {
      final toNext = nextTime!.difference(now);
      final toMidnight = tz.TZDateTime(_zone, now.year, now.month, now.day + 1).difference(now);
      wait = (toNext < toMidnight ? toNext : toMidnight) + const Duration(seconds: 1);
    }
    _timer = Timer(wait, () {
      _tick();
      _schedule();
    });
  }

  void _tick() {
    if (status != LoadState.ready || nextTime == null) return;
    final now = tz.TZDateTime.now(_zone);
    if (_dayKey(now) != _day) {
      _load();
      _scheduleNotifications();
      notifyListeners();
      return;
    }
    if (!nextTime!.isAfter(now)) {
      _computeNext(now);
      notifyListeners();
    }
    final d = nextTime!.difference(now);
    remaining.value = d.isNegative ? Duration.zero : d;
  }

  void _scheduleNotifications() {
    final f = _s.notify ? _notif.ensureScheduled(_s, _svc) : _notif.disable(_s);
    f.catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      _foreground = false;
      _timer?.cancel();
    } else if (s == AppLifecycleState.resumed) {
      _foreground = true;
      if (status == LoadState.ready) {
        _tick();
        _schedule();
        _scheduleNotifications();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_settingsListener != null) _s.removeListener(_settingsListener!);
    remaining.dispose();
    super.dispose();
  }
}
