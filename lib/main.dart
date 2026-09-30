import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

import 'app.dart';
import 'core/di.dart';
import 'core/settings.dart';
import 'data/quran_repository.dart';
import 'features/prayer/prayer_controller.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/prayer_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  try {
    tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  final support = await getApplicationSupportDirectory();
  final quranDir = Directory('${support.path}/quran');
  if (!await quranDir.exists()) await quranDir.create(recursive: true);

  Deps.settings = AppSettings(prefs);
  Deps.prayers = PrayerService();
  Deps.notifications = NotificationService();
  Deps.location = LocationService();
  Deps.quran = QuranRepository(quranDir);
  await Deps.notifications.init();
  if (Deps.settings.notify && !(prefs.getBool('perm_asked') ?? false)) {
    await prefs.setBool('perm_asked', true);
    await Deps.notifications.requestPermissions();
  }
  Deps.prayer = PrayerController(
      Deps.settings, Deps.prayers, Deps.notifications, Deps.location);

  runApp(const App());
  Deps.prayer.init();
}
