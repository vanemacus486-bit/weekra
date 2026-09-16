import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:weekra/app/weekra_design.dart';

/// Frosted material with a directional rim. Works on Windows' Skia renderer.
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 22,
    this.thumb = false,
    this.responsive = true,
  });

  final Widget child;
  final double radius;
  final bool thumb;
  final bool responsive;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface> {
  static const _restingLight = Alignment(-.72, -.92);

  Alignment _pointerLight = _restingLight;
  bool _hovered = false;

  void _updateLight(Offset localPosition) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    final next = Alignment(
      (((localPosition.dx / size.width) * 2 - 1).clamp(-1.0, 1.0) * .82)
          .toDouble(),
      (((localPosition.dy / size.height) * 2 - 1).clamp(-1.0, 1.0) * .82)
          .toDouble(),
    );
    if ((next.x - _pointerLight.x).abs() < .025 &&
        (next.y - _pointerLight.y).abs() < .025) {
      return;
    }
    setState(() => _pointerLight = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = switch (theme.platform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => false,
    };
    if (!desktop) {
      return _StaticGlassSurface(
        radius: widget.radius,
        thumb: widget.thumb,
        child: widget.child,
      );
    }

    final shape = BorderRadius.circular(widget.radius);
    final duration = WeekraMotion.resolve(context, WeekraMotion.control);
    final accent = theme.colorScheme.primary;
    final pointerResponsive = widget.responsive && desktop;
    final targetLight = pointerResponsive && _hovered
        ? _pointerLight
        : _restingLight;
    return MouseRegion(
      onEnter: pointerResponsive
          ? (event) {
              _updateLight(event.localPosition);
              setState(() => _hovered = true);
            }
          : null,
      onHover: pointerResponsive
          ? (event) => _updateLight(event.localPosition)
          : null,
      onExit: pointerResponsive
          ? (_) => setState(() => _hovered = false)
          : null,
      child: AnimatedContainer(
        duration: duration,
        curve: WeekraMotion.standard,
        decoration: BoxDecoration(
          borderRadius: shape,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: widget.thumb ? .25 : (_hovered ? .38 : .32),
              ),
              blurRadius: widget.thumb ? 9 : (_hovered ? 36 : 30),
              spreadRadius: widget.thumb ? -.5 : -2,
              offset: Offset(0, widget.thumb ? 3 : (_hovered ? 14 : 11)),
            ),
            if (!widget.thumb)
              BoxShadow(
                color: accent.withValues(alpha: _hovered ? .045 : .025),
                blurRadius: _hovered ? 22 : 16,
                spreadRadius: -7,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: shape,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: widget.thumb ? 18 : 24,
              sigmaY: widget.thumb ? 18 : 24,
            ),
            child: TweenAnimationBuilder<Alignment>(
              tween: Tween<Alignment>(end: targetLight),
              duration: duration,
              curve: WeekraMotion.standard,
              builder: (context, light, _) => Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      key: const Key('glass-base-layer'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: const Alignment(-1, -1),
                          end: const Alignment(1, 1),
                          colors: widget.thumb
                              ? const [Color(0xA66C727C), Color(0x78404750)]
                              : const [Color(0xB832363D), Color(0xC21A1D22)],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(
                              alpha: widget.thumb ? .085 : .055,
                            ),
                            Colors.transparent,
                            accent.withValues(
                              alpha: widget.thumb ? .035 : .022,
                            ),
                          ],
                          stops: const [0, .46, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      key: const Key('glass-specular-layer'),
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: light,
                          radius: widget.thumb ? .92 : 1.08,
                          colors: [
                            Colors.white.withValues(
                              alpha: widget.thumb
                                  ? .20
                                  : (_hovered ? .145 : .09),
                            ),
                            Colors.white.withValues(
                              alpha: widget.thumb ? .055 : .025,
                            ),
                            Colors.transparent,
                          ],
                          stops: const [0, .34, 1],
                        ),
                      ),
                    ),
                  ),
                  CustomPaint(
                    foregroundPainter: _GlassRim(
                      radius: widget.radius,
                      thumb: widget.thumb,
                      light: light,
                      hovered: _hovered,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stable, low-cost profile for touch platforms without pointer lighting.
class _StaticGlassSurface extends StatelessWidget {
  const _StaticGlassSurface({
    required this.child,
    required this.radius,
    required this.thumb,
  });

  final Widget child;
  final double radius;
  final bool thumb;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: thumb ? .24 : .32),
            blurRadius: thumb ? 8 : 32,
            offset: Offset(0, thumb ? 3 : 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: thumb
                    ? const [Color(0x806F747C), Color(0x40424750)]
                    : const [Color(0xD032353B), Color(0xD9202228)],
              ),
            ),
            child: CustomPaint(
              foregroundPainter: _StaticGlassRim(radius: radius, thumb: thumb),
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticGlassRim extends CustomPainter {
  const _StaticGlassRim({required this.radius, required this.thumb});

  final double radius;
  final bool thumb;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(.6);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: thumb ? .64 : .30),
          Colors.white.withValues(alpha: .06),
          Colors.white.withValues(alpha: thumb ? .23 : .13),
        ],
        stops: const [0, .55, 1],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_StaticGlassRim oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.thumb != thumb;
}

class _GlassRim extends CustomPainter {
  const _GlassRim({
    required this.radius,
    required this.thumb,
    required this.light,
    required this.hovered,
  });
  final double radius;
  final bool thumb;
  final Alignment light;
  final bool hovered;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(.6);
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: light,
        end: Alignment(-light.x, -light.y),
        colors: [
          Colors.white.withValues(alpha: thumb ? .72 : (hovered ? .42 : .32)),
          Colors.white.withValues(alpha: thumb ? .10 : .055),
          Colors.white.withValues(alpha: thumb ? .28 : .14),
        ],
        stops: const [0, .48, 1],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      outerPaint,
    );

    final innerRect = rect.deflate(1.15);
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: thumb ? .18 : .105),
          Colors.white.withValues(alpha: .012),
          Colors.black.withValues(alpha: thumb ? .08 : .12),
        ],
      ).createShader(innerRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        innerRect,
        Radius.circular((radius - 1.15).clamp(0, radius).toDouble()),
      ),
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(_GlassRim oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.thumb != thumb ||
      oldDelegate.light != light ||
      oldDelegate.hovered != hovered;
}

/// One persistent thumb: taps retarget the running spring; drags track the hand.
class GlassSegmentedControl extends StatefulWidget {
  const GlassSegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.children,
    required this.width,
  });
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final List<Widget> children;
  final double width;
  @override
  State<GlassSegmentedControl> createState() => _GlassSegmentedControlState();
}

class _GlassSegmentedControlState extends State<GlassSegmentedControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: widget.selectedIndex.toDouble(),
  );
  bool _dragging = false;

  void _settle(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _position.value = index.toDouble();
      return;
    }
    final velocity = _position.velocity;
    _position.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 500, damping: 44),
        _position.value,
        index.toDouble(),
        velocity,
      ),
    );
  }

  @override
  void didUpdateWidget(GlassSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.selectedIndex != widget.selectedIndex) {
      _settle(widget.selectedIndex);
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const inset = 3.0;
    final itemWidth = (widget.width - inset * 2) / widget.children.length;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return GlassSurface(
      radius: 22,
      child: SizedBox(
        width: widget.width,
        height: 42,
        child: GestureDetector(
          onHorizontalDragStart: (_) {
            _dragging = true;
            _position.stop();
          },
          onHorizontalDragUpdate: (details) {
            _position.value =
                (_position.value +
                        details.delta.dx * (rtl ? -1 : 1) / itemWidth)
                    .clamp(0, widget.children.length - 1)
                    .toDouble();
          },
          onHorizontalDragEnd: (_) {
            _dragging = false;
            final index = _position.value.round();
            widget.onChanged(index);
            _settle(index);
          },
          onHorizontalDragCancel: () {
            _dragging = false;
            _settle(widget.selectedIndex);
          },
          child: AnimatedBuilder(
            animation: _position,
            builder: (context, _) => Stack(
              children: [
                PositionedDirectional(
                  key: const Key('glass-layout-thumb'),
                  start: inset + _position.value * itemWidth,
                  top: inset,
                  bottom: inset,
                  width: itemWidth,
                  child: const GlassSurface(
                    thumb: true,
                    responsive: false,
                    radius: 19,
                    child: SizedBox.expand(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(inset),
                  child: Row(
                    children: [
                      for (final child in widget.children)
                        Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showGlassDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxWidth = 480,
  double maxHeight = 640,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: const Color(0x40000000),
  transitionDuration: WeekraMotion.resolve(context, WeekraMotion.panel),
  pageBuilder: (context, _, _) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
          child: GlassSurface(child: builder(context)),
        ),
      ),
    ),
  ),
  transitionBuilder: (context, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  ),
);
