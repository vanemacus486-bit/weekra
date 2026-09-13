import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:weekra/app/weekra_design.dart';

/// Frosted material with a directional rim. Works on Windows' Skia renderer.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 22,
    this.thumb = false,
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
                    ? [const Color(0x806F747C), const Color(0x40424750)]
                    : [const Color(0xD032353B), const Color(0xD9202228)],
              ),
            ),
            child: CustomPaint(
              foregroundPainter: _GlassRim(radius: radius, thumb: thumb),
              child: Material(type: MaterialType.transparency, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassRim extends CustomPainter {
  const _GlassRim({required this.radius, required this.thumb});
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
  bool shouldRepaint(_GlassRim oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.thumb != thumb;
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
