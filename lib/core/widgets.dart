import 'package:flutter/material.dart';

import 'di.dart';
import 'format.dart';
import 'theme.dart';

class SoftCard extends StatelessWidget {
  const SoftCard(
      {super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: color ?? Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x1F16302B)),
      ),
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// يحدّ عرض المحتوى على الأجهزة اللوحية.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: child),
      );
}

class Message extends StatelessWidget {
  const Message({super.key, required this.icon, required this.text, this.actions = const []});
  final IconData icon;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: AppColors.green),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.6)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: actions),
        ]),
      ),
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

Future<String?> pickOne(BuildContext context, String title, Map<String, String> options,
    String? current) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title),
      children: [
        for (final e in options.entries)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, e.key),
            child: Row(children: [
              Expanded(child: Text(e.value, style: const TextStyle(fontSize: 16))),
              if (e.key == current) const Icon(Icons.check, size: 18, color: AppColors.green),
            ]),
          ),
      ],
    ),
  );
}
