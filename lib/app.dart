import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di.dart';
import 'core/glass.dart';
import 'core/theme.dart';
import 'features/adhkar/adhkar_screen.dart';
import 'features/home/home_screen.dart';
import 'features/prayer/prayer_screen.dart';
import 'features/quran/quran_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Deps.settings,
      builder: (context, _) => MaterialApp(
        title: 'أنيس المؤمن',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: Deps.settings.themeMode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
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

  Widget _tab(int i) {
    if (!_built.contains(i)) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return HomeScreen(onOpenTab: _go);
      case 1:
        return const PrayerScreen();
      case 2:
        return const QuranScreen();
      default:
        return const AdhkarScreen();
    }
  }

  void _go(int i) => setState(() {
        _index = i;
        _built.add(i);
      });

  @override
  Widget build(BuildContext context) {
    final m = MediaQuery.of(context).padding;
    final p = context.pal;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayFor(p),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(children: [
          const Positioned.fill(child: AppBackground()),
          for (var i = 0; i < 4; i++)
            Positioned.fill(child: _TabPage(selected: i == _index, child: _tab(i))),
          // سحابة ضبابية أعلى الشاشة (خلف شريط الحالة) وأسفلها (خلف أزرار النظام)
          Positioned(top: 0, left: 0, right: 0, child: EdgeFade(height: m.top + 36)),
          Positioned(bottom: 0, left: 0, right: 0, child: EdgeFade(top: false, height: m.bottom + 150)),
          Positioned(
            bottom: m.bottom + 12,
            left: 16,
            right: 16,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: GlassNavBar(index: _index, onTap: _go),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TabPage extends StatelessWidget {
  const _TabPage({required this.selected, required this.child});
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) => TickerMode(
        enabled: selected,
        child: ExcludeSemantics(
          excluding: !selected,
          child: IgnorePointer(
            ignoring: !selected,
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              child: AnimatedSlide(
                offset: selected ? Offset.zero : const Offset(0, .025),
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeOutCubic,
                child: child,
              ),
            ),
          ),
        ),
      );
}

class GlassNavBar extends StatelessWidget {
  const GlassNavBar({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const _items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
    (Icons.access_time, Icons.access_time_filled, 'أوقات الصلاة'),
    (Icons.menu_book_outlined, Icons.menu_book_rounded, 'القرآن'),
    (Icons.self_improvement_outlined, Icons.self_improvement, 'الأذكار'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GlassBox(
      radius: 32,
      blur: 26,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: 62,
        child: Stack(children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            alignment: AlignmentDirectional(-1 + 2 * index / (_items.length - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / _items.length,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  color: p.green.withAlpha(p.dark ? 70 : 38),
                  border: Border.all(color: p.green.withAlpha(60)),
                ),
              ),
            ),
          ),
          Row(children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  icon: _items[i].$1,
                  activeIcon: _items[i].$2,
                  label: _items[i].$3,
                  selected: i == index,
                  onTap: () => onTap(i),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.icon, required this.activeIcon, required this.label, required this.selected, required this.onTap});
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedScale(
          scale: selected ? 1.16 : 1,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
            child: Icon(selected ? activeIcon : icon,
                key: ValueKey(selected), size: 24, color: selected ? p.green : p.muted),
          ),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? p.green : p.muted),
          child: Text(label, maxLines: 1),
        ),
      ]),
    );
  }
}
