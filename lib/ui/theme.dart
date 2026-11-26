import 'package:flutter/material.dart';

/// Colors from the web dashboard (Tailwind zinc + accents).
class C {
  static const bg = Color(0xFF09090B); // zinc-950
  static const panel = Color(0xFF131316);
  static const inset = Color(0xFF0C0C0E);
  static const border = Color(0xFF27272A); // zinc-800
  static const text = Color(0xFFF4F4F5); // zinc-100
  static const muted = Color(0xFFA1A1AA); // zinc-400
  static const faint = Color(0xFF71717A); // zinc-500

  static const battery = Color(0xFF34D399); // emerald-400
  static const danger = Color(0xFFF87171); // red-400
  static const solar = Color(0xFFFBBF24); // amber-400
  static const load = Color(0xFFA78BFA); // violet-400
  static const grid = Color(0xFF38BDF8); // sky-400
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: C.battery,
      brightness: Brightness.dark,
      surface: C.bg,
      primary: C.battery,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: C.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: C.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.bg,
      indicatorColor: C.border,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, color: C.muted)),
    ),
    dividerColor: C.border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.inset,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.border)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.battery)),
      labelStyle: const TextStyle(color: C.muted),
      hintStyle: const TextStyle(color: C.faint),
    ),
    textTheme: base.textTheme.apply(bodyColor: C.text, displayColor: C.text),
  );
}

const tabular = [FontFeature.tabularFigures()];
