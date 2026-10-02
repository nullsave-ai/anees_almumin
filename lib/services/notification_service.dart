import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/settings.dart';
import 'adhan_service.dart';
import 'prayer_service.dart';

class NotificationService {
  NotificationService(this._adhan);
  final AdhanService _adhan;
  final _plugin = FlutterLocalNotificationsPlugin();
  final _channels = <String>{};
  static const _horizon = 14;

  static const _defaultChannel = AndroidNotificationChannel(
    'prayer_times',
    'أوقات الصلاة',
    description: 'تنبيه عند دخول وقت الصلاة',
    importance: Importance.high,
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await _android?.createNotificationChannel(_defaultChannel);
  }

  Future<bool> requestPermissions() async {
    final a = _android;
    if (a == null) return false;
    final granted = await a.requestNotificationsPermission() ?? false;
    if (!(await a.canScheduleExactNotifications() ?? true)) await a.requestExactAlarmsPermission();
    return granted;
  }

  /// يلغي كل التنبيهات ويمسح حالة الجدولة (عند تعطيل الإشعارات).
  Future<void> disable(AppSettings s) async {
    await _plugin.cancelAll();
    await s.prefs.remove('notif_sig');
    await s.prefs.remove('notif_until');
  }

  /// قناة مستقلة لكل مؤذن لأن صوت القناة في أندرويد لا يتغير بعد إنشائها.
  Future<String> _channelFor(String voice) async {
    if (voice.isEmpty) return _defaultChannel.id;
    final uri = _adhan.customUri(voice);
    if (voice.startsWith('custom:') && uri == null) return _defaultChannel.id; // الصوت المخصص محذوف
    final id = 'adhan_${voice.replaceAll(':', '_')}';
    if (_channels.add(id)) {
      await _android?.createNotificationChannel(AndroidNotificationChannel(
        id,
        'الأذان',
        description: 'أذان عند دخول وقت الصلاة',
        importance: Importance.max,
        playSound: true,
        sound: uri != null ? UriAndroidNotificationSound(uri) : RawResourceAndroidNotificationSound(voice),
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ));
    }
    return id;
  }

  static int _dayNum(tz.TZDateTime t) => DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ 86400000;

  /// جدولة تراكمية: المعرّفات مرتبطة بالتاريخ فتُكمَّل الأيام الناقصة فقط
  /// ولا يُعاد جدولة كل شيء إلا إذا تغيّر الموقع أو الإعدادات أو الصوت.
  Future<void> ensureScheduled(AppSettings s, PrayerService svc) async {
    final loc = tz.getLocation(s.tzName);
    final now = tz.TZDateTime.now(loc);
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final sig = '${s.lat}|${s.lng}|${s.tzName}|${s.method}|${s.madhab}|${s.voice}|$exact';
    final today = _dayNum(now);
    var until = s.prefs.getInt('notif_until') ?? -1;
    if (s.prefs.getString('notif_sig') != sig) {
      await _plugin.cancelAll();
      until = -1;
      await s.prefs.setString('notif_sig', sig);
    }
    final target = today + _horizon - 1;
    if (until >= target) return;

    final channel = await _channelFor(s.voice);
    final uri = s.voice.startsWith('custom:') ? _adhan.customUri(s.voice) : null;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        s.voice.isEmpty ? 'أوقات الصلاة' : 'الأذان',
        channelDescription: 'تنبيه عند دخول وقت الصلاة',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: s.voice.isEmpty
            ? null
            : (uri != null ? UriAndroidNotificationSound(uri) : RawResourceAndroidNotificationSound(s.voice)),
        audioAttributesUsage: s.voice.isEmpty ? AudioAttributesUsage.notification : AudioAttributesUsage.alarm,
      ),
    );
    final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    for (var day = (until + 1 > today ? until + 1 : today); day <= target; day++) {
      final times = svc.compute(s, day - today, loc0: loc);
      for (final k in PrayerKind.values) {
        if (k == PrayerKind.sunrise) continue;
        final t = times[k]!;
        if (!t.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          (day % 100000) * 10 + k.index,
          'أنيس المؤمن',
          'حان الآن موعد صلاة ${prayerNames[k]}',
          t,
          details,
          androidScheduleMode: mode,
        );
      }
    }
    await s.prefs.setInt('notif_until', target);
  }
}
