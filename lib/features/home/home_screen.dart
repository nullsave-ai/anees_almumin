import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/adhkar_data.dart';
import '../../services/prayer_service.dart';
import '../prayer/prayer_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});
  final void Function(int) onOpenTab;

  @override
  Widget build(BuildContext context) {
    final c = Deps.prayer;
    final p = context.pal;
    final now = DateTime.now();
    return PageBody(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: pagePad(context),
          children: [
            Reveal(
              index: 0,
              child: TabHeader(
                title: hijriLabel(now),
                subtitle: gregorianLabel(now),
                actions: [
                  GlassIconButton(
                    icon: p.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    tooltip: p.dark ? 'الوضع الفاتح' : 'الوضع الليلي',
                    onTap: () => Deps.settings.put('theme', p.dark ? 'light' : 'dark'),
                  ),
                ],
              ),
            ),
            Reveal(
              index: 1,
              child: AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: KeyedSubtree(key: ValueKey(c.status), child: _top(context, c)),
                ),
              ),
            ),
            if (c.status == LoadState.ready) ...[
              const SizedBox(height: 16),
              Reveal(index: 2, child: _Strip(c: c)),
            ],
            const SizedBox(height: 22),
            Reveal(
              index: 3,
              child: Row(children: [
                Expanded(
                  child: Floating(
                    amplitude: 3,
                    period: 3600,
                    child: _Shortcut(
                        icon: Icons.menu_book_rounded,
                        label: 'القرآن الكريم',
                        sub: '${ar(114)} سورة',
                        onTap: () => onOpenTab(2)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Floating(
                    amplitude: 3,
                    period: 4200,
                    phase: .5,
                    child: _Shortcut(
                        icon: Icons.self_improvement,
                        label: 'الأذكار',
                        sub: '${ar(adhkarCategories.length)} أقسام',
                        onTap: () => onOpenTab(3)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _top(BuildContext context, PrayerController c) {
    switch (c.status) {
      case LoadState.loading:
        return const Padding(padding: EdgeInsets.symmetric(vertical: 70), child: Center(child: CircularProgressIndicator()));
      case LoadState.ready:
        return _Hero(c: c);
      default:
        return GlassCard(
          child: Message(
            icon: Icons.location_off_outlined,
            text: c.error ?? 'تعذر عرض أوقات الصلاة.',
            actions: [
              FilledButton.icon(
                  onPressed: () => onOpenTab(1),
                  icon: const Icon(Icons.access_time),
                  label: const Text('أوقات الصلاة')),
            ],
          ),
        );
    }
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
    return Floating(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: p.dark ? const [Color(0xFF1E7A64), Color(0xFF0F3E34)] : const [Color(0xFF1F6F5C), Color(0xFF14483C)],
          ),
          boxShadow: [BoxShadow(color: p.green.withAlpha(p.dark ? 70 : 110), blurRadius: 34, offset: const Offset(0, 18))],
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
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (w, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, .35), end: Offset.zero).animate(a), child: w),
                      ),
                      child: Text(prayerNames[c.next]!,
                          key: ValueKey(c.next),
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.schedule, size: 17, color: p.gold),
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
      child: ValueListenableBuilder<Duration>(
        valueListenable: c.remaining,
        builder: (_, d, __) {
          final total = c.nextTime!
              .difference(c.prevTime ?? c.nextTime!.subtract(const Duration(hours: 4)))
              .inSeconds;
          final prog = total <= 0 ? 0.0 : (1 - d.inSeconds / total).clamp(0.0, 1.0);
          return CustomPaint(
            painter: _RingPainter(prog),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FittedBox(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('المتبقي', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(fmtCountdown(d),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(6);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.white.withAlpha(36);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [Color(0xFFD9B56A), Colors.white],
      ).createShader(rect);
    canvas.drawArc(r, -math.pi / 2, 2 * math.pi, false, track);
    canvas.drawArc(r, -math.pi / 2, 2 * math.pi * progress, false, arc);
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
    final content = SizedBox.expand(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(prayerIcons[kind], size: 22, color: isNext ? Colors.white : p.green),
        const SizedBox(height: 8),
        FittedBox(
            child: Text(prayerNames[kind]!,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isNext ? Colors.white : p.ink))),
        const SizedBox(height: 4),
        FittedBox(
            child: Text(fmtTime(c.today[kind]!),
                style: TextStyle(fontSize: 12, color: isNext ? Colors.white70 : p.muted))),
      ]),
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      padding: EdgeInsets.only(top: isNext ? 0 : 16, bottom: isNext ? 16 : 0),
      child: AnimatedOpacity(
        opacity: passed ? .55 : 1,
        duration: const Duration(milliseconds: 400),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          child: isNext
              ? Container(
                  key: const ValueKey('next'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: p.dark ? const [Color(0xFF1E7A64), Color(0xFF0F3E34)] : const [Color(0xFF1F6F5C), Color(0xFF14483C)],
                    ),
                    boxShadow: [BoxShadow(color: p.green.withAlpha(110), blurRadius: 22, offset: const Offset(0, 10))],
                  ),
                  child: content,
                )
              : GlassBox(key: const ValueKey('glass'), radius: 26, blur: 14, child: content),
        ),
      ),
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
