import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// إعدادات المستخدم المحفوظة محليًا.
class AppSettings extends ChangeNotifier {
  AppSettings(this.prefs);
  final SharedPreferences prefs;

  bool get auto => prefs.getBool('auto') ?? true;
  double? get lat => prefs.getDouble('lat');
  double? get lng => prefs.getDouble('lng');
  bool get hasLocation => lat != null && lng != null;
  String get tzName => prefs.getString('tz') ?? tz.local.name;
  String get place => prefs.getString('place') ?? '';
  String get method => prefs.getString('method') ?? 'ummAlQura';
  String get madhab => prefs.getString('madhab') ?? 'shafi';
  bool get notify => prefs.getBool('notify') ?? true;
  double get quranFont => prefs.getDouble('qfont') ?? 26;

  Future<void> setMany(Map<String, Object> values) async {
    for (final e in values.entries) {
      final v = e.value;
      if (v is bool) {
        await prefs.setBool(e.key, v);
      } else if (v is double) {
        await prefs.setDouble(e.key, v);
      } else if (v is int) {
        await prefs.setInt(e.key, v);
      } else {
        await prefs.setString(e.key, v.toString());
      }
    }
    notifyListeners();
  }

  Future<void> put(String key, Object value) => setMany({key: value});

  Future<void> setLocation(double lat, double lng, String tzName, String place,
          {required bool auto}) =>
      setMany({'lat': lat, 'lng': lng, 'tz': tzName, 'place': place, 'auto': auto});
}
