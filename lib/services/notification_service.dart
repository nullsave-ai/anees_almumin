import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/settings.dart';
import 'prayer_service.dart';

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'prayer_times',
    'أوقات الصلاة',
    description: 'تنبيه عند دخول وقت الصلاة',
    importance: Importance.high,
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await _android?.createNotificationChannel(_channel);
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

  /// يجدول صلوات الأيام القادمة (بدون الشروق). تُعاد الجدولة عند بداية يوم جديد
  /// وعند فتح التطبيق وعند تغيير الموقع أو الإعدادات، وبعد إعادة تشغيل الجهاز.
  Future<void> schedule(AppSettings s, PrayerService svc, {int days = 14}) async {
    await _plugin.cancelAll();
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final now = tz.TZDateTime.now(tz.getLocation(s.tzName));
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_times',
        'أوقات الصلاة',
        channelDescription: 'تنبيه عند دخول وقت الصلاة',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
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
