import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/cities.dart';
import '../../services/adhan_service.dart';
import '../../services/prayer_service.dart';
import 'prayer_controller.dart';

Future<void> chooseCity(BuildContext context) async {
  final key = await pickOne(context, 'اختر المدينة',
      {for (var i = 0; i < cities.length; i++) '$i': cities[i].name}, null);
  if (key == null) return;
  final c = cities[int.parse(key)];
  await Deps.settings.setLocation(c.lat, c.lng, c.tz, c.name, auto: false);
}

class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key, required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final c = Deps.prayer;
    final p = context.pal;
    return PageBody(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => RefreshIndicator(
          color: p.green,
          edgeOffset: MediaQuery.of(context).padding.top + 8,
          onRefresh: () => c.refresh(relocate: true, silent: true),
          child: ListView(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: pagePad(context),
            children: [
              TabHeader(
                title: 'أوقات الصلاة',
                subtitle: c.status == LoadState.ready ? Deps.settings.place : null,
                actions: [
                  GlassIconButton(
                    icon: AppIcons.settings,
                    tooltip: 'الإعدادات',
                    onTap: () => showGlassSheet(context, builder: (_) => const _SettingsSheet()),
                  ),
                ],
              ),
              ..._body(context, c),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, PrayerController c) {
    final p = context.pal;
    switch (c.status) {
      case LoadState.loading:
        return const [
          Skeleton(height: 230, radius: 34),
          SizedBox(height: 16),
          Skeleton(height: 64, radius: 26),
          SizedBox(height: 12),
          Skeleton(height: 64, radius: 26),
          SizedBox(height: 12),
          Skeleton(height: 64, radius: 26),
        ];
      case LoadState.ready:
        const kinds = PrayerKind.values;
        return [
          Reveal(index: 0, child: _SunCard(c: c)),
          const SizedBox(height: 24),
          Stack(children: [
            Positioned.directional(
              textDirection: Directionality.of(context),
              start: 14,
              top: 26,
              bottom: 26,
              width: 2,
              child: DecoratedBox(
                  decoration: BoxDecoration(color: p.green.withAlpha(60), borderRadius: BorderRadius.circular(1))),
            ),
            Column(children: [
              for (var i = 0; i < kinds.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == kinds.length - 1 ? 0 : 12),
                  child: _TimelineItem(kind: kinds[i], c: c),
                ),
            ]),
          ]),
        ];
      default:
        return [
          Message(
            icon: c.status == LoadState.error ? AppIcons.warn : AppIcons.pin,
            text: c.error ?? 'حدد موقعك لعرض أوقات الصلاة.',
            actions: [
              FilledButton.icon(
                  onPressed: () {
                    Deps.settings.put('auto', true);
                    c.refresh(relocate: true);
                  },
                  icon: Icon(AppIcons.locate),
                  label: const Text('تحديد الموقع تلقائيًا')),
              OutlinedButton.icon(
                  onPressed: () => chooseCity(context),
                  icon: Icon(AppIcons.city),
                  label: const Text('اختيار المدينة')),
            ],
          ),
        ];
    }
  }
}

/// بطاقة: الصلاة القادمة + قوس مسار الشمس من الشروق إلى الغروب.
class _SunCard extends StatelessWidget {
  const _SunCard({required this.c});
  final PrayerController c;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final sunrise = c.today[PrayerKind.sunrise]!;
    final sunset = c.today[PrayerKind.maghrib]!;
    return GlassCard(
      radius: 34,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الصلاة القادمة', style: TextStyle(color: p.muted)),
              const SizedBox(height: 4),
              Text(prayerNames[c.next]!, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('المتبقي', style: TextStyle(color: p.muted)),
            const SizedBox(height: 4),
            CountdownText(style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.green)),
          ]),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 118,
          child: RepaintBoundary(
            child: ValueListenableBuilder<Duration>(
              valueListenable: c.remaining,
              builder: (_, __, ___) {
                final now = DateTime.now().millisecondsSinceEpoch;
                final a = sunrise.millisecondsSinceEpoch, b = sunset.millisecondsSinceEpoch;
                final raw = b <= a ? 0.0 : ((now - a) / (b - a)).clamp(0.0, 1.0);
                final day = now >= a && now <= b;
                return CustomPaint(
                  size: Size.infinite,
                  painter: _ArcPainter((raw * 400).round() / 400, day, p.green, p.gold, p.muted.withAlpha(60)),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(day ? 'النهار' : 'الليل', style: TextStyle(fontSize: 12, color: p.muted)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _SunLabel(icon: AppIcons.sunrise, label: 'الشروق', time: sunrise),
          _SunLabel(icon: AppIcons.maghrib, label: 'الغروب', time: sunset),
        ]),
      ]),
    );
  }
}

class _SunLabel extends StatelessWidget {
  const _SunLabel({required this.icon, required this.label, required this.time});
  final IconData icon;
  final String label;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(children: [
      Icon(icon, size: 22, color: p.gold),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: p.muted)),
        Text(fmtTime(time), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
    ]);
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.t, this.day, this.green, this.gold, this.track);
  final double t;
  final bool day;
  final Color green, gold, track;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rx = w / 2 - 16, ry = h - 22;
    final c = Offset(w / 2, h - 6);
    final rect = Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
    canvas.drawArc(rect, math.pi, math.pi, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round..color = track);
    canvas.drawLine(Offset(4, c.dy), Offset(w - 4, c.dy), Paint()..color = track..strokeWidth = 1);
    if (t > 0) {
      // الشروق على اليمين (اتجاه RTL) والتقدم نحو اليسار
      canvas.drawArc(
        rect,
        2 * math.pi,
        -math.pi * t,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [gold, green]).createShader(rect),
      );
    }
    final a = 2 * math.pi - math.pi * t;
    final pos = Offset(c.dx + rx * math.cos(a), c.dy + ry * math.sin(a));
    if (day) canvas.drawCircle(pos, 17, Paint()..color = gold.withAlpha(60));
    canvas.drawCircle(pos, 9, Paint()..color = day ? gold : track);
    canvas.drawCircle(pos, 9,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white.withAlpha(day ? 200 : 60));
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.t != t || o.day != day;
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.kind, required this.c});
  final PrayerKind kind;
  final PrayerController c;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final isNext = c.isNextKind(kind);
    final passed = c.isPassed(kind);
    final filled = passed || isNext;
    final dot = Container(
      width: isNext ? 22 : 16,
      height: isNext ? 22 : 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? p.green : p.bg,
        border: Border.all(color: filled ? p.green : p.muted.withAlpha(120), width: 2),
        boxShadow: isNext ? [BoxShadow(color: p.green.withAlpha(120), blurRadius: 10, spreadRadius: 1)] : null,
      ),
      child: passed ? Icon(AppIcons.check, size: 10, color: Colors.white) : null,
    );
    return Row(children: [
      SizedBox(width: 30, child: Center(child: dot)),
      const SizedBox(width: 10),
      Expanded(child: isNext ? _NextCard(kind: kind, c: c) : _PlainCard(kind: kind, c: c, passed: passed)),
    ]);
  }
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.kind, required this.c});
  final PrayerKind kind;
  final PrayerController c;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: p.hero),
        boxShadow: [BoxShadow(color: p.green.withAlpha(p.dark ? 70 : 100), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(34)),
          child: Icon(prayerIcons[kind], color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(prayerNames[kind]!, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Row(children: [
              Icon(AppIcons.timer, size: 16, color: p.gold),
              const SizedBox(width: 5),
              const CountdownText(style: TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          ]),
        ),
        Text(fmtTime(c.today[kind]!), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _PlainCard extends StatelessWidget {
  const _PlainCard({required this.kind, required this.c, required this.passed});
  final PrayerKind kind;
  final PrayerController c;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final isSun = kind == PrayerKind.sunrise;
    final tc = passed ? p.muted : p.ink;
    return GlassCard(
      radius: 26,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSun ? 12 : 16),
      child: Row(children: [
        IconBadge(icon: prayerIcons[kind]!, size: 44, color: isSun ? p.gold : (passed ? p.muted : p.green)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(prayerNames[kind]!, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tc)),
            if (isSun) Text('نهاية وقت الفجر', style: TextStyle(fontSize: 12, color: p.muted)),
          ]),
        ),
        Text(fmtTime(c.today[kind]!), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tc)),
      ]),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final s = Deps.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('إعدادات الصلاة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          ),
          SwitchListTile(
            secondary: Icon(AppIcons.locate),
            title: const Text('تحديد الموقع تلقائيًا'),
            value: s.auto,
            onChanged: (v) async {
              await s.put('auto', v);
              if (v) Deps.prayer.refresh(relocate: true);
            },
          ),
          ListTile(
            leading: Icon(AppIcons.city),
            title: const Text('اختيار المدينة يدويًا'),
            subtitle: Text(s.place.isEmpty ? 'غير محددة' : s.place),
            onTap: () => chooseCity(context),
          ),
          ListTile(
            leading: Icon(AppIcons.calc),
            title: const Text('طريقة الحساب'),
            subtitle: Text(calcMethods[s.method] ?? ''),
            onTap: () async {
              final v = await pickOne(context, 'طريقة الحساب', calcMethods, s.method);
              if (v != null) s.put('method', v);
            },
          ),
          ListTile(
            leading: Icon(AppIcons.school),
            title: const Text('المذهب (وقت العصر)'),
            subtitle: Text(madhabs[s.madhab] ?? ''),
            onTap: () async {
              final v = await pickOne(context, 'المذهب', madhabs, s.madhab);
              if (v != null) s.put('madhab', v);
            },
          ),
          SwitchListTile(
            secondary: Icon(AppIcons.bell),
            title: const Text('إشعارات الصلاة'),
            value: s.notify,
            onChanged: (v) async {
              if (v) await Deps.notifications.requestPermissions();
              await s.put('notify', v);
            },
          ),
          ListTile(
            leading: Icon(AppIcons.voice),
            title: const Text('المؤذن وصوت الأذان'),
            subtitle: Text(Deps.adhan.nameOf(s.voice)),
            onTap: () => showGlassSheet(context, builder: (_) => const VoiceSheet()),
          ),
          ListTile(
            leading: Icon(AppIcons.battery),
            title: const Text('السماح بالعمل في الخلفية'),
            subtitle: const Text('يضمن وصول الإشعارات في وقتها عند إغلاق التطبيق'),
            onTap: () => Permission.ignoreBatteryOptimizations.request(),
          ),
        ]),
      ),
    );
  }
}

class VoiceSheet extends StatefulWidget {
  const VoiceSheet({super.key});

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> {
  String? _playing;
  late final _sub = Deps.adhan.onComplete.listen((_) {
    if (mounted) setState(() => _playing = null);
  });

  @override
  void initState() {
    super.initState();
    _sub;
  }

  @override
  void dispose() {
    _sub.cancel();
    Deps.adhan.stop();
    super.dispose();
  }

  Future<void> _toggle(AdhanVoice v) async {
    if (_playing == v.id) {
      await Deps.adhan.stop();
      setState(() => _playing = null);
    } else {
      setState(() => _playing = v.id);
      try {
        await Deps.adhan.preview(v);
      } catch (_) {
        if (mounted) setState(() => _playing = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return FutureBuilder<List<AdhanVoice>>(
      future: Deps.adhan.voices(),
      builder: (context, snap) {
        final voices = snap.data ?? const <AdhanVoice>[];
        return ListenableBuilder(
          listenable: Deps.settings,
          builder: (context, _) {
            final cur = Deps.settings.voice;
            Widget tile(String id, String name, AdhanVoice? v) => ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icon(cur == id ? AppIcons.checkOn : AppIcons.checkOff, color: cur == id ? p.green : p.muted),
                  title: Text(name, style: const TextStyle(fontSize: 16)),
                  trailing: v == null
                      ? null
                      : GlassIconButton(
                          size: 40,
                          icon: _playing == id ? AppIcons.stop : AppIcons.play,
                          tooltip: 'معاينة',
                          onTap: () => _toggle(v)),
                  onTap: () => Deps.settings.put('voice', id),
                );
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Text('المؤذن وصوت الأذان', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                tile('', 'صوت الإشعار الافتراضي', null),
                for (final v in voices) tile(v.id, v.name, v),
                if (snap.connectionState == ConnectionState.done && voices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'لا توجد أصوات أذان بعد. ضع ملفات mp3 داخل assets/adhan وأعد بناء التطبيق.',
                      style: TextStyle(color: p.muted, height: 1.7),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
