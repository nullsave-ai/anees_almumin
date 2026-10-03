import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/adhkar_data.dart';
import '../../services/prayer_service.dart';
import '../wallpapers/wallpapers_screen.dart';
import '../prayer/prayer_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab, required this.controller});
  final void Function(int) onOpenTab;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final now = DateTime.now();
    return PageBody(
      child: RefreshIndicator(
        color: p.green,
        edgeOffset: MediaQuery.paddingOf(context).top + 8,
        onRefresh: () => Deps.prayer.refresh(relocate: true, silent: true),
        child: ListView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: pagePad(context),
          children: [
            Reveal(
              index: 0,
              child: TabHeader(
                title: hijriLabel(now),
                subtitle: gregorianLabel(now),
                actions: [
                  GlassIconButton(
                    icon: p.dark ? AppIcons.sun : AppIcons.moon,
                    tooltip: p.dark ? 'الوضع الفاتح' : 'الوضع الليلي',
                    onTap: () => Deps.settings.put('theme', p.dark ? 'light' : 'dark'),
                  ),
                  GlassIconButton(
                    icon: AppIcons.settings,
                    tooltip: 'المظهر',
                    onTap: () => showGlassSheet(context, builder: (_) => const _AppearanceSheet()),
                  ),
                ],
              ),
            ),
            Reveal(index: 1, child: _Dynamic(onOpenTab: onOpenTab)),
            const SizedBox(height: 22),
            Reveal(
              index: 3,
              child: Row(children: [
                Expanded(
                  child: _Shortcut(
                      icon: AppIcons.quran,
                      label: 'القرآن الكريم',
                      sub: '${ar(114)} سورة',
                      onTap: () => onOpenTab(2)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _Shortcut(
                      icon: AppIcons.azkar,
                      label: 'الأذكار',
                      sub: '${ar(adhkarCategories.length)} أقسام',
                      onTap: () => onOpenTab(3)),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Reveal(
              index: 4,
              child: GlassCard(
                radius: 28,
                onTap: () => Navigator.push(context, smoothRoute(const WallpapersScreen())),
                child: Row(children: [
                  IconBadge(icon: AppIcons.wallpaper, size: 50),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('الخلفيات والويدجت', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('خلفيات ثابتة ومتحركة وويدجت الصلاة القادمة',
                          style: TextStyle(fontSize: 12, color: p.muted)),
                    ]),
                  ),
                  Icon(AppIcons.next, color: p.muted),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// الجزء المتغيّر فقط (البطاقة الرئيسية + الشريط) يُعاد بناؤه عند تغير حالة الصلوات.
class _Dynamic extends StatelessWidget {
  const _Dynamic({required this.onOpenTab});
  final void Function(int) onOpenTab;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Deps.prayer,
      builder: (context, _) {
        final c = Deps.prayer;
        switch (c.status) {
          case LoadState.loading:
            return const Skeleton(height: 168, radius: 32);
          case LoadState.ready:
            return Column(children: [_Hero(c: c), const SizedBox(height: 16), _Strip(c: c)]);
          default:
            return GlassCard(
              child: Message(
                icon: AppIcons.pin,
                text: c.error ?? 'تعذر عرض أوقات الصلاة.',
                actions: [
                  FilledButton.icon(
                      onPressed: () => onOpenTab(1), icon: Icon(AppIcons.clock), label: const Text('أوقات الصلاة')),
                ],
              ),
            );
        }
      },
    );
  }
}

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context) {
    final s = Deps.settings;
    const modes = {'system': 'تلقائي (حسب النظام)', 'light': 'فاتح', 'dark': 'ليلي'};
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('المظهر', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        ),
        ListTile(
          leading: Icon(AppIcons.moon),
          title: const Text('الوضع'),
          subtitle: Text(modes[s.theme] ?? ''),
          onTap: () async {
            final v = await pickOne(context, 'الوضع', modes, s.theme);
            if (v != null) s.put('theme', v);
          },
        ),
        SwitchListTile(
          secondary: Icon(AppIcons.settings),
          title: const Text('تأثير الضبابية (blur)'),
          subtitle: const Text('مظهر زجاجي لشريط التنقل والأوراق السفلية. أثقل على الأجهزة الضعيفة'),
          value: s.blur,
          onChanged: (v) => s.put('blur', v),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.c});
  final PrayerController c;

  Widget _circle(double s) => Container(
      width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(20)));

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: p.hero),
        boxShadow: [BoxShadow(color: p.green.withAlpha(p.dark ? 60 : 90), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(children: [
          Positioned(left: -50, bottom: -60, child: _circle(180)),
          Positioned(right: -30, top: -50, child: _circle(130)),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('الصلاة القادمة', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(prayerNames[c.next]!,
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(AppIcons.clock, size: 17, color: p.gold),
                    const SizedBox(width: 6),
                    Text(fmtTime(c.nextTime!), style: const TextStyle(color: Colors.white, fontSize: 17)),
                  ]),
                ]),
              ),
              const SizedBox(width: 12),
              _Ring(c: c),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.c});
  final PrayerController c;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 116,
      child: Stack(children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: LiveValue<Duration>(
              listenable: c.remaining,
              builder: (_, d) {
                final total = c.nextTime!
                    .difference(c.prevTime ?? c.nextTime!.subtract(const Duration(hours: 4)))
                    .inSeconds;
                final raw = total <= 0 ? 0.0 : (1 - d.inSeconds / total).clamp(0.0, 1.0);
                return CustomPaint(painter: _RingPainter((raw * 360).round() / 360));
              },
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FittedBox(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('المتبقي', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const CountdownText(
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(6);
    canvas.drawArc(r, -math.pi / 2, 2 * math.pi, false,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 6..color = Colors.white.withAlpha(36));
    canvas.drawArc(
      r,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _Strip extends StatelessWidget {
  const _Strip({required this.c});
  final PrayerController c;

  @override
  Widget build(BuildContext context) {
    final kinds = [for (final k in PrayerKind.values) if (k != PrayerKind.sunrise) k];
    return SizedBox(
      height: 132,
      child: Row(children: [
        for (final k in kinds)
          Expanded(
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _MiniTile(kind: k, c: c)),
          ),
      ]),
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({required this.kind, required this.c});
  final PrayerKind kind;
  final PrayerController c;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final isNext = c.isNextKind(kind);
    final passed = c.isPassed(kind);
    final main = isNext ? Colors.white : (passed ? p.muted : p.ink);
    final content = SizedBox.expand(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(prayerIcons[kind], size: 24, color: isNext ? Colors.white : (passed ? p.muted : p.green)),
        const SizedBox(height: 8),
        FittedBox(child: Text(prayerNames[kind]!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: main))),
        const SizedBox(height: 4),
        FittedBox(child: Text(fmtTime(c.today[kind]!), style: TextStyle(fontSize: 12, color: isNext ? Colors.white70 : p.muted))),
      ]),
    );
    return Padding(
      padding: EdgeInsets.only(top: isNext ? 0 : 16, bottom: isNext ? 16 : 0),
      child: isNext
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: p.hero),
                boxShadow: [BoxShadow(color: p.green.withAlpha(90), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: content,
            )
          : GlassBox(radius: 26, child: content),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.sub, required this.onTap});
  final IconData icon;
  final String label, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GlassCard(
      onTap: onTap,
      radius: 28,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: SizedBox(
        width: double.infinity,
        child: Column(children: [
          IconBadge(icon: icon, size: 54),
          const SizedBox(height: 14),
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(sub, style: TextStyle(fontSize: 12, color: p.muted)),
        ]),
      ),
    );
  }
}
