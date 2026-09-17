part of '../week_screen.dart';

class _WeekHourlyLayout extends StatefulWidget {
  const _WeekHourlyLayout({
    super.key,
    required this.days,
    required this.events,
    required this.now,
    required this.navigationDirection,
    required this.onEventTap,
    required this.onCreateEvent,
    required this.onEventChanged,
    required this.onEventContextMenu,
  });

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final DateTime now;
  final int navigationDirection;
  final _OpenEventCallback onEventTap;
  final _CreateEventCallback onCreateEvent;
  final ValueChanged<CalendarEvent> onEventChanged;
  final _EventContextMenuCallback onEventContextMenu;

  @override
  State<_WeekHourlyLayout> createState() => _WeekHourlyLayoutState();
}

class _WeekHourlyLayoutState extends State<_WeekHourlyLayout> {
  final _gridKey = GlobalKey();
  final _draftAnchorKey = GlobalKey();
  final _focusNode = FocusNode(debugLabel: 'Week hourly interactions');
  late List<CalendarEvent> _cachedAllDayEvents;
  late List<_EventPlacement> _cachedTimedPlacements;
  late Map<String, CalendarEvent> _cachedEventsById;
  CalendarEvent? _draftEvent;
  CalendarEvent? _movingEvent;
  CalendarEvent? _resizeOrigin;
  CalendarEvent? _resizingEvent;
  String? _selectedEventId;
  _ResizeEdge? _resizeEdge;
  int? _lastFeedbackStep;
  int? _createAnchorDayIndex;
  int? _createAnchorMinute;
  int? _focusMinute;
  bool _editingDraft = false;
  bool _discardingDraft = false;
  int _draftSession = 0;

  @override
  void initState() {
    super.initState();
    _refreshEventLayoutCache();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _WeekHourlyLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.events, widget.events) ||
        _dateKey(oldWidget.days.first) != _dateKey(widget.days.first)) {
      _refreshEventLayoutCache();
    }
    if (_selectedEventId != null &&
        !widget.events.any((event) => event.id == _selectedEventId)) {
      _selectedEventId = null;
      _focusMinute = null;
    }
  }

  void _refreshEventLayoutCache() {
    _cachedEventsById = {for (final event in widget.events) event.id: event};
    _cachedAllDayEvents = widget.events
        .where(_isAllDayEvent)
        .toList(growable: false);
    final timedSegments = widget.events
        .where((event) => !_isAllDayEvent(event))
        .expand((event) => _timedEventSegments(event, widget.days.first));
    _cachedTimedPlacements = _eventPlacements(timedSegments);
  }

  List<_EventPlacement> _displayedTimedPlacements() {
    if (_movingEvent == null && _resizingEvent == null) {
      return _cachedTimedPlacements;
    }
    final timedSegments = widget.events
        .where((event) => !_isAllDayEvent(event))
        .map(_displayEvent)
        .expand((event) => _timedEventSegments(event, widget.days.first));
    return _eventPlacements(timedSegments);
  }

  Offset? _gridPosition(Offset globalPosition) {
    final renderObject = _gridKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.globalToLocal(globalPosition);
  }

  _TimelineScale _interactionScale(_TimelineScale renderedScale) =>
      _TimelineScale(height: renderedScale.height, focusMinute: _focusMinute);

  void _selectNewSlot(
    Offset globalPosition, {
    required double gutterWidth,
    required double columnWidth,
    required _TimelineScale scale,
    required bool alignToHour,
  }) {
    _focusNode.requestFocus();
    final position = _gridPosition(globalPosition);
    if (position == null || position.dx < gutterWidth) {
      setState(() {
        _draftSession++;
        _draftEvent = null;
        _selectedEventId = null;
        _focusMinute = null;
      });
      return;
    }

    final dayIndex = ((position.dx - gutterWidth) / columnWidth)
        .floor()
        .clamp(0, widget.days.length - 1)
        .toInt();
    const firstMinute = 0;
    const lastMinute = 24 * 60;
    const lastStartMinute = lastMinute - _gridSnapMinutes;
    final rawMinute = scale.minuteForY(position.dy);
    final minute =
        (alignToHour ? _hourStartForMinute(rawMinute) : _snapMinutes(rawMinute))
            .clamp(firstMinute, lastStartMinute)
            .toInt();
    final day = widget.days[dayIndex];
    final start = _dateAtMinute(day, minute);

    setState(() {
      _draftSession++;
      _selectedEventId = null;
      // Creating a draft must not reshape the entire 24-hour timeline. The
      // uniform scale keeps every existing event stationary and makes the
      // first preview frame cheap enough to feel immediate.
      _focusMinute = null;
      _draftEvent = CalendarEvent(
        id: '_draft',
        title: '',
        start: start,
        end: _dateAtMinute(
          day,
          math.min(minute + _defaultEventMinutes, 24 * 60),
        ),
        color: Theme.of(context).colorScheme.primary,
      );
    });
    HapticFeedback.selectionClick();
  }

  void _startCreating(
    Offset globalPosition, {
    required double gutterWidth,
    required double columnWidth,
    required _TimelineScale scale,
  }) {
    _selectNewSlot(
      globalPosition,
      gutterWidth: gutterWidth,
      columnWidth: columnWidth,
      scale: scale,
      alignToHour: false,
    );
    final draft = _draftEvent;
    if (draft == null) {
      return;
    }
    _createAnchorDayIndex = draft.dayIndexIn(widget.days.first);
    _createAnchorMinute = draft.startMinutes;
    _lastFeedbackStep = draft.startMinutes;
  }

  void _updateCreating(Offset globalPosition, {required _TimelineScale scale}) {
    final dayIndex = _createAnchorDayIndex;
    final anchor = _createAnchorMinute;
    final position = _gridPosition(globalPosition);
    if (dayIndex == null || anchor == null || position == null) {
      return;
    }
    const firstMinute = 0;
    const lastMinute = 24 * 60;
    final current = _snapMinutes(
      _interactionScale(scale).minuteForY(position.dy),
    ).clamp(firstMinute, lastMinute).toInt();
    final startMinute = math.min(anchor, current);
    final endMinute = math
        .max(math.max(anchor, current), startMinute + _minimumEventMinutes)
        .clamp(firstMinute + _minimumEventMinutes, lastMinute)
        .toInt();
    final day = widget.days[dayIndex];
    final draft = CalendarEvent(
      id: '_draft',
      title: '',
      start: _dateAtMinute(day, startMinute),
      end: _dateAtMinute(day, endMinute),
      color: Theme.of(context).colorScheme.primary,
    );
    if (current != _lastFeedbackStep) {
      _lastFeedbackStep = current;
      HapticFeedback.selectionClick();
    }
    setState(() => _draftEvent = draft);
  }

  void _finishCreating() {
    if (_createAnchorMinute != null) {
      HapticFeedback.mediumImpact();
    }
    _createAnchorDayIndex = null;
    _createAnchorMinute = null;
    _lastFeedbackStep = null;
    _openDraftEditor();
  }

  Future<void> _openDraftEditor() async {
    final draft = _draftEvent;
    if (draft == null || _editingDraft) {
      return;
    }
    final session = _draftSession;
    setState(() {
      _editingDraft = true;
      _discardingDraft = false;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    if (_draftSession != session || _draftEvent == null) {
      if (_editingDraft) {
        setState(() => _editingDraft = false);
      }
      return;
    }
    final anchorRect = _globalRectFor(_draftAnchorKey.currentContext);
    final saved = await widget.onCreateEvent(
      start: draft.start,
      end: draft.end,
      anchorRect: anchorRect,
    );
    if (!mounted || _draftSession != session) {
      return;
    }
    if (_draftEvent == null) {
      setState(() => _editingDraft = false);
      return;
    }
    if (saved) {
      setState(() {
        _draftSession++;
        _draftEvent = null;
        _editingDraft = false;
        _focusMinute = null;
      });
      return;
    }
    final dismissDuration = WeekraMotion.resolve(context, WeekraMotion.quick);
    setState(() {
      _editingDraft = false;
      _discardingDraft = true;
    });
    if (dismissDuration != Duration.zero) {
      await Future<void>.delayed(dismissDuration);
    }
    if (!mounted) {
      return;
    }
    if (_draftSession != session) {
      return;
    }
    setState(() {
      _draftSession++;
      _draftEvent = null;
      _discardingDraft = false;
      _focusMinute = null;
    });
  }

  void _selectEvent(CalendarEvent event) {
    _focusNode.requestFocus();
    setState(() {
      _draftSession++;
      _draftEvent = null;
      _selectedEventId = event.id;
      _focusMinute = (event.startMinutes + event.endMinutes) ~/ 2;
    });
    HapticFeedback.selectionClick();
  }

  void _startMoving(CalendarEvent event) {
    _focusNode.requestFocus();
    setState(() {
      _draftSession++;
      _draftEvent = null;
      _selectedEventId = event.id;
      _focusMinute = (event.startMinutes + event.endMinutes) ~/ 2;
      _movingEvent = event;
      _resizingEvent = null;
      _resizeOrigin = null;
      _resizeEdge = null;
      _lastFeedbackStep = null;
    });
    HapticFeedback.mediumImpact();
  }

  void _updateMoving(
    Offset globalPosition, {
    required double gutterWidth,
    required double columnWidth,
    required _TimelineScale scale,
  }) {
    final moving = _movingEvent;
    final position = _gridPosition(globalPosition);
    if (moving == null || position == null) {
      return;
    }

    final dayIndex = ((position.dx - gutterWidth) / columnWidth)
        .floor()
        .clamp(0, widget.days.length - 1)
        .toInt();
    const firstMinute = 0;
    const lastMinute = 24 * 60;
    final duration = math.min(
      math.max(_minimumEventMinutes, moving.durationMinutes),
      lastMinute - firstMinute,
    );
    final maxStart = math.max(firstMinute, lastMinute - duration);
    final minute = _snapMinutes(
      _interactionScale(scale).minuteForY(position.dy) - duration / 2,
    ).clamp(firstMinute, maxStart).toInt();
    final day = widget.days[dayIndex];
    final start = _dateAtMinute(day, minute);
    final updated = _copyEvent(
      moving,
      start: start,
      end: start.add(Duration(minutes: duration)),
    );
    final feedbackStep = dayIndex * 24 * 60 + minute;
    if (feedbackStep != _lastFeedbackStep) {
      _lastFeedbackStep = feedbackStep;
      HapticFeedback.selectionClick();
    }
    setState(() => _movingEvent = updated);
  }

  void _finishMoving() {
    final moved = _movingEvent;
    if (moved == null) {
      return;
    }
    CalendarEvent? original;
    for (final event in widget.events) {
      if (event.id == moved.id) {
        original = event;
        break;
      }
    }
    setState(() {
      _movingEvent = null;
      _lastFeedbackStep = null;
      _selectedEventId = null;
      _focusMinute = null;
    });
    if (original != null &&
        (original.start != moved.start || original.end != moved.end)) {
      HapticFeedback.mediumImpact();
      widget.onEventChanged(moved);
    }
  }

  void _cancelMoving() {
    setState(() {
      _movingEvent = null;
      _lastFeedbackStep = null;
      _selectedEventId = null;
      _focusMinute = null;
    });
  }

  void _startResizing(CalendarEvent event, _ResizeEdge edge) {
    _focusNode.requestFocus();
    setState(() {
      _draftSession++;
      _draftEvent = null;
      _selectedEventId = event.id;
      _movingEvent = null;
      _resizeOrigin = event;
      _resizingEvent = event;
      _resizeEdge = edge;
      // No `_focusMinute` here either: rescaling the grid while the pointer is
      // already down slides the edge out from under it.
      _lastFeedbackStep = null;
    });
    HapticFeedback.selectionClick();
  }

  void _updateResizing(
    DragUpdateDetails details, {
    required _TimelineScale scale,
  }) {
    final origin = _resizeOrigin;
    final edge = _resizeEdge;
    if (origin == null || edge == null) {
      return;
    }
    final position = _gridPosition(details.globalPosition);
    if (position == null) {
      return;
    }
    final pointerMinute = _snapMinutes(
      _interactionScale(scale).minuteForY(position.dy),
    );
    final day = DateTime(
      origin.start.year,
      origin.start.month,
      origin.start.day,
    );
    const firstMinute = 0;
    const lastMinute = 24 * 60;
    late final CalendarEvent resized;
    late final int feedbackStep;

    if (edge == _ResizeEdge.start) {
      final latestStart = origin.endMinutes - _minimumEventMinutes;
      final minute = pointerMinute.clamp(firstMinute, latestStart).toInt();
      feedbackStep = minute;
      resized = _copyEvent(origin, start: _dateAtMinute(day, minute));
    } else {
      final earliestEnd = origin.startMinutes + _minimumEventMinutes;
      final minute = pointerMinute.clamp(earliestEnd, lastMinute).toInt();
      feedbackStep = minute;
      resized = _copyEvent(origin, end: _dateAtMinute(day, minute));
    }

    if (feedbackStep != _lastFeedbackStep) {
      _lastFeedbackStep = feedbackStep;
      HapticFeedback.selectionClick();
    }
    setState(() => _resizingEvent = resized);
  }

  void _finishResizing() {
    final origin = _resizeOrigin;
    final resized = _resizingEvent;
    if (origin == null || resized == null) {
      return;
    }
    setState(() {
      _resizeOrigin = null;
      _resizingEvent = null;
      _resizeEdge = null;
      _lastFeedbackStep = null;
      _selectedEventId = null;
      _focusMinute = null;
    });
    if (origin.start != resized.start || origin.end != resized.end) {
      HapticFeedback.mediumImpact();
      widget.onEventChanged(resized);
    }
  }

  void _cancelResizing() {
    setState(() {
      _resizeOrigin = null;
      _resizingEvent = null;
      _resizeEdge = null;
      _lastFeedbackStep = null;
      _selectedEventId = null;
      _focusMinute = null;
    });
  }

  void _cancelTemporaryOperation() {
    if (_editingDraft) {
      Navigator.of(context).maybePop();
    }
    final draftOrigin = _resizeOrigin?.id == '_draft' ? _resizeOrigin : null;
    setState(() {
      _draftSession++;
      _draftEvent = draftOrigin;
      _movingEvent = null;
      _resizeOrigin = null;
      _resizingEvent = null;
      _resizeEdge = null;
      _lastFeedbackStep = null;
      _createAnchorDayIndex = null;
      _createAnchorMinute = null;
      _editingDraft = false;
      _discardingDraft = false;
      _selectedEventId = null;
      _focusMinute = null;
    });
  }

  bool _consumeGridTapToCancelDraft() {
    // A click outside an active draft is a cancellation gesture. It must not
    // fall through and become the starting click of another event.
    if (_editingDraft) {
      return true;
    }
    if (_draftEvent == null && !_discardingDraft) {
      return false;
    }
    setState(() {
      _draftSession++;
      _draftEvent = null;
      _resizeOrigin = null;
      _resizingEvent = null;
      _resizeEdge = null;
      _lastFeedbackStep = null;
      _createAnchorDayIndex = null;
      _createAnchorMinute = null;
      _discardingDraft = false;
      _selectedEventId = null;
      _focusMinute = null;
    });
    return true;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (_draftEvent != null ||
          _movingEvent != null ||
          _resizingEvent != null) {
        _cancelTemporaryOperation();
        return KeyEventResult.handled;
      }
      if (_focusMinute != null || _selectedEventId != null) {
        setState(() {
          _focusMinute = null;
          _selectedEventId = null;
        });
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  CalendarEvent _displayEvent(CalendarEvent event) {
    if (_movingEvent?.id == event.id) {
      return _movingEvent!;
    }
    if (_resizingEvent?.id == event.id) {
      return _resizingEvent!;
    }
    return event;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 900;
          final desktopPointers = _usesDesktopPointerRules(context);
          final allDayEvents = _cachedAllDayEvents;
          final displayedTimedPlacements = _displayedTimedPlacements();
          const startHour = 0;
          const endHour = 24;
          final allDayCount = List.generate(
            7,
            (dayIndex) => allDayEvents
                .where(
                  (event) => _eventOccursOnDay(event, widget.days[dayIndex]),
                )
                .length,
          ).fold<int>(0, math.max);
          final allDayHeight = allDayEvents.isEmpty
              ? 0.0
              : 11.0 + allDayCount * 28 + math.max(0, allDayCount - 1) * 3;
          final headerTextHeight = narrow ? 27.0 : 31.0;
          final headerHeight =
              (narrow ? 58.0 : 64.0) +
              math.max(
                0,
                MediaQuery.textScalerOf(context).scale(headerTextHeight) -
                    headerTextHeight,
              );
          final gutterWidth = _timeGutterWidth(context, startHour, endHour);
          final columnWidth = (constraints.maxWidth - gutterWidth) / 7;
          final gridHeight = math.max(
            1.0,
            constraints.maxHeight - headerHeight - allDayHeight - 1,
          );
          final scale = _TimelineScale(
            height: gridHeight,
            focusMinute: _focusMinute,
          );
          final todayIndex = widget.days.indexWhere(
            (day) => _isSameDay(day, widget.now),
          );

          return Column(
            key: const Key('week-hourly-layout'),
            children: [
              SizedBox(
                height: headerHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: gutterWidth),
                    Expanded(
                      child: ClipRect(
                        child: _FlowingDateSwitcher(
                          direction: widget.navigationDirection,
                          travelDistance: columnWidth,
                          child: Row(
                            key: ValueKey(
                              'hourly-header-${_dateKey(widget.days.first)}',
                            ),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final day in widget.days)
                                Expanded(
                                  child: _GridDayHeader(
                                    day: day,
                                    isToday: _isSameDay(day, widget.now),
                                    narrow: narrow,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (allDayEvents.isNotEmpty) ...[
                const Divider(height: 1, color: _subtleLine),
                _AllDayBand(
                  days: widget.days,
                  events: allDayEvents,
                  today: widget.now,
                  gutterWidth: gutterWidth,
                  navigationDirection: widget.navigationDirection,
                  onEventTap: widget.onEventTap,
                ),
              ],
              const Divider(height: 1, color: _line),
              Expanded(
                key: const Key('hourly-viewport'),
                child: SizedBox.expand(
                  key: const Key('hourly-scroll'),
                  child: KeyedSubtree(
                    key: const Key('week-hourly-grid'),
                    child: GestureDetector(
                      key: _gridKey,
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onTapUp: (details) {
                        if (_consumeGridTapToCancelDraft()) {
                          return;
                        }
                        _selectNewSlot(
                          details.globalPosition,
                          gutterWidth: gutterWidth,
                          columnWidth: columnWidth,
                          scale: scale,
                          alignToHour: true,
                        );
                        _openDraftEditor();
                      },
                      onPanStart: desktopPointers
                          ? (details) => _startCreating(
                              details.globalPosition,
                              gutterWidth: gutterWidth,
                              columnWidth: columnWidth,
                              scale: scale,
                            )
                          : null,
                      onPanUpdate: desktopPointers
                          ? (details) => _updateCreating(
                              details.globalPosition,
                              scale: scale,
                            )
                          : null,
                      onPanEnd: desktopPointers
                          ? (_) => _finishCreating()
                          : null,
                      onPanCancel: desktopPointers
                          ? _cancelTemporaryOperation
                          : null,
                      onLongPressStart: desktopPointers
                          ? null
                          : (details) => _startCreating(
                              details.globalPosition,
                              gutterWidth: gutterWidth,
                              columnWidth: columnWidth,
                              scale: scale,
                            ),
                      onLongPressMoveUpdate: desktopPointers
                          ? null
                          : (details) => _updateCreating(
                              details.globalPosition,
                              scale: scale,
                            ),
                      onLongPressEnd: desktopPointers
                          ? null
                          : (_) => _finishCreating(),
                      onLongPressCancel: desktopPointers
                          ? null
                          : _cancelTemporaryOperation,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          if (scale.hasFocus)
                            _TimelineFocusBand(
                              scale: scale,
                              gutterWidth: gutterWidth,
                            ),
                          for (var hour = startHour; hour <= endHour; hour++)
                            _HourRule(
                              top: scale.yForMinute(hour * 60),
                              gutterWidth: gutterWidth,
                              label: _formatTime(context, hour * 60),
                              isDayEnd: hour == endHour,
                            ),
                          if (scale.hasFocus)
                            for (
                              var minute = scale.focusStartMinute + 15;
                              minute < scale.focusEndMinute;
                              minute += 15
                            )
                              if (minute % 60 != 0)
                                _MinuteRule(
                                  top: scale.yForMinute(minute),
                                  gutterWidth: gutterWidth,
                                  label: minute % 30 == 0
                                      ? _formatTime(context, minute)
                                      : null,
                                ),
                          PositionedDirectional(
                            start: gutterWidth,
                            end: 0,
                            top: 0,
                            bottom: 0,
                            child: ClipRect(
                              child: _FlowingDateSwitcher(
                                direction: widget.navigationDirection,
                                travelDistance: columnWidth,
                                child: SizedBox.expand(
                                  key: ValueKey(
                                    'hourly-canvas-'
                                    '${_dateKey(widget.days.first)}',
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      if (todayIndex >= 0)
                                        PositionedDirectional(
                                          key: const Key(
                                            'timeline-today-column',
                                          ),
                                          start: todayIndex * columnWidth,
                                          top: 0,
                                          bottom: 0,
                                          width: columnWidth,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.045),
                                                  WeekraColors.textPrimary
                                                      .withValues(alpha: 0.012),
                                                  Colors.transparent,
                                                ],
                                                stops: const [0, .36, 1],
                                              ),
                                            ),
                                          ),
                                        ),
                                      for (final placement
                                          in displayedTimedPlacements)
                                        Builder(
                                          builder: (context) {
                                            final displayedEvent =
                                                placement.event;
                                            final originalEvent =
                                                _cachedEventsById[displayedEvent
                                                    .id]!;
                                            final displayedOriginal =
                                                _displayEvent(originalEvent);
                                            final isLeadingSegment =
                                                displayedEvent.start ==
                                                displayedOriginal.start;
                                            final segmentDayIndex =
                                                displayedEvent.dayIndexIn(
                                                  widget.days.first,
                                                );
                                            final segmentKey = isLeadingSegment
                                                ? 'hourly-event-${originalEvent.id}'
                                                : 'hourly-event-${originalEvent.id}'
                                                      '-continuation-$segmentDayIndex';
                                            return _GridEvent(
                                              key: ValueKey(
                                                'segment-$segmentKey',
                                              ),
                                              eventKey: Key(segmentKey),
                                              event: displayedEvent,
                                              dayIndex: segmentDayIndex,
                                              lane: placement.lane,
                                              laneCount: placement.laneCount,
                                              columnWidth: columnWidth,
                                              gutterWidth: 0,
                                              scale: scale,
                                              narrow: narrow,
                                              isSelected:
                                                  _selectedEventId ==
                                                  originalEvent.id,
                                              isManipulating:
                                                  _movingEvent?.id ==
                                                  originalEvent.id,
                                              isResizing:
                                                  _resizingEvent?.id ==
                                                  originalEvent.id,
                                              allowResize: _isSameDay(
                                                displayedOriginal.start,
                                                displayedOriginal.end,
                                              ),
                                              desktopPointers: desktopPointers,
                                              onFocus: () =>
                                                  _selectEvent(originalEvent),
                                              onTap: (anchorRect) async {
                                                await widget.onEventTap(
                                                  originalEvent,
                                                  anchorRect: anchorRect,
                                                );
                                              },
                                              onSecondaryTap:
                                                  (anchorRect, position) async {
                                                    await widget
                                                        .onEventContextMenu(
                                                          originalEvent,
                                                          anchorRect:
                                                              anchorRect,
                                                          position: position,
                                                        );
                                                  },
                                              onMoveStart: () =>
                                                  _startMoving(originalEvent),
                                              onMoveUpdate: (globalPosition) =>
                                                  _updateMoving(
                                                    globalPosition,
                                                    gutterWidth: gutterWidth,
                                                    columnWidth: columnWidth,
                                                    scale: scale,
                                                  ),
                                              onMoveEnd: _finishMoving,
                                              onMoveCancel: _cancelMoving,
                                              onResizeStart: (edge) =>
                                                  _startResizing(
                                                    originalEvent,
                                                    edge,
                                                  ),
                                              onResizeUpdate: (details) =>
                                                  _updateResizing(
                                                    details,
                                                    scale: scale,
                                                  ),
                                              onResizeEnd: (_) =>
                                                  _finishResizing(),
                                              onResizeCancel: _cancelResizing,
                                            );
                                          },
                                        ),
                                      if (_draftEvent case final draft?)
                                        _GridDraftEvent(
                                          event: draft,
                                          anchorKey: _draftAnchorKey,
                                          dayIndex: draft.dayIndexIn(
                                            widget.days.first,
                                          ),
                                          columnWidth: columnWidth,
                                          gutterWidth: 0,
                                          scale: scale,
                                          compact: narrow,
                                          manipulating:
                                              _createAnchorMinute != null ||
                                              _resizingEvent?.id == '_draft',
                                          discarding: _discardingDraft,
                                          onTap: _openDraftEditor,
                                          onResizeStart: (edge) =>
                                              _startDraftResizing(draft, edge),
                                          onResizeUpdate: (details) =>
                                              _updateDraftResize(
                                                details,
                                                scale: scale,
                                              ),
                                          onResizeEnd: (_) =>
                                              _finishDraftResize(),
                                          onResizeCancel: _cancelDraftResize,
                                        ),
                                      if (todayIndex >= 0)
                                        _CurrentTimeLine(
                                          now: widget.now,
                                          todayIndex: todayIndex,
                                          columnWidth: columnWidth,
                                          scale: scale,
                                          gutterWidth: 0,
                                        ),
                                    ],
                                  ),
                                ),
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
          );
        },
      ),
    );
  }

  void _updateDraftResize(
    DragUpdateDetails details, {
    required _TimelineScale scale,
  }) {
    final origin = _resizeOrigin;
    final edge = _resizeEdge;
    if (origin == null || edge == null || origin.id != '_draft') {
      return;
    }
    final position = _gridPosition(details.globalPosition);
    if (position == null) {
      return;
    }
    final pointerMinute = _snapMinutes(
      _interactionScale(scale).minuteForY(position.dy),
    );
    final day = DateTime(
      origin.start.year,
      origin.start.month,
      origin.start.day,
    );
    const firstMinute = 0;
    const lastMinute = 24 * 60;
    late final CalendarEvent resized;
    late final int feedbackStep;
    if (edge == _ResizeEdge.start) {
      final minute = pointerMinute
          .clamp(firstMinute, origin.endMinutes - _minimumEventMinutes)
          .toInt();
      feedbackStep = minute;
      resized = _copyEvent(origin, start: _dateAtMinute(day, minute));
    } else {
      final minute = pointerMinute
          .clamp(origin.startMinutes + _minimumEventMinutes, lastMinute)
          .toInt();
      feedbackStep = minute;
      resized = _copyEvent(origin, end: _dateAtMinute(day, minute));
    }
    if (feedbackStep != _lastFeedbackStep) {
      _lastFeedbackStep = feedbackStep;
      HapticFeedback.selectionClick();
    }
    setState(() {
      _draftEvent = resized;
      _resizingEvent = resized;
    });
  }

  void _startDraftResizing(CalendarEvent draft, _ResizeEdge edge) {
    setState(() {
      _resizeOrigin = draft;
      _resizingEvent = draft;
      _resizeEdge = edge;
      _lastFeedbackStep = null;
    });
    HapticFeedback.selectionClick();
  }

  void _finishDraftResize() {
    setState(() {
      _resizeOrigin = null;
      _resizingEvent = null;
      _resizeEdge = null;
      _lastFeedbackStep = null;
    });
  }

  void _cancelDraftResize() {
    final origin = _resizeOrigin;
    setState(() {
      if (origin?.id == '_draft') {
        _draftEvent = origin;
      }
      _resizeOrigin = null;
      _resizingEvent = null;
      _resizeEdge = null;
      _lastFeedbackStep = null;
    });
  }
}

