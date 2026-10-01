import '../data/quran_repository.dart';
import '../features/prayer/prayer_controller.dart';
import '../services/adhan_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/prayer_service.dart';
import 'settings.dart';

/// محدد خدمات بسيط: تُهيَّأ مرة واحدة في main.
class Deps {
  static late AppSettings settings;
  static late PrayerService prayers;
  static late NotificationService notifications;
  static late LocationService location;
  static late PrayerController prayer;
  static late QuranRepository quran;
  static late AdhanService adhan;
}
