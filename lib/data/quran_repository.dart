import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/format.dart';

class Surah {
  const Surah(this.number, this.name, this.ayahs, this.meccan, this.norm);
  final int number;
  final String name;
  final int ayahs;
  final bool meccan;
  final String norm; // الاسم بعد تبسيطه للبحث (يُحسب مرة واحدة)
}

class Ayah {
  const Ayah(this.number, this.text);
  final int number;
  final String text;
}

// دوال المعالجة العليا (تعمل داخل Isolate عند الحاجة)
String _compactSurahs(Uint8List b) {
  final d = jsonDecode(utf8.decode(b))['data'] as List;
  return jsonEncode([
    for (final e in d) [e['number'], e['name'], e['numberOfAyahs'], e['revelationType'] == 'Meccan' ? 1 : 0]
  ]);
}

String _compactAyahs(Uint8List b) {
  final d = jsonDecode(utf8.decode(b))['data']['ayahs'] as List;
  return jsonEncode([for (final e in d) e['text']]);
}

List<Ayah> _parseAyahs(String raw) {
  final l = jsonDecode(raw) as List;
  return [for (var i = 0; i < l.length; i++) Ayah(i + 1, l[i] as String)];
}

/// يجلب نص القرآن من alquran.cloud مرة واحدة ويخزنه بصيغة مضغوطة (نصوص فقط)
/// للقراءة دون إنترنت. التحليل الثقيل يتم خارج الخيط الرئيسي.
class QuranRepository {
  Directory? _dir;
  static const _base = 'https://api.alquran.cloud/v1';

  Future<Directory> _d() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/quran');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  Future<String> _cached(String file, String path, String Function(Uint8List) compact) async {
    final f = File('${(await _d()).path}/$file');
    if (await f.exists()) return f.readAsString();
    final r = await http.get(Uri.parse('$_base$path')).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw HttpException('status ${r.statusCode}');
    final bytes = r.bodyBytes;
    final raw = await Isolate.run(() => compact(bytes));
    await f.writeAsString(raw);
    return raw;
  }

  Future<List<Surah>> surahs() async {
    final raw = await _cached('v2_surahs.json', '/surah', _compactSurahs);
    final l = jsonDecode(raw) as List;
    return [
      for (final e in l) Surah(e[0] as int, e[1] as String, e[2] as int, e[3] == 1, normalizeAr(e[1] as String))
    ];
  }

  Future<List<Ayah>> ayahs(int surah) async {
    final raw = await _cached('v2_s$surah.json', '/surah/$surah/quran-uthmani', _compactAyahs);
    return raw.length > 20000 ? Isolate.run(() => _parseAyahs(raw)) : _parseAyahs(raw);
  }
}
