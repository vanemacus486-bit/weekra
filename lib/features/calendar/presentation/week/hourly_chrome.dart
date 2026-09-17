part of '../week_screen.dart';

class _FlowingDateSwitcher extends StatefulWidget {
  const _FlowingDateSwitcher({
    required this.child,
    required this.direction,
    required this.travelDistance,
  });

  final Widget child;
  final int direction;
  final double travelDistance;

  @override
  State<_FlowingDateSwitcher> createState() => _FlowingDateSwitcherState();
}

class _FlowingDateSwitcherState extends State<_FlowingDateSwitcher>
    with SingleTickerProviderStateMixin {
  static const _flowCurve = Cubic(.2, .8, .2, 1);

  late final AnimationController _controller;
  late Widget _currentChild;
  Widget? _outgoingChild;
  double _incomingBeginOffset = 0;
  double _outgoingBeginOffset = 0;
  double _outgoingEndOffset = 0;
  int _transitionDirection = 1;

  @override
  void initState() {
    super.initState();
    _currentChild = widget.child;
    _controller = AnimationController(vsync: this, value: 1)
      ..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant _FlowingDateSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child.key == widget.child.key) {
      _currentChild = widget.child;
      return;
    }

    // A new input must never inherit a partially composed pair of canvases.
    // Settle on the most recent target first, then begin one clean column move.
    // This keeps clicks responsive without carrying a third stale layer forward.
    if (_controller.isAnimating) {
      _controller.stop();
      _outgoingChild = null;
      _incomingBeginOffset = 0;
      _outgoingBeginOffset = 0;
      _outgoingEndOffset = 0;
    }

    final direction = widget.direction == 0 ? 1 : widget.direction.sign;
    final distance = widget.travelDistance.abs();

    _transitionDirection = direction;
    _outgoingChild = _currentChild;
    _outgoingBeginOffset = 0;
    _outgoingEndOffset = -direction * distance;
    _incomingBeginOffset = direction * distance;
    _currentChild = widget.child;

    final duration = WeekraMotion.resolve(
      context,
      const Duration(milliseconds: 290),
    );
    if (duration == Duration.zero || distance == 0) {
      _controller.stop();
      _controller.value = 1;
      _outgoingChild = null;
      _incomingBeginOffset = 0;
      return;
    }

    _controller.duration = duration;
    _controller.forward(from: 0);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed ||
        _outgoingChild == null ||
        !mounted) {
      return;
    }
    setState(() {
      _outgoingChild = null;
      _incomingBeginOffset = 0;
    });
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outgoingChild = _outgoingChild;
    if (outgoingChild == null) {
      return _FlowingDateLayer(
        key: _layerKey(_currentChild),
        horizontalOffset: 0,
        clip: _FlowingDateClip.full,
        clipExtent: 0,
        interactive: true,
        child: _currentChild,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _flowCurve.transform(_controller.value);
        final outgoingOffset =
            _outgoingBeginOffset +
            (_outgoingEndOffset - _outgoingBeginOffset) * progress;
        final incomingOffset = _incomingBeginOffset * (1 - progress);
        // Adjacent timeline windows share six of their seven dates. Drawing
        // both complete canvases during the slide briefly duplicates every
        // shared event: the outgoing copy has already moved one column while
        // the incoming copy is still near its old screen position. Keep the
        // outgoing canvas as the single source for shared dates and reveal
        // only the edge that is genuinely entering the viewport.
        final enteringExtent = _incomingBeginOffset.abs() * progress;
        final movesForward = _transitionDirection > 0;
        return Stack(
          fit: StackFit.expand,
          children: [
            _FlowingDateLayer(
              key: _layerKey(outgoingChild),
              horizontalOffset: outgoingOffset,
              clip: _FlowingDateClip.full,
              clipExtent: 0,
              interactive: false,
              child: outgoingChild,
            ),
            _FlowingDateLayer(
              key: _layerKey(_currentChild),
              horizontalOffset: incomingOffset,
              clip: movesForward
                  ? _FlowingDateClip.trailing
                  : _FlowingDateClip.leading,
              clipExtent: enteringExtent,
              interactive: true,
              child: _currentChild,
            ),
          ],
        );
      },
    );
  }

  ValueKey<String> _layerKey(Widget child) =>
      ValueKey('flowing-date-layer-${child.key}');
}

enum _FlowingDateClip { full, leading, trailing }

class _FlowingDateLayer extends StatelessWidget {
  const _FlowingDateLayer({
    super.key,
    required this.child,
    required this.horizontalOffset,
    required this.clip,
    required this.clipExtent,
    required this.interactive,
  });

  final Widget child;
  final double horizontalOffset;
  final _FlowingDateClip clip;
  final double clipExtent;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !interactive,
      child: ExcludeSemantics(
        excluding: !interactive,
        child: ClipRect(
          clipper: _FlowingDateClipper(mode: clip, extent: clipExtent),
          child: Transform.translate(
            offset: Offset(horizontalOffset, 0),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FlowingDateClipper extends CustomClipper<Rect> {
  const _FlowingDateClipper({required this.mode, required this.extent});

  final _FlowingDateClip mode;
  final double extent;

  @override
  Rect getClip(Size size) {
    final clippedExtent = extent.clamp(0.0, size.width).toDouble();
    return switch (mode) {
      _FlowingDateClip.full => Offset.zero & size,
      _FlowingDateClip.leading => Rect.fromLTWH(
        0,
        0,
        clippedExtent,
        size.height,
      ),
      _FlowingDateClip.trailing => Rect.fromLTWH(
        size.width - clippedExtent,
        0,
        clippedExtent,
        size.height,
      ),
    };
  }

  @override
  bool shouldReclip(covariant _FlowingDateClipper oldClipper) =>
      mode != oldClipper.mode || extent != oldClipper.extent;
}

class _GridDayHeader extends StatelessWidget {
  const _GridDayHeader({
    required this.day,
    required this.isToday,
    required this.narrow,
  });

  final DateTime day;
  final bool isToday;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      color: isToday
          ? WeekraColors.textPrimary.withValues(alpha: 0.018)
          : Colors.transparent,
      padding: EdgeInsets.symmetric(vertical: narrow ? 7 : 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _weekdayShortName(l10n, day.weekday),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isToday ? accent : _mutedInk,
              fontSize: narrow ? 9 : 10,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: narrow ? 0.55 : 0.85,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${day.day}',
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: isToday ? accent : _ink,
              fontSize: narrow ? 17 : 20,
              height: 1,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: WeekraMotion.resolve(context, WeekraMotion.quick),
            width: isToday ? (narrow ? 16 : 20) : 0,
            height: 2,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDayBand extends StatelessWidget {
  const _AllDayBand({
    required this.days,
    required this.events,
    required this.today,
    required this.gutterWidth,
    required this.navigationDirection,
    required this.onEventTap,
  });

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final DateTime today;
  final double gutterWidth;
  final int navigationDirection;
  final _OpenEventCallback onEventTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final byDay = List.generate(
      days.length,
      (index) => events
          .where((event) => _eventOccursOnDay(event, days[index]))
          .toList(),
    );
    final maxCount = byDay.fold<int>(
      0,
      (largest, items) => math.max(largest, items.length),
    );
    final height = 10.0 + maxCount * 28 + math.max(0, maxCount - 1) * 3;

    return Container(
      height: height,
      color: WeekraColors.surface.withValues(alpha: 0.46),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: gutterWidth,
            child: Align(
              alignment: AlignmentDirectional.topCenter,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(top: 12, end: 5),
                child: Text(
                  l10n.allDay,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(
                    color: _tertiaryInk,
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) => _FlowingDateSwitcher(
                  direction: navigationDirection,
                  travelDistance: constraints.maxWidth / days.length,
                  child: Row(
                    key: ValueKey('all-day-${_dateKey(days.first)}'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var dayIndex = 0; dayIndex < days.length; dayIndex++)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 5,
                            ),
                            color: _isSameDay(days[dayIndex], today)
                                ? WeekraColors.textPrimary.withValues(
                                    alpha: 0.018,
                                  )
                                : Colors.transparent,
                            child: Column(
                              children: [
                                for (
                                  var index = 0;
                                  index < byDay[dayIndex].length;
                                  index++
                                ) ...[
                                  _AllDayEvent(
                                    event: byDay[dayIndex][index],
                                    onTap: onEventTap,
                                  ),
                                  if (index != byDay[dayIndex].length - 1)
                                    const SizedBox(height: 3),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllDayEvent extends StatelessWidget {
  const _AllDayEvent({required this.event, required this.onTap});

  final CalendarEvent event;
  final _OpenEventCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: event.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(event),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 28,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              gradient: WeekraEventStyle.gradient(event.color),
              border: Border.all(
                color: event.color.withValues(alpha: .20),
                width: .75,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: event.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
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

class _TimelineScale {
  const _TimelineScale({required this.height, this.focusMinute});

  static const totalMinutes = 24 * 60;
  static const focusWindowMinutes = 2 * 60;

  final double height;
  final int? focusMinute;

  bool get hasFocus => focusMinute != null;

  int get focusStartMinute {
    final center = (focusMinute ?? 0).clamp(0, totalMinutes).toInt();
    return (center - focusWindowMinutes ~/ 2)
        .clamp(0, totalMinutes - focusWindowMinutes)
        .toInt();
  }

  int get focusEndMinute => focusStartMinute + focusWindowMinutes;

  double get _focusHeight {
    if (!hasFocus) {
      return 0;
    }
    final preferred = math.max(104.0, height * .30);
    return math.min(math.min(196.0, preferred), height * .55);
  }

  double get _focusPixelsPerMinute => _focusHeight / focusWindowMinutes;

  double get _focusTop {
    if (focusStartMinute == 0) {
      return 0;
    }
    if (focusEndMinute == totalMinutes) {
      return height - _focusHeight;
    }
    final center = focusMinute!.clamp(0, totalMinutes).toDouble();
    return (height * center / totalMinutes - _focusHeight / 2)
        .clamp(0, height - _focusHeight)
        .toDouble();
  }

  double get _beforePixelsPerMinute =>
      focusStartMinute == 0 ? 0 : _focusTop / focusStartMinute;

  double get _afterPixelsPerMinute => focusEndMinute == totalMinutes
      ? 0
      : (height - _focusTop - _focusHeight) / (totalMinutes - focusEndMinute);

  double yForMinute(num minute) {
    final value = minute.clamp(0, totalMinutes).toDouble();
    if (!hasFocus) {
      return value / totalMinutes * height;
    }
    if (value <= focusStartMinute) {
      return value * _beforePixelsPerMinute;
    }
    if (value <= focusEndMinute) {
      return _focusTop + (value - focusStartMinute) * _focusPixelsPerMinute;
    }
    return _focusTop +
        _focusHeight +
        (value - focusEndMinute) * _afterPixelsPerMinute;
  }

  double minuteForY(num y) {
    final value = y.clamp(0, height).toDouble();
    if (!hasFocus) {
      return value / height * totalMinutes;
    }
    final focusBottom = _focusTop + _focusHeight;
    if (value <= _focusTop) {
      return focusStartMinute == 0 ? 0 : value / _beforePixelsPerMinute;
    }
    if (value <= focusBottom) {
      return focusStartMinute + (value - _focusTop) / _focusPixelsPerMinute;
    }
    return focusEndMinute + (value - focusBottom) / _afterPixelsPerMinute;
  }

  double heightForRange(num startMinute, num endMinute) =>
      yForMinute(endMinute) - yForMinute(startMinute);

  bool rangeTouchesFocus(num startMinute, num endMinute) =>
      hasFocus && endMinute > focusStartMinute && startMinute < focusEndMinute;
}

class _TimelineFocusBand extends StatelessWidget {
  const _TimelineFocusBand({required this.scale, required this.gutterWidth});

  final _TimelineScale scale;
  final double gutterWidth;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final top = scale.yForMinute(scale.focusStartMinute);
    final height = scale.heightForRange(
      scale.focusStartMinute,
      scale.focusEndMinute,
    );
    return AnimatedPositionedDirectional(
      key: const Key('timeline-focus-lens'),
      duration: WeekraMotion.resolve(context, WeekraMotion.control),
      curve: WeekraMotion.emphasized,
      start: gutterWidth,
      end: 0,
      top: top,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .055),
            border: Border.symmetric(
              horizontal: BorderSide(
                color: accent.withValues(alpha: .28),
                width: .75,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HourRule extends StatelessWidget {
  const _HourRule({
    required this.top,
    required this.gutterWidth,
    required this.label,
    this.isDayEnd = false,
  });

  final double top;
  final double gutterWidth;
  final String label;
  final bool isDayEnd;

  @override
  Widget build(BuildContext context) {
    if (isDayEnd) {
      return AnimatedPositionedDirectional(
        key: const Key('timeline-day-end'),
        start: 0,
        end: 0,
        bottom: 0,
        height: 14,
        duration: WeekraMotion.resolve(context, WeekraMotion.control),
        curve: WeekraMotion.emphasized,
        child: Stack(
          children: [
            PositionedDirectional(
              start: 0,
              bottom: 2,
              width: gutterWidth,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 9),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: _tertiaryInk,
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              start: gutterWidth,
              end: 0,
              bottom: 0,
              child: const Divider(height: 1, color: _subtleLine),
            ),
          ],
        ),
      );
    }
    return AnimatedPositionedDirectional(
      top: top,
      start: 0,
      end: 0,
      duration: WeekraMotion.resolve(context, WeekraMotion.control),
      curve: WeekraMotion.emphasized,
      child: Row(
        children: [
          SizedBox(
            width: gutterWidth,
            child: Transform.translate(
              offset: Offset(0, top == 0 ? 2 : -6),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 9),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: _tertiaryInk,
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(height: 1, color: _subtleLine)),
        ],
      ),
    );
  }
}

class _MinuteRule extends StatelessWidget {
  const _MinuteRule({required this.top, required this.gutterWidth, this.label});

  final double top;
  final double gutterWidth;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return AnimatedPositionedDirectional(
      top: top,
      start: 0,
      end: 0,
      duration: WeekraMotion.resolve(context, WeekraMotion.control),
      curve: WeekraMotion.emphasized,
      child: Row(
        children: [
          SizedBox(
            width: gutterWidth,
            child: label == null
                ? null
                : Transform.translate(
                    offset: const Offset(0, -5),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 9),
                      child: Text(
                        label!,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary
                              .withValues(alpha: .72),
                          fontSize: 8,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              thickness: .5,
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: .13),
            ),
          ),
        ],
      ),
    );
  }
}
