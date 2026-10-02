import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// إعدادات المستخدم المحفوظة محليًا.
/// الإعدادات التي تؤثر على واجهة محددة لها Notifier مستقل كي لا تُعاد بناء بقية التطبيق.
class AppSettings extends ChangeNotifier {
  AppSettings(this.prefs)
      : themeN = ValueNotifier(_theme(prefs.getString('theme'))),
        blurN = ValueNotifier(prefs.getBool('blur') ?? false),
        gridN = ValueNotifier(prefs.getBool('grid') ?? false),
        fontN = ValueNotifier(prefs.getDouble('qfont') ?? 26);

  final SharedPreferences prefs;
  final ValueNotifier<ThemeMode> themeN;
  final ValueNotifier<bool> blurN, gridN;
  final ValueNotifier<double> fontN;

  static ThemeMode _theme(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  bool get auto => prefs.getBool('auto') ?? true;
  double? get lat => prefs.getDouble('lat');
  double? get lng => prefs.getDouble('lng');
  bool get hasLocation => lat != null && lng != null;
  String get tzName => prefs.getString('tz') ?? tz.local.name;
  String get place => prefs.getString('place') ?? '';
  String get method => prefs.getString('method') ?? 'ummAlQura';
  String get madhab => prefs.getString('madhab') ?? 'shafi';
  bool get notify => prefs.getBool('notify') ?? true;
  String get voice => prefs.getString('voice') ?? '';
  String get theme => prefs.getString('theme') ?? 'system';
  bool get blur => blurN.value;
  bool get grid => gridN.value;
  double get quranFont => fontN.value;
  int get locStamp => prefs.getInt('loc_ts') ?? 0;

  static const _viewOnly = {'qfont', 'grid'};

  Future<void> setMany(Map<String, Object> values) async {
    final writes = <Future<bool>>[];
    for (final e in values.entries) {
      final v = e.value;
      if (v is bool) {
        writes.add(prefs.setBool(e.key, v));
      } else if (v is double) {
        writes.add(prefs.setDouble(e.key, v));
      } else if (v is int) {
        writes.add(prefs.setInt(e.key, v));
      } else {
        writes.add(prefs.setString(e.key, v.toString()));
      }
    }
    if (values.containsKey('theme')) themeN.value = _theme(theme);
    if (values.containsKey('blur')) blurN.value = prefs.getBool('blur') ?? false;
    if (values.containsKey('grid')) gridN.value = prefs.getBool('grid') ?? false;
    if (values.containsKey('qfont')) fontN.value = prefs.getDouble('qfont') ?? 26;
    if (!values.keys.every(_viewOnly.contains)) notifyListeners();
    await Future.wait(writes);
  }

  Future<void> put(String key, Object value) => setMany({key: value});

  Future<void> setLocation(double lat, double lng, String tzName, String place, {required bool auto}) =>
      setMany({
        'lat': lat,
        'lng': lng,
        'tz': tzName,
        'place': place,
        'auto': auto,
        'loc_ts': DateTime.now().millisecondsSinceEpoch,
      });

  @override
  void dispose() {
    themeN.dispose();
    blurN.dispose();
    gridN.dispose();
    fontN.dispose();
    super.dispose();
  }
}
