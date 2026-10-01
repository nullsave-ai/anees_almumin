import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/settings.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';
import '../../services/prayer_service.dart';

enum LoadState { loading, ready, needsLocation, error }

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
  final remaining = ValueNotifier<Duration>(Duration.zero);

  Timer? _timer;
  String _sig = '';
  String _day = '';
  String _scheduledDay = '';
  bool _busy = false;

  String _makeSig() =>
      '${_s.lat}|${_s.lng}|${_s.tzName}|${_s.method}|${_s.madhab}|${_s.notify}|${_s.voice}';
  String _dayKey(tz.TZDateTime t) => '${t.year}-${t.month}-${t.day}';

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _s.addListener(() {
      if (!_busy && _makeSig() != _sig) refresh();
    });
    await refresh(relocate: true);
  }

  Future<void> refresh({bool relocate = false}) async {
    if (_busy) return;
    _busy = true;
    status = LoadState.loading;
    error = null;
    notifyListeners();
    try {
      if (_s.auto && (relocate || !_s.hasLocation)) {
        try {
          final p = await _loc.current();
          await _s.setLocation(p.$1, p.$2, tz.local.name, 'موقعك الحالي', auto: true);
        } on LocationException {
          if (!_s.hasLocation) rethrow;
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
      _startTimer();
      _scheduleNotifications(force: true);
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

  void _load() {
    final now = tz.TZDateTime.now(tz.getLocation(_s.tzName));
    today = _svc.today(_s);
    _day = _dayKey(now);
    _computeNext(now);
    remaining.value = nextTime!.difference(now);
  }

  void _computeNext(tz.TZDateTime now) {
    tz.TZDateTime? prev;
    for (final k in PrayerKind.values) {
      if (k == PrayerKind.sunrise) continue;
      final t = today[k]!;
      if (t.isAfter(now)) {
        next = k;
        nextTime = t;
        prevTime = prev ?? _svc.compute(_s, -1)[PrayerKind.isha];
        return;
      }
      prev = t;
    }
    next = PrayerKind.fajr;
    nextTime = _svc.compute(_s, 1)[PrayerKind.fajr];
    prevTime = prev;
  }

  bool isNextKind(PrayerKind k) =>
      nextTime != null && today[k] != null && today[k]!.isAtSameMomentAs(nextTime!);
  bool isPassed(PrayerKind k) =>
      nextTime != null && today[k] != null && today[k]!.isBefore(nextTime!);

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (status != LoadState.ready || nextTime == null) return;
    final now = tz.TZDateTime.now(tz.getLocation(_s.tzName));
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

  void _scheduleNotifications({bool force = false}) {
    if (!force && _scheduledDay == _day) return;
    _scheduledDay = _day;
    final f = _s.notify ? _notif.schedule(_s, _svc) : _notif.cancelAll();
    f.catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (status != LoadState.ready) return;
    if (s == AppLifecycleState.resumed) {
      _tick();
      _startTimer();
      _scheduleNotifications();
    } else if (s == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }
}
