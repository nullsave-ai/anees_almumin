import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/settings.dart';
import 'prayer_service.dart';

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _defaultChannel = AndroidNotificationChannel(
    'prayer_times',
    'أوقات الصلاة',
    description: 'تنبيه عند دخول وقت الصلاة',
    importance: Importance.high,
  );

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await _android?.createNotificationChannel(_defaultChannel);
  }

  Future<bool> requestPermissions() async {
    final a = _android;
    if (a == null) return false;
    final granted = await a.requestNotificationsPermission() ?? false;
    if (!(await a.canScheduleExactNotifications() ?? true)) {
      await a.requestExactAlarmsPermission();
    }
    return granted;
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// قناة مستقلة لكل مؤذن لأن صوت القناة في أندرويد لا يتغير بعد إنشائها.
  Future<String> _channelFor(String voice) async {
    if (voice.isEmpty) return _defaultChannel.id;
    final id = 'adhan_$voice';
    await _android?.createNotificationChannel(AndroidNotificationChannel(
      id,
      'الأذان',
      description: 'أذان عند دخول وقت الصلاة',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(voice),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ));
    return id;
  }

  /// يجدول صلوات الأيام القادمة (بدون الشروق) بصوت المؤذن المختار.
  Future<void> schedule(AppSettings s, PrayerService svc, {int days = 14}) async {
    await _plugin.cancelAll();
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final now = tz.TZDateTime.now(tz.getLocation(s.tzName));
    final voice = s.voice;
    final channel = await _channelFor(voice);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        voice.isEmpty ? 'أوقات الصلاة' : 'الأذان',
        channelDescription: 'تنبيه عند دخول وقت الصلاة',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: voice.isEmpty ? null : RawResourceAndroidNotificationSound(voice),
        audioAttributesUsage: voice.isEmpty ? AudioAttributesUsage.notification : AudioAttributesUsage.alarm,
      ),
    );
    for (var d = 0; d < days; d++) {
      final times = svc.compute(s, d);
      for (final k in PrayerKind.values) {
        if (k == PrayerKind.sunrise) continue;
        final t = times[k]!;
        if (!t.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          d * 10 + k.index,
          'أنيس المؤمن',
          'حان الآن موعد صلاة ${prayerNames[k]}',
          t,
          details,
          androidScheduleMode:
              exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    }
  }
}
