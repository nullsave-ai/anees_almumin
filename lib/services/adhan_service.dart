import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AdhanVoice {
  const AdhanVoice(this.id, this.name, this.asset);
  final String id;
  final String name;
  final String asset;
}

/// يكتشف ملفات الأذان الموجودة في assets/adhan تلقائيًا ويشغّل معاينتها.
class AdhanService {
  final _player = AudioPlayer();
  List<AdhanVoice>? _cache;

  // أسماء عرض اختيارية لأسماء الملفات الشائعة؛ غير ذلك يُعرض اسم الملف.
  static const _names = <String, String>{
    'mishary_alafasy': 'مشاري العفاسي',
    'nasser_alqatami': 'ناصر القطامي',
    'ali_mulla': 'علي ملا',
    'makkah': 'أذان المسجد الحرام',
    'madinah': 'أذان المسجد النبوي',
    'aqsa': 'أذان المسجد الأقصى',
  };

  Future<List<AdhanVoice>> voices() async {
    if (_cache != null) return _cache!;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final out = <AdhanVoice>[];
    for (final a in manifest.listAssets()) {
      if (!a.startsWith('assets/adhan/')) continue;
      final f = a.split('/').last;
      final dot = f.lastIndexOf('.');
      if (dot < 0) continue;
      if (!const ['mp3', 'ogg', 'wav'].contains(f.substring(dot + 1).toLowerCase())) continue;
      final id = f.substring(0, dot).toLowerCase().replaceAll(RegExp(r'[ -]'), '_');
      out.add(AdhanVoice(id, _names[id] ?? id.replaceAll('_', ' '), a));
    }
    out.sort((a, b) => a.id.compareTo(b.id));
    return _cache = out;
  }

  String nameOf(String id) {
    if (id.isEmpty) return 'صوت الإشعار الافتراضي';
    return _cache?.where((v) => v.id == id).firstOrNull?.name ?? id;
  }

  Stream<void> get onComplete => _player.onPlayerComplete;

  Future<void> preview(AdhanVoice v) async {
    await _player.stop();
    await _player.play(AssetSource(v.asset.replaceFirst('assets/', '')));
  }

  Future<void> stop() => _player.stop();
}
