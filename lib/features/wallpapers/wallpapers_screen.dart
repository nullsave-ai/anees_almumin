import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di.dart';
import '../../core/glass.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'wall_painters.dart';

class _Live {
  const _Live(this.key, this.design, this.title, this.desc);
  final String key;
  final WallDesign design;
  final String title, desc;
}

const _lives = [
  _Live('sky', WallDesign.sky, 'سماء الصلاة', 'سماء تتغير فعليًا مع الفجر والشروق والظهر والغروب والليل'),
  _Live('grass', WallDesign.grass, 'عشب ورياح', 'عشب أخضر تهزّه الرياح بهدوء'),
  _Live('night', WallDesign.night, 'ليل ونجوم', 'نجوم متلألئة وهلال ذهبي وشهب عابرة'),
];

const _statics = [
  WallDesign.grass,
  WallDesign.dawn,
  WallDesign.night,
  WallDesign.pattern,
  WallDesign.sunset,
  WallDesign.crescent,
];

class _Thumb extends StatelessWidget {
  const _Thumb({required this.design, this.width, this.height});
  final WallDesign design;
  final double? width, height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: RepaintBoundary(child: CustomPaint(painter: WallPainter(design), size: Size.infinite)),
        ),
      );
}

class WallpapersScreen extends StatefulWidget {
  const WallpapersScreen({super.key});

  @override
  State<WallpapersScreen> createState() => _WallpapersScreenState();
}

class _WallpapersScreenState extends State<WallpapersScreen> {
  late String _live = Deps.settings.prefs.getString('live_theme') ?? 'sky';
  String? _msg;

  Future<void> _setLive(String key) async {
    await Deps.settings.put('live_theme', key);
    setState(() {
      _live = key;
      _msg = null;
    });
    try {
      await Deps.wallpaper.setLive();
    } on PlatformException {
      if (mounted) setState(() => _msg = 'تعذر فتح شاشة الخلفيات الحية في جهازك.');
    }
  }

  Future<void> _pin() async {
    try {
      final ok = await Deps.wallpaper.pinWidget();
      if (!ok && mounted) {
        setState(() => _msg = 'أضفه يدويًا: اضغط مطولًا على الشاشة الرئيسية ثم الأدوات ثم أنيس المؤمن.');
      }
    } on PlatformException {
      if (mounted) setState(() => _msg = 'تعذر إضافة الويدجت.');
    }
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GlassPage(
      title: 'الخلفيات والويدجت',
      child: PageBody(
        child: ListView(
          padding: pagePad(context, nav: false, extraTop: 66),
          children: [
            _title('خلفيات متحركة'),
            for (final l in _lives)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  radius: 28,
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    Row(children: [
                      _Thumb(design: l.design, width: 72, height: 128),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(l.desc, style: TextStyle(fontSize: 13, height: 1.5, color: p.muted)),
                        ]),
                      ),
                      if (_live == l.key) Icon(AppIcons.checkOn, color: p.green),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _setLive(l.key),
                        icon: Icon(AppIcons.wallpaper, size: 18),
                        label: const Text('تثبيت كخلفية متحركة'),
                      ),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 12),
            _title('خلفيات ثابتة'),
            GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .56,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final d in _statics)
                  Pressable(
                    onTap: () => showGlassSheet(context, builder: (_) => _WallSheet(design: d)),
                    child: Stack(fit: StackFit.expand, children: [
                      _Thumb(design: d),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                            gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Color(0xB3000000), Color(0x00000000)]),
                          ),
                          child: Text(wallNames[d]!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _title('ويدجت الشاشة الرئيسية'),
            GlassCard(
              radius: 28,
              child: Row(children: [
                IconBadge(icon: AppIcons.widget, size: 50),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('الصلاة القادمة مع العدّ التنازلي على شاشتك الرئيسية',
                      style: TextStyle(fontSize: 14, height: 1.5, color: p.muted)),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _pin, child: const Text('إضافة')),
              ]),
            ),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(_msg!, style: TextStyle(color: Theme.of(context).colorScheme.error, height: 1.6)),
              ),
          ],
        ),
      ),
    );
  }
}

class _WallSheet extends StatefulWidget {
  const _WallSheet({required this.design});
  final WallDesign design;

  @override
  State<_WallSheet> createState() => _WallSheetState();
}

class _WallSheetState extends State<_WallSheet> {
  bool _busy = false;
  String? _msg;
  bool _ok = false;

  Future<void> _apply(int which) async {
    final mq = MediaQuery.of(context);
    final px = mq.size * mq.devicePixelRatio;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final path = await renderWallToFile(widget.design, px);
      await Deps.wallpaper.setStatic(path, which);
      _ok = true;
      _msg = 'تم تعيين الخلفية';
    } on PlatformException {
      _ok = false;
      _msg = 'تعذر تعيين الخلفية';
    } catch (_) {
      _ok = false;
      _msg = 'تعذر إنشاء الخلفية';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final h = MediaQuery.sizeOf(context).height;
    final previewH = (h * .42).clamp(240.0, 420.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(wallNames[widget.design]!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _Thumb(design: widget.design, height: previewH, width: previewH * .5),
        const SizedBox(height: 14),
        if (_busy)
          const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
        else
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            FilledButton.tonal(onPressed: () => _apply(1), child: const Text('الشاشة الرئيسية')),
            FilledButton.tonal(onPressed: () => _apply(2), child: const Text('شاشة القفل')),
            FilledButton(onPressed: () => _apply(3), child: const Text('كلتاهما')),
          ]),
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_msg!, style: TextStyle(color: _ok ? p.green : Theme.of(context).colorScheme.error)),
          ),
      ]),
    );
  }
}
