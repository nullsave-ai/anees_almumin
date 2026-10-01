import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class Surah {
  const Surah(this.number, this.name, this.ayahs, this.meccan);
  final int number;
  final String name;
  final int ayahs;
  final bool meccan;
}

class Ayah {
  const Ayah(this.number, this.text);
  final int number;
  final String text;
}

/// يجلب نص القرآن من alquran.cloud مرة واحدة ويخزنه على الجهاز للقراءة دون إنترنت.
class QuranRepository {
  QuranRepository(this._dir);
  final Directory _dir;
  static const _base = 'https://api.alquran.cloud/v1';

  Future<dynamic> _fetch(String file, String path) async {
    final f = File('${_dir.path}/$file');
    if (await f.exists()) return jsonDecode(await f.readAsString());
    final r = await http.get(Uri.parse('$_base$path')).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) throw HttpException('status ${r.statusCode}');
    final data = jsonDecode(utf8.decode(r.bodyBytes))['data'];
    await f.writeAsString(jsonEncode(data));
    return data;
  }

  Future<List<Surah>> surahs() async {
    final d = await _fetch('surahs.json', '/surah') as List;
    return [
      for (final e in d)
        Surah(e['number'] as int, e['name'] as String, e['numberOfAyahs'] as int,
            e['revelationType'] == 'Meccan')
    ];
  }

  Future<List<Ayah>> ayahs(int surah) async {
    final d = await _fetch('s$surah.json', '/surah/$surah/quran-uthmani');
    return [
      for (final e in d['ayahs'] as List) Ayah(e['numberInSurah'] as int, e['text'] as String)
    ];
  }
}
