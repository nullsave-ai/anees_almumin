import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdhanException implements Exception {
  AdhanException(this.message);
  final String message;
}

class AdhanVoice {
  const AdhanVoice({required this.id, required this.name, this.asset, this.path, this.uri});
  final String id, name;
  final String? asset; // ملف مضمّن في assets/adhan
  final String? path; // نسخة داخل التطبيق (للمعاينة)
  final String? uri; // content:// من MediaStore (لصوت الإشعار)
  bool get custom => id.startsWith('custom:');
}

/// أصوات الأذان: المضمّنة في assets/adhan + ما يضيفه المستخدم من جهازه.
/// المشغّل ومعرّف الأصول يُنشآن عند الحاجة فقط (لا كلفة عند الإقلاع).
class AdhanService {
  AdhanService(this._prefs);
  final SharedPreferences _prefs;
  static const _ch = MethodChannel('anees/adhan');
  static const _maxBytes = 8 * 1024 * 1024;

  AudioPlayer? _p;
  List<AdhanVoice>? _bundled;

  static const _names = <String, String>{
    'mishary_alafasy': 'مشاري العفاسي',
    'nasser_alqatami': 'ناصر القطامي',
    'ali_mulla': 'علي ملا',
    'makkah': 'أذان المسجد الحرام',
    'madinah': 'أذان المسجد النبوي',
    'aqsa': 'أذان المسجد الأقصى',
  };

  List<AdhanVoice> custom() {
    final raw = _prefs.getString('custom_voices');
    if (raw == null) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          AdhanVoice(id: e['id'] as String, name: e['name'] as String, path: e['path'] as String?, uri: e['uri'] as String?)
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveCustom(List<AdhanVoice> list) => _prefs.setString(
      'custom_voices',
      jsonEncode([for (final v in list) {'id': v.id, 'name': v.name, 'path': v.path, 'uri': v.uri}]));

  String? customUri(String id) => custom().where((v) => v.id == id).firstOrNull?.uri;

  Future<List<AdhanVoice>> bundled() async {
    if (_bundled != null) return _bundled!;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final out = <AdhanVoice>[];
    for (final a in manifest.listAssets()) {
      if (!a.startsWith('assets/adhan/')) continue;
      final f = a.split('/').last;
      final dot = f.lastIndexOf('.');
      if (dot < 0) continue;
      if (!const ['mp3', 'ogg', 'wav'].contains(f.substring(dot + 1).toLowerCase())) continue;
      final id = f.substring(0, dot).toLowerCase().replaceAll(RegExp(r'[ -]'), '_');
      out.add(AdhanVoice(id: id, name: _names[id] ?? id.replaceAll('_', ' '), asset: a));
    }
    out.sort((a, b) => a.id.compareTo(b.id));
    return _bundled = out;
  }

  Future<List<AdhanVoice>> voices() async => [...custom(), ...await bundled()];

  String nameOf(String id) {
    if (id.isEmpty) return 'صوت الإشعار الافتراضي';
    final c = custom().where((v) => v.id == id).firstOrNull;
    if (c != null) return c.name;
    return _bundled?.where((v) => v.id == id).firstOrNull?.name ?? id;
  }

  Future<Directory> _customDir() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/adhan');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// يختار المستخدم ملفًا صوتيًا من جهازه ويُضاف كمؤذن مخصص.
  Future<AdhanVoice?> pickAndAdd() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.audio);
    final f = r?.files.firstOrNull;
    if (f == null || f.path == null) return null;
    if (f.size > _maxBytes) throw AdhanException('حجم الملف كبير. الحد الأقصى 8 ميغابايت.');
    final dot = f.name.lastIndexOf('.');
    final ext = dot < 0 ? 'mp3' : f.name.substring(dot + 1).toLowerCase();
    final base = dot < 0 ? f.name : f.name.substring(0, dot);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final dest = File('${(await _customDir()).path}/$ts.$ext');
    await File(f.path!).copy(dest.path);
    unawaited(FilePicker.platform.clearTemporaryFiles().then((_) {}, onError: (_) {}));
    final String uri;
    try {
      uri = await _ch.invokeMethod<String>('import', {'path': dest.path, 'name': 'anees_$ts.$ext'}) ?? '';
    } on PlatformException catch (e) {
      await dest.delete();
      throw AdhanException(e.code == 'unsupported'
          ? 'إضافة صوت مخصص تتطلب أندرويد 10 أو أحدث.'
          : 'تعذر إضافة الصوت. جرّب ملفًا آخر.');
    }
    if (uri.isEmpty) {
      await dest.delete();
      throw AdhanException('تعذر إضافة الصوت. جرّب ملفًا آخر.');
    }
    final v = AdhanVoice(id: 'custom:$ts', name: base, path: dest.path, uri: uri);
    await _saveCustom([v, ...custom()]);
    return v;
  }

  Future<void> removeCustom(AdhanVoice v) async {
    await stop();
    try {
      if (v.path != null) await File(v.path!).delete();
    } catch (_) {}
    if (v.uri != null) {
      try {
        await _ch.invokeMethod('delete', {'uri': v.uri});
      } catch (_) {}
    }
    await _saveCustom(custom().where((e) => e.id != v.id).toList());
  }

  AudioPlayer get _player => _p ??= AudioPlayer();
  Stream<void> get onComplete => _player.onPlayerComplete;

  Future<void> preview(AdhanVoice v) async {
    final p = _player;
    await p.stop();
    await p.play(v.path != null ? DeviceFileSource(v.path!) : AssetSource(v.asset!.replaceFirst('assets/', '')));
  }

  Future<void> stop() async => _p?.stop();

  /// يحرر المشغّل الأصلي عند إغلاق شاشة الاختيار.
  Future<void> releasePlayer() async {
    final p = _p;
    _p = null;
    await p?.dispose();
  }
}
