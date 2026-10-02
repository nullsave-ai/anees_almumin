import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di.dart';
import 'core/glass.dart';
import 'core/icons.dart';
import 'core/theme.dart';
import 'features/adhkar/adhkar_screen.dart';
import 'features/home/home_screen.dart';
import 'features/prayer/prayer_screen.dart';
import 'features/quran/quran_screen.dart';

class App extends StatelessWidget {
  const App({super.key});
  static final _light = buildTheme(Brightness.light);
  static final _dark = buildTheme(Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: Deps.settings.themeN,
      builder: (context, mode, _) => MaterialApp(
        title: 'أنيس المؤمن',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: mode,
        theme: _light,
        darkTheme: _dark,
        home: const Shell(),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  final _built = <int>{0};
  final _sc = List.generate(4, (_) => ScrollController());
  final _barsOn = ValueNotifier<bool>(true);

  @override
  void dispose() {
    for (final c in _sc) {
      c.dispose();
    }
    _barsOn.dispose();
    super.dispose();
  }

  Widget _tab(int i) {
    if (!_built.contains(i)) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return HomeScreen(onOpenTab: _go, controller: _sc[0]);
      case 1:
        return PrayerScreen(controller: _sc[1]);
      case 2:
        return QuranScreen(controller: _sc[2]);
      default:
        return AdhkarScreen(controller: _sc[3]);
    }
  }

  /// تبديل فوري بدون حركة (كتطبيقات X وThreads). الضغط على التبويب الحالي يعيد للأعلى.
  void _go(int i) {
    _barsOn.value = true;
    if (i == _index) {
      final c = _sc[i];
      if (c.hasClients && c.offset > 0) {
        c.animateTo(0, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
      }
      return;
    }
    setState(() {
      _index = i;
      _built.add(i);
    });
  }

  /// إخفاء الشريط عند التمرير للأسفل وإظهاره عند التمرير للأعلى.
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.reverse && n.metrics.pixels > 80) {
        if (_barsOn.value) _barsOn.value = false;
      } else if (n.direction == ScrollDirection.forward) {
        if (!_barsOn.value) _barsOn.value = true;
      }
    } else if (n is ScrollUpdateNotification && n.metrics.pixels <= 0 && !_barsOn.value) {
      _barsOn.value = true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final m = MediaQuery.of(context).padding;
    final p = context.pal;
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayFor(p),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: Stack(children: [
              const Positioned.fill(child: AppBackground()),
              for (var i = 0; i < 4; i++)
                Positioned.fill(
                  child: Offstage(offstage: i != _index, child: TickerMode(enabled: i == _index, child: _tab(i))),
                ),
              Positioned(top: 0, left: 0, right: 0, child: EdgeFade(height: m.top + 30)),
              Positioned(bottom: 0, left: 0, right: 0, child: EdgeFade(top: false, height: m.bottom + 24)),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _barsOn,
                  builder: (_, on, child) => AnimatedSlide(
                    offset: on ? Offset.zero : const Offset(0, 1.4),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: child,
                  ),
                  child: Stack(alignment: Alignment.bottomCenter, children: [
                    EdgeFade(top: false, height: m.bottom + 120),
                    Padding(
                      padding: EdgeInsets.fromLTRB(40, 0, 40, m.bottom + 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: GlassNavBar(index: _index, onTap: _go),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// شريط تنقل عائم بأيقونات فقط (أسلوب Threads): الأيقونة الممتلئة = التبويب الحالي.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = <(IconData, IconData, String)>[
    (AppIcons.home, AppIcons.homeOn, 'الرئيسية'),
    (AppIcons.clock, AppIcons.clockOn, 'أوقات الصلاة'),
    (AppIcons.quran, AppIcons.quranOn, 'القرآن'),
    (AppIcons.azkar, AppIcons.azkarOn, 'الأذكار'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return ValueListenableBuilder<bool>(
      valueListenable: Deps.settings.blurN,
      builder: (context, _, __) => GlassBox(
        radius: 30,
        blur: 14,
        tint: p.dark ? const Color(0xE6141F12) : const Color(0xF2FFFFFF),
        child: SizedBox(
          height: 56,
          child: Row(children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: _items[i].$3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(i);
                    },
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(i == index ? _items[i].$2 : _items[i].$1,
                          size: 26, color: i == index ? p.green : p.muted),
                      const SizedBox(height: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: i == index ? p.green : Colors.transparent),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
