// Astryn liquid glass, ported from the 2013 tree's theme/astryn_glass.dart.
// Pure liquid transparent glass, no frosted matte: star purple slightly
// shifted toward pink-blue (#CDB6FF), blur only on bounded local surfaces.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:prism_ui/shape.dart';

abstract final class AstrynGlass {
  static const double blur = 22.0;
  static const double cardBlur = 14.0;
  static const double dialogBlur = 16.0;
  static const double scrimBlur = 14.0;
  static const double smallBlur = 10.0;

  static List<double> opticsMatrix(double saturation, double brightness) {
    final red = 0.2126 * brightness;
    final green = 0.7152 * brightness;
    final blue = 0.0722 * brightness;
    final rest = 1 - saturation;
    final kept = saturation * brightness;
    return [
      red * rest + kept, green * rest, blue * rest, 0, 0, //
      red * rest, green * rest + kept, blue * rest, 0, 0,
      red * rest, green * rest, blue * rest + kept, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  static Widget frost({
    required double blur,
    required double saturation,
    double brightness = 1.0,
    required Widget child,
  }) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(opticsMatrix(saturation, brightness)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      ),
    );
  }

  static double dockSaturation({required bool isLight}) =>
      isLight ? 2.1 : 1.925;

  static double cardSaturation({required bool isLight}) =>
      isLight ? 2.08 : 2.84;

  static double dialogSaturation({required bool isLight}) =>
      isLight ? 2.0 : 1.75;

  static double dialogBrightness({required bool isLight}) =>
      isLight ? 1.1 : 1.8;

  static double scrimSaturation({required bool isLight}) =>
      isLight ? 2.1 : 1.925;

  static double controlSaturation({required bool isLight}) =>
      isLight ? 2.08 : 2.84;

  // 首卡玻璃底色：浅色取星紫，深色取深空蓝向星紫靠拢的深紫蓝，各自适配明暗。
  static const Color lightHeroTint = Color(0x8CCDB6FF);
  static const double heroTintAlphaLight = 0.55;
  static const double heroTintAlphaDark = 0.45;
  static const Color darkHeroTint = Color(0x734F4A7C);

  static Color heroTint({required bool isLight}) =>
      isLight ? lightHeroTint : darkHeroTint;

  static Color rimColor({required bool isLight}) =>
      Colors.white.withValues(alpha: isLight ? 0.60 : 0.35);

  static Color surfaceRimColor({required bool isLight}) =>
      Colors.white.withValues(alpha: isLight ? 0.65 : 0.35);

  static Color get controlRimColor => Colors.white.withValues(alpha: 0.28);

  static const LinearGradient topSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x38FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.45],
  );

  static Color scrimTint({
    required bool isLight,
    required Color scaffoldBackground,
    required Color accent,
  }) {
    if (isLight) return const Color(0x86CDB6FF);
    return Color.lerp(
      scaffoldBackground,
      accent,
      0.25,
    )!.withValues(alpha: 0.42);
  }

  static Color dialogFill({
    required bool isLight,
    required Color cardBackground,
    required Color accent,
  }) {
    if (isLight) return const Color(0x8CCDB6FF);
    return Color.lerp(cardBackground, accent, 0.12)!.withValues(alpha: 0.63);
  }

  static Color menuFill({
    required bool isLight,
    required Color cardBackground,
    required Color accent,
  }) {
    if (isLight) return const Color(0xDBEDE6FB);
    return Color.lerp(cardBackground, accent, 0.12)!.withValues(alpha: 0.90);
  }

  static Color controlFill({
    required bool isLight,
    required Color cardBackground,
    required Color accent,
  }) {
    if (isLight) return const Color(0x8ACDB6FF);
    return Color.lerp(cardBackground, accent, 0.12)!.withValues(alpha: 0.62);
  }

  static ShapeBorder dialogShape({required bool isLight}) =>
      RoundedSuperellipseBorder(
        borderRadius: AppRadius.all(34),
        side: BorderSide(color: surfaceRimColor(isLight: isLight), width: 1.2),
      );

  static ShapeBorder menuShape({required bool isLight}) =>
      RoundedSuperellipseBorder(
        borderRadius: AppRadius.lg,
        side: BorderSide(color: surfaceRimColor(isLight: isLight), width: 1.2),
      );

  static ShapeBorder topSheetShape({required bool isLight}) =>
      RoundedSuperellipseBorder(
        borderRadius: AppRadius.top(AppCorner.lg),
        side: BorderSide(color: surfaceRimColor(isLight: isLight), width: 1.2),
      );
}
