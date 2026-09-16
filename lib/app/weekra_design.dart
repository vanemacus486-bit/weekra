import 'package:flutter/material.dart';

/// Shared visual language for Weekra's calm, dark calendar surfaces.
abstract final class WeekraColors {
  static const canvas = Color(0xFF101113);
  static const surface = Color(0xFF181A1D);
  static const surfaceRaised = Color(0xFF202327);
  static const surfacePressed = Color(0xFF292C30);

  static const textPrimary = Color(0xFFF2EFE9);
  static const textSecondary = Color(0xFFA9A49D);
  static const textTertiary = Color(0xFF817C76);

  static const coral = Color(0xFFF1776C);
  static const onAccent = Color(0xFF241311);
  static const divider = Color(0x14FFFFFF);
  static const dividerSubtle = Color(0x0AFFFFFF);
  static const outline = Color(0x26FFFFFF);
}

abstract final class WeekraMetrics {
  static const controlHeight = 38.0;
  static const controlRadius = 10.0;
  static const eventRadius = 9.0;
  static const pageGutter = 28.0;
}

/// Motion and material values used by the calendar interaction surfaces.
///
/// Keeping these values together makes the transitions feel related and gives
/// reduced-motion users a single, reliable escape hatch.
abstract final class WeekraMotion {
  static const quick = Duration(milliseconds: 120);
  static const control = Duration(milliseconds: 180);
  static const content = Duration(milliseconds: 220);
  static const panel = Duration(milliseconds: 190);

  static const standard = Cubic(0.2, 0.72, 0.2, 1);
  static const emphasized = Cubic(0.16, 0.86, 0.24, 1);

  static Duration resolve(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}

/// Adds the small, physical response shared by Weekra's clickable controls.
///
/// The control itself remains responsible for hover and focus colors. Keeping
/// the scale in a wrapper means icon, text, and custom controls all compress in
/// the same way without changing their hit targets.
class WeekraPressableScale extends StatefulWidget {
  const WeekraPressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = .94,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<WeekraPressableScale> createState() => _WeekraPressableScaleState();
}

class _WeekraPressableScaleState extends State<WeekraPressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  void didUpdateWidget(WeekraPressableScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onExit: (_) => _setPressed(false),
      child: Listener(
        onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
        onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
        onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1,
          duration: WeekraMotion.resolve(context, WeekraMotion.quick),
          curve: WeekraMotion.standard,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Icon button with Weekra's shared hover color and press response.
class WeekraIconButton extends StatelessWidget {
  const WeekraIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return WeekraPressableScale(
      enabled: onPressed != null,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        color: color,
        icon: icon,
      ),
    );
  }
}

abstract final class WeekraMaterial {
  static const glass = Color(0xD91D1F22);
  static const glassStrong = Color(0xF2232529);
  static const glassBorder = Color(0x24FFFFFF);
  static const shadow = Color(0x66000000);
  static const blurSigma = 14.0;
  static const floatingRadius = 16.0;
}

abstract final class WeekraEventStyle {
  static LinearGradient gradient(Color color, {bool emphasized = false}) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(
            color.withValues(alpha: emphasized ? .48 : .36),
            WeekraColors.surfaceRaised,
          ),
          Color.alphaBlend(
            color.withValues(alpha: emphasized ? .30 : .20),
            WeekraColors.surface,
          ),
        ],
      );

  static Color surface(Color categoryColor, {bool emphasized = false}) {
    return Color.alphaBlend(
      categoryColor.withValues(alpha: emphasized ? 0.38 : 0.28),
      WeekraColors.surfaceRaised,
    );
  }

  static Color subtleSurface(Color categoryColor) {
    return Color.alphaBlend(
      categoryColor.withValues(alpha: 0.18),
      WeekraColors.surfaceRaised,
    );
  }
}

abstract final class WeekraDesign {
  static ThemeData dark({String? fontFamily, Color? accent}) {
    final resolvedAccent = accent ?? WeekraColors.coral;
    final colorScheme =
        ColorScheme.fromSeed(
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
      splashFactory: NoSplash.splashFactory,
      hoverColor: WeekraColors.surfaceRaised,
      highlightColor: WeekraColors.surfacePressed,
      splashColor: Colors.transparent,
      focusColor: WeekraColors.surfaceRaised,
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
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.focused)) {
              return WeekraColors.textPrimary;
            }
            return WeekraColors.textSecondary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.transparent;
            }
            if (states.contains(WidgetState.pressed)) {
              return WeekraColors.surfacePressed;
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return WeekraColors.surfaceRaised;
            }
            return Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          animationDuration: WeekraMotion.quick,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(0, WeekraMetrics.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12),
          ),
          shape: const WidgetStatePropertyAll(controlShape),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return WeekraColors.textTertiary;
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.focused)) {
              return WeekraColors.textPrimary;
            }
            return WeekraColors.textSecondary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return WeekraColors.surfacePressed;
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return WeekraColors.surfaceRaised;
            }
            return Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          animationDuration: WeekraMotion.quick,
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return WeekraColors.surfacePressed;
            }
            if (states.contains(WidgetState.pressed)) {
              return Color.alphaBlend(
                Colors.black.withValues(alpha: .14),
                resolvedAccent,
              );
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return Color.alphaBlend(
                Colors.white.withValues(alpha: .10),
                resolvedAccent,
              );
            }
            return resolvedAccent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return WeekraColors.textTertiary;
            }
            return WeekraColors.onAccent;
          }),
          elevation: const WidgetStatePropertyAll(0),
          shape: const WidgetStatePropertyAll(controlShape),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          animationDuration: WeekraMotion.quick,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 42)),
          foregroundColor: const WidgetStatePropertyAll(
            WeekraColors.textPrimary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return WeekraColors.surfacePressed;
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return WeekraColors.surfaceRaised;
            }
            return Colors.transparent;
          }),
          side: const WidgetStatePropertyAll(
            BorderSide(color: WeekraColors.outline),
          ),
          shape: const WidgetStatePropertyAll(controlShape),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          animationDuration: WeekraMotion.quick,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
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
