import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app.dart';
import 'core/di.dart';
import 'core/settings.dart';
import 'data/quran_repository.dart';
import 'features/prayer/prayer_controller.dart';
import 'services/adhan_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/prayer_service.dart';
import 'services/wallpaper_service.dart';

/// الإقلاع: ننتظر SharedPreferences فقط ثم نعرض الواجهة فورًا (هياكل تحميل).
/// كل ما عداه (المناطق الزمنية، الإشعارات، الموقع، الصوتيات) يبدأ بعد أول إطار.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();

  Deps.settings = AppSettings(prefs);
  Deps.prayers = PrayerService();
  Deps.location = LocationService();
  Deps.adhan = AdhanService(prefs);
  Deps.notifications = NotificationService(Deps.adhan);
  Deps.wallpaper = WallpaperService();
  Deps.quran = QuranRepository();
  Deps.prayer = PrayerController(Deps.settings, Deps.prayers, Deps.notifications, Deps.location);

  // يُحدَّث الويدجت كلما أُعيد حساب أوقات الصلاة
  Deps.prayer.onTimesChanged = () => Deps.wallpaper.refreshWidget();

  runApp(const App());
  WidgetsBinding.instance.addPostFrameCallback((_) => _boot(prefs));
}

Future<void> _boot(SharedPreferences prefs) async {
  tzdata.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
  } catch (_) {}
  await Deps.notifications.init();
  await Deps.prayer.init();

  // أعمال غير عاجلة بعد استقرار الواجهة
  Timer(const Duration(seconds: 2), () async {
    if (Deps.settings.notify && !(prefs.getBool('perm_asked') ?? false)) {
      await prefs.setBool('perm_asked', true);
      await Deps.notifications.requestPermissions();
    }
    unawaited(Deps.adhan.bundled().then((_) {}, onError: (_) {}));
  });
}
