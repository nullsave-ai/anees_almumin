import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'di.dart';
import 'icons.dart';
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

/// سطح زجاجي خفيف: تدرج شفاف + حدود + ظل ناعم.
/// الـ blur الحقيقي (BackdropFilter) لا يُطبَّق إلا إذا طُلب blur > 0 وكان مفعّلًا من الإعدادات.
class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key,
    required this.child,
    this.radius = 24,
    this.blur = 0,
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
    Widget box = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: r,
        border: Border.all(color: p.edge),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [base, base.withAlpha((base.alpha * .72).round())],
        ),
      ),
      child: child,
    );
    if (blur > 0 && Deps.settings.blur) {
      box = BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: box);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow
            ? [BoxShadow(color: Colors.black.withAlpha(p.dark ? 70 : 20), blurRadius: 14, offset: const Offset(0, 6))]
            : null,
      ),
      child: ClipRRect(borderRadius: r, child: box),
    );
  }
}

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = .97});
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
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
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
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? tint;
  final double radius;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: GlassBox(radius: radius, tint: tint, padding: padding, child: child),
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
      scale: .9,
      child: GlassBox(
        radius: size / 2,
        child: SizedBox(width: size, height: size, child: Icon(icon, color: active ? p.green : p.ink, size: 22)),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// ظهور خفيف للعناصر الأولى فقط (أول 6) لتجنب التقطيع أثناء التمرير.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) => index >= 6 ? child : _RevealAnim(index: index, child: child);
}

class _RevealAnim extends StatefulWidget {
  const _RevealAnim({required this.child, required this.index});
  final Widget child;
  final int index;

  @override
  State<_RevealAnim> createState() => _RevealAnimState();
}

class _RevealAnimState extends State<_RevealAnim> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
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
          position: Tween<Offset>(begin: const Offset(0, .08), end: Offset.zero).animate(_a),
          child: widget.child,
        ),
      );
}

/// حافة متدرجة (سحابة) فوق المحتوى بدون blur: خفيفة جدًا على المعالج.
class EdgeFade extends StatelessWidget {
  const EdgeFade({super.key, required this.height, this.top = true});
  final double height;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final near = top
        ? p.bg.withAlpha(242)
        : Color.alphaBlend(p.green.withAlpha(p.dark ? 46 : 32), p.bg).withAlpha(246);
    final far = (top ? p.bg : Color.alphaBlend(p.gold.withAlpha(p.dark ? 18 : 26), p.bg)).withAlpha(0);
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
              colors: [near, near.withAlpha(150), far],
              stops: const [0, .45, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  Widget _blob(Color c, double size, int alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle, gradient: RadialGradient(colors: [c.withAlpha(alpha), c.withAlpha(0)])),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return RepaintBoundary(
      child: ColoredBox(
        color: p.bg,
        child: Stack(children: [
          Positioned(top: -120, right: -110, child: _blob(p.green, 420, p.dark ? 64 : 56)),
          Positioned(top: 420, left: -170, child: _blob(p.gold, 400, p.dark ? 30 : 44)),
          Positioned(bottom: -100, right: -120, child: _blob(p.green, 360, p.dark ? 46 : 38)),
        ]),
      ),
    );
  }
}

/// صفحة داخلية بشريط علوي عائم.
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
          Positioned(top: 0, left: 0, right: 0, child: EdgeFade(height: m.top + 84)),
          Positioned(
            top: m.top + 10,
            left: 16,
            right: 16,
            child: Row(children: [
              GlassIconButton(icon: AppIcons.back, tooltip: 'رجوع', onTap: () => Navigator.of(context).maybePop()),
              Expanded(
                child: Center(
                  child: GlassBox(
                    radius: 22,
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
          Positioned(bottom: 0, left: 0, right: 0, child: EdgeFade(top: false, height: m.bottom + 50)),
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
    final blur = Deps.settings.blur;
    Widget body = Container(
      decoration: BoxDecoration(
        border: Border.all(color: p.edge),
        borderRadius: BorderRadius.circular(32),
        color: p.dark ? Color(blur ? 0xD90C140B : 0xF50C140B) : Color(blur ? 0xE6F6F9F0 : 0xF7F6F9F0),
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
    );
    if (blur) body = BackdropFilter(filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24), child: body);
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: mq.size.height * .86),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + mq.padding.bottom),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(70), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: ClipRRect(borderRadius: BorderRadius.circular(32), child: body),
          ),
        ),
      ),
    );
  }
}

/// ورقة سفلية: تعتيم + صعود سلس (والضبابية الحقيقية اختيارية من الإعدادات).
Future<T?> showGlassSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق',
    barrierColor: Colors.black.withAlpha(90),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, _, __) => _SheetFrame(child: builder(ctx)),
    transitionBuilder: (ctx, anim, _, child) {
      final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return SlideTransition(position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(c), child: child);
    },
  );
}

/// انتقال أصلي كتطبيقات Threads و X: انزلاق مع تأثير بارالاكس وسحب من الحافة للرجوع.
Route<T> smoothRoute<T>(Widget page) => CupertinoPageRoute<T>(builder: (_) => page);
