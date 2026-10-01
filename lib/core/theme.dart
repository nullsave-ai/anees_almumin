import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

class Pal {
  const Pal({
    required this.dark,
    required this.bg,
    required this.ink,
    required this.green,
    required this.gold,
    required this.glass,
    required this.edge,
    required this.hero1,
    required this.hero2,
  });
  final bool dark;
  final Color bg, ink, green, gold, glass, edge, hero1, hero2;
  Color get muted => ink.withAlpha(150);
  List<Color> get hero => [hero1, hero2];

  // أخضر العشب
  static const light = Pal(
    dark: false,
    bg: Color(0xFFF3F7EC),
    ink: Color(0xFF1A2616),
    green: Color(0xFF4F9D2D),
    gold: Color(0xFFC9A13B),
    glass: Color(0xCCFFFFFF),
    edge: Color(0x1F1A2616),
    hero1: Color(0xFF5CAA30),
    hero2: Color(0xFF2F7A1E),
  );
  static const night = Pal(
    dark: true,
    bg: Color(0xFF0C140B),
    ink: Color(0xFFE8F0E3),
    green: Color(0xFF7CC24A),
    gold: Color(0xFFDDB75A),
    glass: Color(0x26FFFFFF),
    edge: Color(0x26FFFFFF),
    hero1: Color(0xFF4F9D2D),
    hero2: Color(0xFF24541A),
  );
}

extension PalX on BuildContext {
  Pal get pal => Theme.of(this).brightness == Brightness.dark ? Pal.night : Pal.light;
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Pal.night : Pal.light;
  final base = ThemeData(brightness: b, useMaterial3: true);
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F9D2D), brightness: b)
        .copyWith(primary: p.green, surface: p.bg),
    scaffoldBackgroundColor: p.bg,
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    splashFactory: NoSplash.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    highlightColor: Colors.transparent,
    dividerColor: p.edge,
    listTileTheme: ListTileThemeData(iconColor: p.green, textColor: p.ink),
  );
}
