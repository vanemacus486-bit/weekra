part of '../week_screen.dart';

class _GridEvent extends StatefulWidget {
  const _GridEvent({
    super.key,
    required this.eventKey,
    required this.event,
    required this.dayIndex,
    required this.lane,
    required this.laneCount,
    required this.columnWidth,
    required this.gutterWidth,
    required this.scale,
    required this.narrow,
    required this.isSelected,
    required this.isManipulating,
    required this.isResizing,
    required this.allowResize,
    required this.desktopPointers,
    required this.onFocus,
    required this.onTap,
    required this.onSecondaryTap,
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
    required this.onMoveCancel,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onResizeCancel,
  });

  final Key eventKey;
  final CalendarEvent event;
  final int dayIndex;
  final int lane;
  final int laneCount;
  final double columnWidth;
  final double gutterWidth;
  final _TimelineScale scale;
  final bool narrow;
  final bool isSelected;
  final bool isManipulating;
  final bool isResizing;
  final bool allowResize;
  final bool desktopPointers;
  final VoidCallback onFocus;
  final ValueChanged<Rect> onTap;
  final void Function(Rect anchorRect, Offset position) onSecondaryTap;
  final VoidCallback onMoveStart;
  final ValueChanged<Offset> onMoveUpdate;
  final VoidCallback onMoveEnd;
  final VoidCallback onMoveCancel;
  final ValueChanged<_ResizeEdge> onResizeStart;
  final GestureDragUpdateCallback onResizeUpdate;
  final GestureDragEndCallback onResizeEnd;
  final GestureDragCancelCallback onResizeCancel;

  @override
  State<_GridEvent> createState() => _GridEventState();
}

class _GridEventState extends State<_GridEvent> {
  _ResizeEdge? _hoveredResizeEdge;
  _ResizeEdge? _activeResizeEdge;

  Key get eventKey => widget.eventKey;
  CalendarEvent get event => widget.event;
  int get dayIndex => widget.dayIndex;
  int get lane => widget.lane;
  int get laneCount => widget.laneCount;
  double get columnWidth => widget.columnWidth;
  double get gutterWidth => widget.gutterWidth;
  _TimelineScale get scale => widget.scale;
  bool get narrow => widget.narrow;
  bool get isSelected => widget.isSelected;
  bool get isManipulating => widget.isManipulating;
  bool get isResizing => widget.isResizing;
  bool get allowResize => widget.allowResize;
  bool get desktopPointers => widget.desktopPointers;
  VoidCallback get onFocus => widget.onFocus;
  ValueChanged<Rect> get onTap => widget.onTap;
  void Function(Rect, Offset) get onSecondaryTap => widget.onSecondaryTap;
  VoidCallback get onMoveStart => widget.onMoveStart;
  ValueChanged<Offset> get onMoveUpdate => widget.onMoveUpdate;
  VoidCallback get onMoveEnd => widget.onMoveEnd;
  VoidCallback get onMoveCancel => widget.onMoveCancel;
  ValueChanged<_ResizeEdge> get onResizeStart => widget.onResizeStart;
  GestureDragUpdateCallback get onResizeUpdate => widget.onResizeUpdate;
  GestureDragEndCallback get onResizeEnd => widget.onResizeEnd;
  GestureDragCancelCallback get onResizeCancel => widget.onResizeCancel;

  _ResizeEdge? _edgeAt(
    Offset position, {
    required double bodyOffset,
    required double bodyHeight,
  }) {
    if (!allowResize) {
      return null;
    }
    final bodyEnd = bodyOffset + bodyHeight;
    if (position.dy < bodyOffset - 4 || position.dy > bodyEnd + 4) {
      return null;
    }
    if (bodyHeight <= 18) {
      return position.dy <= bodyOffset + bodyHeight / 2
          ? _ResizeEdge.start
          : _ResizeEdge.end;
    }
    if (position.dy <= bodyOffset + 8) {
      return _ResizeEdge.start;
    }
    if (position.dy >= bodyEnd - 8) {
      return _ResizeEdge.end;
    }
    return null;
  }

  void _setHoveredEdge(_ResizeEdge? edge) {
    if (_hoveredResizeEdge == edge || _activeResizeEdge != null) {
      return;
    }
    setState(() => _hoveredResizeEdge = edge);
  }

  @override
  Widget build(BuildContext context) {
    final visibleStart = math.max(event.startMinutes, 0);
    final visibleEnd = math.min(_eventEndMinuteForLayout(event), 24 * 60);
    final top = scale.yForMinute(visibleStart);
    final rawHeight = scale.heightForRange(visibleStart, visibleEnd);
    final bodyHeight = math.max(
      scale.rangeTouchesFocus(visibleStart, visibleEnd) ? 14.0 : 5.0,
      rawHeight - 2,
    );
    final hitPadding = math.max(0.0, (24.0 - bodyHeight) / 2);
    final desiredBodyTop = top + 1;
    final positionedTop = math.max(0.0, desiredBodyTop - hitPadding);
    final bodyOffset = desiredBodyTop - positionedTop;
    final trailingPadding = hitPadding;
    final outerHeight = math.max(
      24.0,
      bodyOffset + bodyHeight + trailingPadding,
    );
    final outerInset = narrow ? 2.0 : 5.0;
    final laneGap = laneCount >= 4 ? 1.0 : 2.0;
    final usableWidth = columnWidth - outerInset * 2;
    final laneWidth = math.max(
      1.0,
      (usableWidth - laneGap * (laneCount - 1)) / laneCount,
    );
    final start =
        gutterWidth +
        dayIndex * columnWidth +
        outerInset +
        lane * (laneWidth + laneGap);
    final startLabel = _formatTime(context, event.startMinutes);
    final timeRange = '$startLabel – ${_formatTime(context, event.endMinutes)}';
    final isShort = bodyHeight < 48;
    final isTiny = laneWidth < 22 || bodyHeight < 15;
    final verticalPadding = bodyHeight < 24
        ? 1.0
        : isShort
        ? 3.0
        : 6.0;
    return AnimatedPositionedDirectional(
      start: start,
      top: positionedTop,
      width: laneWidth,
      height: outerHeight,
      duration: isManipulating || isResizing
          ? Duration.zero
          : WeekraMotion.resolve(context, WeekraMotion.control),
      curve: WeekraMotion.emphasized,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            start: 0,
            end: 0,
            top: 0,
            bottom: 0,
            child: Semantics(
              button: true,
              selected: isSelected,
              label: '${event.title}, $timeRange',
              hint: AppLocalizations.of(context).moveEventHint,
              child: AnimatedScale(
                scale: isManipulating ? 1.015 : 1,
                duration: WeekraMotion.resolve(context, WeekraMotion.quick),
                curve: WeekraMotion.standard,
                child: Builder(
                  builder: (eventContext) => MouseRegion(
                    cursor: !desktopPointers
                        ? MouseCursor.defer
                        : _hoveredResizeEdge == null
                        ? SystemMouseCursors.move
                        : SystemMouseCursors.resizeUpDown,
                    onHover: desktopPointers
                        ? (event) => _setHoveredEdge(
                            _edgeAt(
                              event.localPosition,
                              bodyOffset: bodyOffset,
                              bodyHeight: bodyHeight,
                            ),
                          )
                        : null,
                    onExit: desktopPointers
                        ? (_) => _setHoveredEdge(null)
                        : null,
                    child: GestureDetector(
                      key: eventKey,
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onTapDown: (_) => onFocus(),
                      onSecondaryTapDown: desktopPointers
                          ? (_) => onFocus()
                          : null,
                      onTapUp: (details) => onTap(
                        _globalRectFor(eventContext) ??
                            Rect.fromCenter(
                              center: details.globalPosition,
                              width: 1,
                              height: 1,
                            ),
                      ),
                      onSecondaryTapUp: desktopPointers
                          ? (details) => onSecondaryTap(
                              _globalRectFor(eventContext) ??
                                  Rect.fromCenter(
                                    center: details.globalPosition,
                                    width: 1,
                                    height: 1,
                                  ),
                              details.globalPosition,
                            )
                          : null,
                      onPanStart: desktopPointers
                          ? (details) {
                              final edge = _edgeAt(
                                details.localPosition,
                                bodyOffset: bodyOffset,
                                bodyHeight: bodyHeight,
                              );
                              setState(() {
                                _activeResizeEdge = edge;
                                _hoveredResizeEdge = edge;
                              });
                              if (edge == null) {
                                onMoveStart();
                              } else {
                                onResizeStart(edge);
                              }
                            }
                          : null,
                      onPanUpdate: desktopPointers
                          ? (details) {
                              if (_activeResizeEdge == null) {
                                onMoveUpdate(details.globalPosition);
                              } else {
                                onResizeUpdate(details);
                              }
                            }
                          : null,
                      onPanEnd: desktopPointers
                          ? (details) {
                              final edge = _activeResizeEdge;
                              setState(() {
                                _activeResizeEdge = null;
                                _hoveredResizeEdge = null;
                              });
                              if (edge == null) {
                                onMoveEnd();
                              } else {
                                onResizeEnd(details);
                              }
                            }
                          : null,
                      onPanCancel: desktopPointers
                          ? () {
                              final edge = _activeResizeEdge;
                              setState(() {
                                _activeResizeEdge = null;
                                _hoveredResizeEdge = null;
                              });
                              if (edge == null) {
                                onMoveCancel();
                              } else {
                                onResizeCancel();
                              }
                            }
                          : null,
                      onLongPressStart: desktopPointers
                          ? null
                          : (_) => onMoveStart(),
                      onLongPressMoveUpdate: desktopPointers
                          ? null
                          : (details) => onMoveUpdate(details.globalPosition),
                      onLongPressEnd: desktopPointers
                          ? null
                          : (_) => onMoveEnd(),
                      onLongPressCancel: desktopPointers ? null : onMoveCancel,
                      child: AnimatedPadding(
                        padding: EdgeInsets.only(
                          top: bodyOffset,
                          bottom: math.max(
                            0,
                            outerHeight - bodyOffset - bodyHeight,
                          ),
                        ),
                        duration: isManipulating || isResizing
                            ? Duration.zero
                            : WeekraMotion.resolve(
                                context,
                                WeekraMotion.control,
                              ),
                        curve: WeekraMotion.emphasized,
                        child: AnimatedContainer(
                          key: Key(
                            'hourly-event-surface-${event.id}-$dayIndex',
                          ),
                          duration: WeekraMotion.resolve(
                            context,
                            WeekraMotion.quick,
                          ),
                          curve: WeekraMotion.standard,
                          padding: EdgeInsetsDirectional.fromSTEB(
                            isTiny
                                ? 1
                                : narrow
                                ? 5
                                : 7,
                            verticalPadding,
                            isTiny
                                ? 1
                                : narrow
                                ? 4
                                : 6,
                            verticalPadding,
                          ),
                          decoration: BoxDecoration(
                            gradient: WeekraEventStyle.gradient(
                              event.color,
                              emphasized:
                                  isSelected || isManipulating || isResizing,
                            ),
                            border: Border.all(
                              color: event.color.withValues(
                                alpha: isSelected ? .68 : .24,
                              ),
                              width: .75,
                            ),
                            borderRadius: BorderRadius.circular(
                              WeekraMetrics.eventRadius,
                            ),
                            boxShadow: isSelected
                                ? const [
                                    BoxShadow(
                                      color: Color(0x3D000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ]
                                : const [
                                    BoxShadow(
                                      color: Color(0x24000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: _GridEventContents(
                            event: event,
                            startLabel: startLabel,
                            timeRange: timeRange,
                            laneWidth: laneWidth,
                            narrow: narrow,
                            manipulating: isManipulating || isResizing,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_hoveredResizeEdge case final edge?)
            PositionedDirectional(
              key: Key('event-resize-edge-${event.id}'),
              start: 5,
              end: 5,
              top: edge == _ResizeEdge.start ? bodyOffset : null,
              bottom: edge == _ResizeEdge.end
                  ? math.max(0, outerHeight - bodyOffset - bodyHeight)
                  : null,
              height: 2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: event.color.withValues(alpha: .82),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: event.color.withValues(alpha: .38),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridEventContents extends StatelessWidget {
  const _GridEventContents({
    required this.event,
    required this.startLabel,
    required this.timeRange,
    required this.laneWidth,
    required this.narrow,
    required this.manipulating,
  });

  final CalendarEvent event;
  final String startLabel;
  final String timeRange;
  final double laneWidth;
  final bool narrow;
  final bool manipulating;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final cramped = laneWidth < 70;
        if (laneWidth < 22 || height < 11) {
          return const SizedBox.shrink();
        }
        if (manipulating) {
          return Text(
            timeRange,
            maxLines: height >= 22 ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _ink,
              fontSize: narrow ? 8.5 : 10,
              height: 1.1,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
        }
        if (height < 31) {
          return Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink,
                    fontSize: narrow ? 9.5 : 11.5,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (laneWidth >= 96) ...[
                const SizedBox(width: 5),
                Text(
                  startLabel,
                  maxLines: 1,
                  style: const TextStyle(
                    color: _mutedInk,
                    fontSize: 9,
                    height: 1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              maxLines: !cramped && height >= 48 ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _ink,
                fontSize: narrow ? 10.5 : 12.5,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!cramped) ...[
              const SizedBox(height: 3),
              Text(
                timeRange,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  color: _mutedInk,
                  fontSize: narrow ? 8.5 : 10,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            if (event.location != null && height >= 64) ...[
              const SizedBox(height: 5),
              Text(
                event.location!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _tertiaryInk,
                  fontSize: narrow ? 8.5 : 10,
                  height: 1.1,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _GridDraftEvent extends StatelessWidget {
  const _GridDraftEvent({
    required this.event,
    required this.anchorKey,
    required this.dayIndex,
    required this.columnWidth,
    required this.gutterWidth,
    required this.scale,
    required this.compact,
    required this.manipulating,
    required this.discarding,
    required this.onTap,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onResizeCancel,
  });

  final CalendarEvent event;
  final GlobalKey anchorKey;
  final int dayIndex;
  final double columnWidth;
  final double gutterWidth;
  final _TimelineScale scale;
  final bool compact;
  final bool manipulating;
  final bool discarding;
  final VoidCallback onTap;
  final ValueChanged<_ResizeEdge> onResizeStart;
  final GestureDragUpdateCallback onResizeUpdate;
  final GestureDragEndCallback onResizeEnd;
  final GestureDragCancelCallback onResizeCancel;

  @override
  Widget build(BuildContext context) {
    final top = scale.yForMinute(event.startMinutes);
    final bodyHeight =
        math.max(
          compact ? 20.0 : 24.0,
          scale.heightForRange(
            event.startMinutes,
            _eventEndMinuteForLayout(event),
          ),
        ) -
        2;
    const handlePadding = 12.0;
    final desiredBodyTop = top + 2;
    final positionedTop = math.max(0.0, desiredBodyTop - handlePadding);
    final bodyOffset = desiredBodyTop - positionedTop;
    return AnimatedPositionedDirectional(
      start: gutterWidth + dayIndex * columnWidth + (compact ? 2 : 4),
      top: positionedTop,
      width: columnWidth - (compact ? 4 : 8),
      height: bodyOffset + bodyHeight + handlePadding,
      duration: manipulating
          ? Duration.zero
          : WeekraMotion.resolve(context, WeekraMotion.control),
      curve: WeekraMotion.emphasized,
      child: AnimatedOpacity(
        opacity: discarding ? 0 : 1,
        duration: WeekraMotion.resolve(context, WeekraMotion.quick),
        curve: WeekraMotion.standard,
        child: AnimatedScale(
          scale: discarding ? 0.97 : 1,
          duration: WeekraMotion.resolve(context, WeekraMotion.quick),
          curve: WeekraMotion.standard,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositionedDirectional(
                start: 0,
                end: 0,
                top: bodyOffset,
                height: bodyHeight,
                duration: manipulating
                    ? Duration.zero
                    : WeekraMotion.resolve(context, WeekraMotion.control),
                curve: WeekraMotion.emphasized,
                child: Semantics(
                  button: true,
                  label: AppLocalizations.of(context).confirmNewEventTime,
                  child: GestureDetector(
                    key: const Key('draft-event'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: Container(
                      key: anchorKey,
                      padding: EdgeInsetsDirectional.fromSTEB(
                        compact ? 4 : 7,
                        compact ? 3 : 5,
                        compact ? 3 : 6,
                        compact ? 3 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: 0.24),
                        border: Border.all(color: _ink, width: 1.5),
                        borderRadius: BorderRadius.circular(compact ? 5 : 7),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        '${_formatTime(context, event.startMinutes)} – '
                        '${_formatTime(context, event.endMinutes)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ink,
                          fontSize: compact ? 8 : 11,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _GridResizeHandle(
                key: const Key('draft-resize-start'),
                edge: _ResizeEdge.start,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: AppLocalizations.of(context).resizeEventStart,
                onStart: onResizeStart,
                onUpdate: onResizeUpdate,
                onEnd: onResizeEnd,
                onCancel: onResizeCancel,
              ),
              _GridResizeHandle(
                key: const Key('draft-resize-end'),
                edge: _ResizeEdge.end,
                color: Theme.of(context).colorScheme.primary,
                semanticLabel: AppLocalizations.of(context).resizeEventEnd,
                onStart: onResizeStart,
                onUpdate: onResizeUpdate,
                onEnd: onResizeEnd,
                onCancel: onResizeCancel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridResizeHandle extends StatefulWidget {
  const _GridResizeHandle({
    super.key,
    required this.edge,
    required this.color,
    required this.semanticLabel,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  final _ResizeEdge edge;
  final Color color;
  final String semanticLabel;
  final ValueChanged<_ResizeEdge> onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final GestureDragCancelCallback onCancel;

  @override
  State<_GridResizeHandle> createState() => _GridResizeHandleState();
}

class _GridResizeHandleState extends State<_GridResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: 0,
      end: 0,
      top: widget.edge == _ResizeEdge.start ? 0 : null,
      bottom: widget.edge == _ResizeEdge.end ? 0 : null,
      height: 24,
      child: Semantics(
        slider: true,
        label: widget.semanticLabel,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: (_) => widget.onStart(widget.edge),
            onVerticalDragUpdate: widget.onUpdate,
            onVerticalDragEnd: widget.onEnd,
            onVerticalDragCancel: widget.onCancel,
            child: Center(
              child: AnimatedContainer(
                duration: WeekraMotion.resolve(context, WeekraMotion.quick),
                width: _hovered ? 28 : 18,
                height: 2,
                decoration: BoxDecoration(
                  color: _hovered
                      ? widget.color.withValues(alpha: .86)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: _hovered
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: .34),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentTimeLine extends StatelessWidget {
  const _CurrentTimeLine({
    required this.now,
    required this.todayIndex,
    required this.columnWidth,
    required this.scale,
    required this.gutterWidth,
  });

  final DateTime now;
  final int todayIndex;
  final double columnWidth;
  final _TimelineScale scale;
  final double gutterWidth;

  @override
  Widget build(BuildContext context) {
    final minutes = now.hour * 60 + now.minute;
    final top = scale.yForMinute(minutes);
    final accent = Theme.of(context).colorScheme.primary;

    return AnimatedPositionedDirectional(
      start: gutterWidth + todayIndex * columnWidth - 3,
      top: top - 3,
      width: columnWidth + 3,
      height: 7,
      duration: WeekraMotion.resolve(context, WeekraMotion.control),
      curve: WeekraMotion.emphasized,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          Expanded(child: Container(height: 1.25, color: accent)),
        ],
      ),
    );
  }
}

