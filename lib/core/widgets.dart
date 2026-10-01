import 'package:flutter/material.dart';

import 'di.dart';
import 'format.dart';
import 'glass.dart';
import 'theme.dart';

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: child),
      );
}

class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.size = 46, this.color});
  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pal.green;
    return GlassBox(
      radius: size / 2,
      blur: 10,
      shadow: false,
      tint: c.withAlpha(44),
      child: SizedBox(width: size, height: size, child: Icon(icon, color: c, size: size * .5)),
    );
  }
}

class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle!, style: TextStyle(fontSize: 14, color: p.muted)),
              ),
          ]),
        ),
        for (final a in actions) Padding(padding: const EdgeInsetsDirectional.only(start: 10), child: a),
      ]),
    );
  }
}

class Message extends StatelessWidget {
  const Message({super.key, required this.icon, required this.text, this.actions = const []});
  final IconData icon;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        IconBadge(icon: icon, size: 68),
        const SizedBox(height: 18),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.7, color: p.muted)),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: actions),
      ]),
    );
  }
}

class CountdownText extends StatelessWidget {
  const CountdownText({super.key, this.style});
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
        valueListenable: Deps.prayer.remaining,
        builder: (_, d, __) => Text(fmtCountdown(d), style: style),
      );
}

Future<String?> pickOne(BuildContext context, String title, Map<String, String> options, String? current) {
  return showGlassSheet<String>(
    context,
    builder: (ctx) {
      final p = ctx.pal;
      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          for (final e in options.entries)
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(e.value, style: const TextStyle(fontSize: 16)),
              trailing: e.key == current ? Icon(Icons.check_circle, color: p.green) : null,
              onTap: () => Navigator.pop(ctx, e.key),
            ),
        ],
      );
    },
  );
}
