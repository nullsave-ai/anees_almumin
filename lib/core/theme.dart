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
  });
  final bool dark;
  final Color bg, ink, green, gold, glass, edge;
  Color get muted => ink.withAlpha(150);

  static const light = Pal(
    dark: false,
    bg: Color(0xFFF4F1EA),
    ink: Color(0xFF16302B),
    green: Color(0xFF1F6F5C),
    gold: Color(0xFFB8934A),
    glass: Color(0xB3FFFFFF),
    edge: Color(0x80FFFFFF),
  );
  static const night = Pal(
    dark: true,
    bg: Color(0xFF0B1613),
    ink: Color(0xFFE6F0EC),
    green: Color(0xFF4FB99B),
    gold: Color(0xFFD9B56A),
    glass: Color(0x1FFFFFFF),
    edge: Color(0x2EFFFFFF),
  );
}

extension PalX on BuildContext {
  Pal get pal => Theme.of(this).brightness == Brightness.dark ? Pal.night : Pal.light;
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Pal.night : Pal.light;
  final base = ThemeData(brightness: b, useMaterial3: true);
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6F5C), brightness: b)
        .copyWith(primary: p.green, surface: p.bg),
    scaffoldBackgroundColor: p.bg,
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: p.edge,
    listTileTheme: ListTileThemeData(iconColor: p.green, textColor: p.ink),
  );
}
