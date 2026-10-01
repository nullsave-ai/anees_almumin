import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/adhkar_data.dart';

AdhkarCategory? _suggested() {
  final h = DateTime.now().hour;
  if (h >= 4 && h < 11) return adhkarCategories[0];
  if (h >= 15 && h < 20) return adhkarCategories[1];
  if (h >= 21 || h < 3) return adhkarCategories[3];
  return null;
}

class AdhkarScreen extends StatelessWidget {
  const AdhkarScreen({super.key, required this.controller});
  final ScrollController controller;

  void _open(BuildContext context, AdhkarCategory c) =>
      Navigator.push(context, smoothRoute(AdhkarDetail(category: c)));

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final s = _suggested();
    return PageBody(
      child: ListView(
        controller: controller,
        padding: pagePad(context),
        children: [
          const TabHeader(title: 'الأذكار', subtitle: 'اختر القسم'),
          if (s != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassCard(
                radius: 28,
                tint: s.color.withAlpha(p.dark ? 60 : 40),
                onTap: () => _open(context, s),
                child: Row(children: [
                  IconBadge(icon: s.icon, size: 50, color: s.color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('الآن', style: TextStyle(fontSize: 12, color: p.muted)),
                      const SizedBox(height: 2),
                      Text(s.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  Icon(AppIcons.forward, color: s.color),
                ]),
              ),
            ),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.05,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final cat in adhkarCategories) _CatTile(cat: cat, onTap: () => _open(context, cat)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatTile extends StatelessWidget {
  const _CatTile({required this.cat, required this.onTap});
  final AdhkarCategory cat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GlassCard(
      radius: 30,
      tint: cat.color.withAlpha(p.dark ? 40 : 26),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Stack(fit: StackFit.expand, children: [
        Positioned(bottom: -18, left: -14, child: Icon(cat.icon, size: 96, color: cat.color.withAlpha(34))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconBadge(icon: cat.icon, size: 48, color: cat.color),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cat.title, maxLines: 2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.3)),
            const SizedBox(height: 3),
            Text('${ar(cat.items.length)} ذكرًا', style: TextStyle(fontSize: 12, color: p.muted)),
          ]),
        ]),
      ]),
    );
  }
}

class AdhkarDetail extends StatefulWidget {
  const AdhkarDetail({super.key, required this.category});
  final AdhkarCategory category;

  @override
  State<AdhkarDetail> createState() => _AdhkarDetailState();
}

class _AdhkarDetailState extends State<AdhkarDetail> {
  late List<int> _left = [for (final d in widget.category.items) d.count];
  late bool _pager = Deps.settings.prefs.getBool('apager') ?? true;
  int _page = 0;

  /// يرجع true إذا اكتمل الذكر بهذه الضغطة.
  bool _tap(int i) {
    if (_left[i] == 0) return false;
    final done = _left[i] == 1;
    if (done) HapticFeedback.mediumImpact();
    setState(() => _left[i]--);
    return done;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.category.items;
    return GlassPage(
      title: widget.category.title,
      actions: [
        GlassIconButton(
          icon: _pager ? AppIcons.rows : AppIcons.cards,
          tooltip: _pager ? 'عرض قائمة' : 'عرض بطاقات',
          size: 40,
          onTap: () {
            setState(() => _pager = !_pager);
            Deps.settings.prefs.setBool('apager', _pager);
          },
        ),
        GlassIconButton(
          icon: AppIcons.reset,
          tooltip: 'إعادة العدادات',
          size: 40,
          onTap: () => setState(() {
            _left = [for (final d in items) d.count];
            _page = 0;
          }),
        ),
      ],
      child: PageBody(
        child: _pager
            ? _Pager(
                key: ValueKey('p${_left.where((e) => e != 0).length == items.length}'),
                items: items,
                left: _left,
                initialPage: _page,
                color: widget.category.color,
                onPage: (i) => _page = i,
                onTap: _tap,
              )
            : _listView(context),
      ),
    );
  }

  Widget _listView(BuildContext context) {
    final p = context.pal;
    final items = widget.category.items;
    return ListView.builder(
      padding: pagePad(context, nav: false, extraTop: 66),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final d = items[i];
        final done = _left[i] == 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: GlassCard(
            onTap: () => _tap(i),
            radius: 28,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(children: [
              if (d.title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(d.title!, style: TextStyle(fontSize: 13, color: p.green, fontWeight: FontWeight.w700)),
                ),
              Text(d.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, height: 2, color: done ? p.muted : p.ink)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1 - _left[i] / d.count,
                  minHeight: 5,
                  backgroundColor: p.green.withAlpha(34),
                  valueColor: AlwaysStoppedAnimation(p.green),
                ),
              ),
              const SizedBox(height: 10),
              done
                  ? Icon(AppIcons.checkOn, color: p.green, size: 26)
                  : Text('${ar(_left[i])} / ${ar(d.count)}',
                      style: TextStyle(color: p.green, fontWeight: FontWeight.w800, fontSize: 17)),
            ]),
          ),
        );
      },
    );
  }
}

/// عرض البطاقات: ذكر في كل صفحة، عدّاد حلقي كبير، انتقال تلقائي عند الاكتمال.
class _Pager extends StatefulWidget {
  const _Pager({
    super.key,
    required this.items,
    required this.left,
    required this.initialPage,
    required this.color,
    required this.onPage,
    required this.onTap,
  });
  final List<Dhikr> items;
  final List<int> left;
  final int initialPage;
  final Color color;
  final ValueChanged<int> onPage;
  final bool Function(int) onTap;

  @override
  State<_Pager> createState() => _PagerState();
}

class _PagerState extends State<_Pager> {
  late final PageController _pc = PageController(viewportFraction: .92, initialPage: widget.initialPage);
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _handleTap(int i) {
    final done = widget.onTap(i);
    if (done && i < widget.items.length - 1) {
      Future.delayed(const Duration(milliseconds: 420), () {
        if (mounted && _page == i && _pc.hasClients) {
          _pc.animateToPage(i + 1, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final m = MediaQuery.of(context).padding;
    final n = widget.items.length;
    final done = widget.left.where((e) => e == 0).length;
    return Column(children: [
      SizedBox(height: m.top + 78),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(children: [
          Text('${ar(_page + 1)} / ${ar(n)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          Icon(AppIcons.checkRing, size: 18, color: p.green),
          const SizedBox(width: 4),
          Text('${ar(done)} مكتمل', style: TextStyle(fontSize: 13, color: p.muted)),
        ]),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: n == 0 ? 0 : done / n,
            minHeight: 5,
            backgroundColor: widget.color.withAlpha(40),
            valueColor: AlwaysStoppedAnimation(widget.color),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: PageView.builder(
          controller: _pc,
          itemCount: n,
          onPageChanged: (i) {
            setState(() => _page = i);
            widget.onPage(i);
          },
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
            child: _PagerCard(
              dhikr: widget.items[i],
              index: i,
              left: widget.left[i],
              color: widget.color,
              onTap: () => _handleTap(i),
            ),
          ),
        ),
      ),
      SizedBox(height: m.bottom + 22),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withAlpha(34), borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );
}

class _PagerCard extends StatelessWidget {
  const _PagerCard(
      {required this.dhikr, required this.index, required this.left, required this.color, required this.onTap});
  final Dhikr dhikr;
  final int index, left;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final done = left == 0;
    return GlassCard(
      radius: 36,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      onTap: onTap,
      child: Column(children: [
        Row(children: [
          _Chip(text: dhikr.title ?? 'ذكر ${ar(index + 1)}', color: color),
          const Spacer(),
          _Chip(text: 'التكرار ${ar(dhikr.count)}', color: p.muted),
        ]),
        Expanded(
          child: LayoutBuilder(
            builder: (context, cons) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: cons.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      dhikr.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: dhikr.text.length > 220 ? 20 : 25, height: 2.0, color: p.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _Counter(left: left, total: dhikr.count, color: color),
        const SizedBox(height: 8),
        Text(done ? 'أحسنت، تم الذكر' : 'اضغط للعدّ', style: TextStyle(fontSize: 12, color: p.muted)),
      ]),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.left, required this.total, required this.color});
  final int left, total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final done = left == 0;
    return SizedBox(
      width: 108,
      height: 108,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CountRing(1 - left / total, color, p.gold, color.withAlpha(36)),
          child: Center(
            child: done
                ? Icon(AppIcons.check, size: 42, color: p.gold)
                : Text(ar(left), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: color)),
          ),
        ),
      ),
    );
  }
}

class _CountRing extends CustomPainter {
  _CountRing(this.progress, this.color, this.gold, this.track);
  final double progress;
  final Color color, gold, track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(7);
    canvas.drawArc(r, 0, 2 * math.pi, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 8..color = track);
    canvas.drawArc(
      r,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = progress >= 1 ? gold : color,
    );
  }

  @override
  bool shouldRepaint(_CountRing o) => o.progress != progress || o.color != color;
}
