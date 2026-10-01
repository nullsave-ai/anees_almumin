import 'package:hijri/hijri_calendar.dart';

String ar(Object n) {
  const d = '٠١٢٣٤٥٦٧٨٩';
  return n.toString().replaceAllMapped(RegExp(r'\d'), (m) => d[int.parse(m[0]!)]);
}

String fmtTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${ar(h)}:${ar(t.minute.toString().padLeft(2, '0'))} ${t.hour < 12 ? 'ص' : 'م'}';
}

String fmtCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  String p(int v) => ar(v.toString().padLeft(2, '0'));
  return '${p(d.inHours)}:${p(d.inMinutes % 60)}:${p(d.inSeconds % 60)}';
}

const _months = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];
const _hijriMonths = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
  'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة'
];
const _days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

String gregorianLabel(DateTime d) =>
    '${_days[d.weekday - 1]}، ${ar(d.day)} ${_months[d.month - 1]} ${ar(d.year)} م';

String hijriLabel(DateTime d) {
  final h = HijriCalendar.fromDate(d);
  return '${ar(h.hDay)} ${_hijriMonths[h.hMonth - 1]} ${ar(h.hYear)} هـ';
}

/// تبسيط النص العربي للبحث: إزالة التشكيل وتوحيد الألف والهاء والياء.
String normalizeAr(String s) {
  var r = s
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .trim();
  if (r.startsWith('سوره ')) r = r.substring(5);
  return r;
}
