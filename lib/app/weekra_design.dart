import 'package:flutter/material.dart';

/// Shared visual language for Weekra's calm, dark calendar surfaces.
abstract final class WeekraColors {
  static const canvas = Color(0xFF111214);
  static const surface = Color(0xFF191B1E);
  static const surfaceRaised = Color(0xFF202226);
  static const surfacePressed = Color(0xFF292C30);

  static const textPrimary = Color(0xFFF2EFE9);
  static const textSecondary = Color(0xFFA9A49D);
  static const textTertiary = Color(0xFF817C76);

  static const coral = Color(0xFFF1776C);
  static const onAccent = Color(0xFF241311);
  static const divider = Color(0x17FFFFFF);
  static const dividerSubtle = Color(0x0CFFFFFF);
  static const outline = Color(0x26FFFFFF);
}

abstract final class WeekraMetrics {
  static const controlHeight = 38.0;
  static const controlRadius = 10.0;
  static const eventRadius = 7.0;
  static const pageGutter = 24.0;
}

abstract final class WeekraDesign {
  static ThemeData dark({String? fontFamily, Color? accent}) {
    final resolvedAccent = accent ?? WeekraColors.coral;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: resolvedAccent,
      brightness: Brightness.dark,
      surface: WeekraColors.surface,
    ).copyWith(
      primary: resolvedAccent,
      onPrimary: WeekraColors.onAccent,
      surface: WeekraColors.surface,
      onSurface: WeekraColors.textPrimary,
      outline: WeekraColors.outline,
      outlineVariant: WeekraColors.divider,
    );

    const controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(WeekraMetrics.controlRadius),
      ),
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: WeekraColors.canvas,
      canvasColor: WeekraColors.canvas,
      dividerColor: WeekraColors.divider,
      splashFactory: InkRipple.splashFactory,
      useMaterial3: true,
      iconTheme: const IconThemeData(
        color: WeekraColors.textSecondary,
        size: 20,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: WeekraColors.textPrimary,
          fontSize: 23,
          height: 1.12,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.45,
        ),
        titleMedium: TextStyle(
          color: WeekraColors.textPrimary,
          fontSize: 15,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: WeekraColors.textPrimary,
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: WeekraColors.textSecondary,
          fontSize: 12,
          height: 1.3,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(38, 38)),
          maximumSize: const WidgetStatePropertyAll(Size(38, 38)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          shape: const WidgetStatePropertyAll(controlShape),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return WeekraColors.textTertiary;
            }
            return WeekraColors.textSecondary;
          }),
          overlayColor: const WidgetStatePropertyAll(
            WeekraColors.surfacePressed,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: const ButtonStyle(
          minimumSize: WidgetStatePropertyAll(
            Size(0, WeekraMetrics.controlHeight),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12),
          ),
          shape: WidgetStatePropertyAll(controlShape),
          foregroundColor: WidgetStatePropertyAll(
            WeekraColors.textSecondary,
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          backgroundColor: resolvedAccent,
          foregroundColor: WeekraColors.onAccent,
          elevation: 0,
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 42),
          foregroundColor: WeekraColors.textPrimary,
          side: const BorderSide(color: WeekraColors.outline),
          shape: controlShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: resolvedAccent,
        foregroundColor: WeekraColors.onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WeekraColors.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(WeekraMetrics.controlRadius),
          ),
          borderSide: BorderSide(color: WeekraColors.outline),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(WeekraMetrics.controlRadius),
          ),
          borderSide: BorderSide(color: WeekraColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(WeekraMetrics.controlRadius),
          ),
          borderSide: BorderSide(color: resolvedAccent, width: 1.5),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: WeekraColors.surface,
        modalBackgroundColor: WeekraColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: WeekraColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
