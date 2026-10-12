import 'package:flutter/material.dart';

/// The approved kinetic-type look (design/kinetic-preview.html, 2026-10-12):
/// dark ink ground, bone type, and colour that comes only from split tags.
abstract final class Tone {
  static const ground = Color(0xFF101011);
  static const surface = Color(0xFF19191B);
  static const raised = Color(0xFF232326);
  static const bone = Color(0xFFEBE6DC);
  static const mute = Color(0xFF8D887F);
  static const line = Color(0xFF2C2C30);
  static const pr = Color(0xFFF2B530);
  static const danger = Color(0xFFFF5A36);
  static const good = Color(0xFF2FBF71);
}

/// Default split colours. Every one can be recoloured in Profile.
abstract final class SplitColors {
  static const legs = Color(0xFF3D7BFF);
  static const push = Color(0xFFFF5A36);
  static const pull = Color(0xFF2FBF71);
  static const upper = Color(0xFFA070FF);
  static const lower = Color(0xFF13B5A6);
  static const full = Color(0xFFF2B530);
  static const arms = Color(0xFFFF8A3D);
  static const core = Color(0xFF7FB8FF);
  static const cardio = Color(0xFFFF4F9A);
  static const rest = Color(0xFF6B6862);

  /// Offered when recolouring, so a custom split still looks like it belongs.
  static const palette = [
    legs, push, pull, upper, lower, full, arms, core, cardio,
    Color(0xFFE0E05A), Color(0xFF55D6F0), Color(0xFFFF7A7A),
  ];
}

/// Text on a split-coloured surface: ink on every default (all are light
/// enough), bone if someone picks a dark custom colour.
Color onColor(Color c) =>
    c.computeLuminance() > 0.18 ? Tone.ground : Tone.bone;

/// Display type: Archivo variable, width 62-125, weight 100-900.
TextStyle display(
  double size, {
  double wdth = 100,
  double wght = 800,
  Color color = Tone.bone,
  double height = .9,
  double letterSpacing = 0,
}) =>
    TextStyle(
      fontFamily: 'Archivo',
      fontSize: size,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
      fontVariations: [
        FontVariation('wdth', wdth.clamp(62, 125)),
        FontVariation('wght', wght.clamp(100, 900)),
      ],
    );

/// Labels and data: IBM Plex Mono.
TextStyle mono(
  double size, {
  Color color = Tone.mute,
  FontWeight weight = FontWeight.w400,
  double letterSpacing = 0,
  double height = 1.4,
}) =>
    TextStyle(
      fontFamily: 'PlexMono',
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Uppercase spaced label, the "LBL" of the preview.
TextStyle label({Color color = Tone.mute}) =>
    mono(10.5, color: color, letterSpacing: 1.3, weight: FontWeight.w500);

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    surface: Tone.surface,
    primary: Tone.bone,
    onPrimary: Tone.ground,
    secondary: Tone.bone,
    onSurface: Tone.bone,
    error: Tone.danger,
    outline: Tone.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Tone.ground,
    fontFamily: 'PlexMono',
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: Tone.ground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: display(26, wdth: 80, wght: 850),
      foregroundColor: Tone.bone,
    ),
    dividerTheme: const DividerThemeData(color: Tone.line, thickness: 1, space: 1),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Tone.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Tone.line,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Tone.surface,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Tone.raised,
      labelStyle: mono(13),
      hintStyle: mono(13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Tone.bone,
      contentTextStyle: mono(13, color: Tone.ground),
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Tone.ground : Tone.mute,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Tone.bone : Tone.raised,
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: Tone.bone),
  );
}
