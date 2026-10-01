import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

SystemUiOverlayStyle overlayFor(Pal p) {
  final icons = p.dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    statusBarIconBrightness: icons,
    systemNavigationBarIconBrightness: icons,
    statusBarBrightness: p.dark ? Brightness.dark : Brightness.light,
  );
}

EdgeInsets pagePad(BuildContext c, {bool nav = true, double extraTop = 0}) {
  final m = MediaQuery.of(c).padding;
  return EdgeInsets.fromLTRB(20, m.top + 14 + extraTop, 20, m.bottom + (nav ? 124 : 40));
}

/// سطح زجاجي: blur + تدرج شفاف + حدود + ظل ناعم.
class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key,
    required this.child,
    this.radius = 24,
    this.blur = 16,
    this.padding,
    this.tint,
    this.shadow = true,
  });
  final Widget child;
  final double radius, blur;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final r = BorderRadius.circular(radius);
    final base = tint ?? p.glass;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow
            ? [BoxShadow(color: Colors.black.withAlpha(p.dark ? 80 : 26), blurRadius: 26, offset: const Offset(0, 12))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: r,
              border: Border.all(color: p.edge),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [base, base.withAlpha((base.alpha * .62).round())],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = .96});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap!();
      },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
            opacity: _down ? .88 : 1, duration: const Duration(milliseconds: 140), child: widget.child),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.tint,
    this.radius = 24,
    this.blur = 16,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? tint;
  final double radius, blur;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: GlassBox(radius: radius, blur: blur, tint: tint, padding: padding, child: child),
      );
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton(
      {super.key, required this.icon, required this.onTap, this.tooltip, this.size = 44, this.active = false});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final btn = Pressable(
      onTap: onTap,
      scale: .88,
      child: GlassBox(
        radius: size / 2,
        blur: 12,
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (c, a) => RotationTransition(
                turns: Tween<double>(begin: .75, end: 1).animate(a),
                child: FadeTransition(opacity: a, child: c)),
            child: Icon(icon, key: ValueKey(icon), color: active ? p.green : p.ink, size: 22),
          ),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// ظهور متدرج (تلاشي + انزلاق) لكل عنصر عند بنائه.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 560));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    final delay = widget.index >= 10 ? 0 : widget.index * 50;
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _a,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, .12), end: Offset.zero).animate(_a),
          child: widget.child,
        ),
      );
}

/// طفو هادئ للعنصر (حركة رأسية بطيئة).
class Floating extends StatefulWidget {
  const Floating({super.key, required this.child, this.amplitude = 4, this.period = 3400, this.phase = 0});
  final Widget child;
  final double amplitude, phase;
  final int period;

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: Duration(milliseconds: widget.period), value: widget.phase)
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          child: widget.child,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, (Curves.easeInOut.transform(_c.value) * 2 - 1) * widget.amplitude),
            child: child,
          ),
        ),
      );
}

/// حافة ضبابية متدرجة (سحابة) فوق المحتوى: blur يتلاشى + لون متدرج.
class EdgeFade extends StatelessWidget {
  const EdgeFade({super.key, required this.height, this.top = true});
  final double height;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final begin = top ? Alignment.topCenter : Alignment.bottomCenter;
    final end = top ? Alignment.bottomCenter : Alignment.topCenter;
    final near = top
        ? p.bg.withAlpha(p.dark ? 225 : 235)
        : Color.alphaBlend(p.green.withAlpha(p.dark ? 60 : 38), p.bg).withAlpha(235);
    final far = (top ? p.bg : Color.alphaBlend(p.gold.withAlpha(p.dark ? 22 : 30), p.bg)).withAlpha(0);
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: Stack(fit: StackFit.expand, children: [
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => LinearGradient(
                    begin: begin, end: end, colors: const [Colors.black, Colors.transparent], stops: const [.4, 1])
                .createShader(r),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          ),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: begin, end: end, colors: [near, far]))),
        ]),
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  Widget _blob(Color c, double size, int alpha) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [c.withAlpha(alpha), c.withAlpha(0)])),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return RepaintBoundary(
      child: ColoredBox(
        color: p.bg,
        child: Stack(children: [
          Positioned(top: -120, right: -110, child: _blob(p.green, 420, p.dark ? 70 : 60)),
          Positioned(top: 420, left: -170, child: _blob(p.gold, 400, p.dark ? 34 : 50)),
          Positioned(bottom: -100, right: -120, child: _blob(p.green, 360, p.dark ? 50 : 40)),
        ]),
      ),
    );
  }
}

/// صفحة داخلية بشريط علوي زجاجي عائم.
class GlassPage extends StatelessWidget {
  const GlassPage({super.key, required this.title, required this.child, this.actions = const []});
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final m = MediaQuery.of(context).padding;
    final p = context.pal;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(p),
      child: Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: AppBackground()),
          Positioned.fill(child: child),
          Positioned(top: 0, left: 0, right: 0, child: EdgeFade(height: m.top + 92)),
          Positioned(
            top: m.top + 10,
            left: 16,
            right: 16,
            child: Row(children: [
              GlassIconButton(
                  icon: Icons.arrow_back, tooltip: 'رجوع', onTap: () => Navigator.of(context).maybePop()),
              Expanded(
                child: Center(
                  child: GlassBox(
                    radius: 22,
                    blur: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              if (actions.isEmpty) const SizedBox(width: 44),
              for (final a in actions) Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: a),
            ]),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: EdgeFade(top: false, height: m.bottom + 60)),
        ]),
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final mq = MediaQuery.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: mq.size.height * .86),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + mq.padding.bottom),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(90), blurRadius: 40, offset: const Offset(0, 16))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: p.edge),
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.alphaBlend(p.green.withAlpha(30), p.dark ? const Color(0xD90B1613) : const Color(0xE6F8F5EE)),
                        p.dark ? const Color(0xE60B1613) : const Color(0xF2F4F1EA),
                      ],
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragEnd: (d) {
                          if ((d.primaryVelocity ?? 0) > 250) Navigator.of(context).maybePop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 60),
                          child: Container(
                              height: 5,
                              width: 44,
                              decoration: BoxDecoration(color: p.muted.withAlpha(90), borderRadius: BorderRadius.circular(3))),
                        ),
                      ),
                      Flexible(child: child),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ورقة سفلية زجاجية: تضبب الخلفية تدريجيًا وتصعد بحركة ناعمة.
Future<T?> showGlassSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (ctx, _, __) => _SheetFrame(child: builder(ctx)),
    transitionBuilder: (ctx, anim, _, child) {
      final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return Stack(fit: StackFit.expand, children: [
        IgnorePointer(
          child: AnimatedBuilder(
            animation: c,
            builder: (_, __) => BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10 * c.value, sigmaY: 10 * c.value),
              child: ColoredBox(color: Colors.black.withAlpha((100 * c.value).round())),
            ),
          ),
        ),
        SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(c), child: child),
      ]);
    },
  );
}

Route<T> smoothRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 440),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, .06), end: Offset.zero).animate(c),
            child: ScaleTransition(scale: Tween<double>(begin: .97, end: 1).animate(c), child: child),
          ),
        );
      },
    );
