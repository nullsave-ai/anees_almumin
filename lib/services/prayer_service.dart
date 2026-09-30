import 'dart:convert';

import 'package:adhan_dart/adhan_dart.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/settings.dart';

enum PrayerKind { fajr, sunrise, dhuhr, asr, maghrib, isha }

const prayerNames = {
  PrayerKind.fajr: 'الفجر',
  PrayerKind.sunrise: 'الشروق',
  PrayerKind.dhuhr: 'الظهر',
  PrayerKind.asr: 'العصر',
  PrayerKind.maghrib: 'المغرب',
  PrayerKind.isha: 'العشاء',
};

const prayerIcons = {
  PrayerKind.fajr: Icons.bedtime_outlined,
  PrayerKind.sunrise: Icons.wb_twilight,
  PrayerKind.dhuhr: Icons.wb_sunny_outlined,
  PrayerKind.asr: Icons.light_mode_outlined,
  PrayerKind.maghrib: Icons.nights_stay_outlined,
  PrayerKind.isha: Icons.dark_mode_outlined,
};

const calcMethods = {
  'ummAlQura': 'أم القرى (مكة المكرمة)',
  'muslimWorldLeague': 'رابطة العالم الإسلامي',
  'egyptian': 'الهيئة المصرية العامة للمساحة',
  'karachi': 'جامعة العلوم الإسلامية بكراتشي',
  'dubai': 'دبي',
  'qatar': 'قطر',
  'kuwait': 'الكويت',
  'singapore': 'سنغافورة',
  'northAmerica': 'أمريكا الشمالية',
  'moonsighting': 'لجنة رؤية الهلال',
};

const madhabs = {
  'shafi': 'الجمهور (الشافعي والمالكي والحنبلي)',
  'hanafi': 'الحنفي',
};

typedef DayTimes = Map<PrayerKind, tz.TZDateTime>;

/// حساب أوقات الصلاة محليًا (بدون إنترنت) وحفظ نتيجة اليوم.
class PrayerService {
  CalculationParameters _params(String method, String madhab) {
    final p = switch (method) {
      'muslimWorldLeague' => CalculationMethodParameters.muslimWorldLeague(),
      'egyptian' => CalculationMethodParameters.egyptian(),
      'karachi' => CalculationMethodParameters.karachi(),
      'dubai' => CalculationMethodParameters.dubai(),
      'qatar' => CalculationMethodParameters.qatar(),
      'kuwait' => CalculationMethodParameters.kuwait(),
      'singapore' => CalculationMethodParameters.singapore(),
      'northAmerica' => CalculationMethodParameters.northAmerica(),
      'moonsighting' => CalculationMethodParameters.moonsightingCommittee(),
      _ => CalculationMethodParameters.ummAlQura(),
    };
    p.madhab = madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    return p;
  }

  DayTimes compute(AppSettings s, int dayOffset) {
    final loc = tz.getLocation(s.tzName);
    final now = tz.TZDateTime.now(loc);
    final date = DateTime(now.year, now.month, now.day + dayOffset);
    final pt = PrayerTimes(
      coordinates: Coordinates(s.lat!, s.lng!),
      date: date,
      calculationParameters: _params(s.method, s.madhab),
      precision: true,
    );
    tz.TZDateTime c(DateTime t) => tz.TZDateTime.from(t, loc);
    return {
      PrayerKind.fajr: c(pt.fajr),
      PrayerKind.sunrise: c(pt.sunrise),
      PrayerKind.dhuhr: c(pt.dhuhr),
      PrayerKind.asr: c(pt.asr),
      PrayerKind.maghrib: c(pt.maghrib),
      PrayerKind.isha: c(pt.isha),
    };
  }

  /// أوقات اليوم مع تخزين محلي؛ يعاد الحساب عند تغير اليوم أو الموقع أو الإعدادات.
  DayTimes today(AppSettings s) {
    final loc = tz.getLocation(s.tzName);
    final n = tz.TZDateTime.now(loc);
    final key = '${n.year}-${n.month}-${n.day}|${s.lat}|${s.lng}|${s.tzName}|${s.method}|${s.madhab}';
    final raw = s.prefs.getString('pt_cache');
    if (raw != null) {
      try {
        final j = jsonDecode(raw);
        if (j['k'] == key) {
          return {
            for (final k in PrayerKind.values)
              k: tz.TZDateTime.fromMillisecondsSinceEpoch(loc, j['t'][k.name] as int)
          };
        }
      } catch (_) {}
    }
    final t = compute(s, 0);
    s.prefs.setString('pt_cache', jsonEncode({
      'k': key,
      't': {for (final e in t.entries) e.key.name: e.value.millisecondsSinceEpoch}
    }));
    return t;
  }
}
