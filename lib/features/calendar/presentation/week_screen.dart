import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:weekra/app/weekra_design.dart';
import 'package:weekra/app/glass_surface.dart';
import 'package:weekra/app/weekra_theme.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';
import 'package:weekra/features/calendar/domain/event_category.dart';
import 'package:weekra/features/calendar/domain/event_category_suggestion.dart';
import 'package:weekra/features/settings/domain/app_settings.dart';
import 'package:weekra/l10n/app_localizations.dart';

part 'week/week_shared.dart';
part 'week/week_layout_stage.dart';
part 'week/week_toolbar.dart';
part 'week/month_layout.dart';
part 'week/overview_agenda.dart';
part 'week/hourly_layout.dart';
part 'week/hourly_chrome.dart';
part 'week/hourly_event.dart';
part 'week/event_editor.dart';
part 'week/event_details.dart';
part 'week/floating_card.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({
    super.key,
    required this.eventStore,
    required this.calendarSettings,
    required this.categorySettings,
    this.theme = WeekraTheme.ember,
    this.onOpenSettings,
    this.clock,
  });

  final CalendarEventStore eventStore;
  final CalendarViewSettings calendarSettings;
  final CategorySettings categorySettings;
  final WeekraTheme theme;
  final VoidCallback? onOpenSettings;
  final DateTime Function()? clock;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late DateTime _weekStart;
  late DateTime _monthStart;
  int _navigationDirection = 0;
  _WeekLayout _layout = _WeekLayout.grid;
  List<CalendarEvent> _events = [];
  bool _isLoading = true;
  bool _didStartLoading = false;
  bool _didChooseInitialLayout = false;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    final now = _now();
    _weekStart = _timelineStart(now, widget.calendarSettings);
    _monthStart = DateTime(now.year, now.month);
  }

  @override
  void didUpdateWidget(covariant WeekScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameCalendarSettings(
      oldWidget.calendarSettings,
      widget.calendarSettings,
    )) {
      final target = _timelineStart(_now(), widget.calendarSettings);
      _navigationDirection = target.isAfter(_weekStart)
          ? 1
          : target.isBefore(_weekStart)
          ? -1
          : 0;
      _weekStart = target;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didChooseInitialLayout) {
      _layout = MediaQuery.sizeOf(context).width >= 760
          ? _WeekLayout.hourly
          : _WeekLayout.grid;
      _didChooseInitialLayout = true;
    }
    if (_didStartLoading) {
      return;
    }
    _didStartLoading = true;
    _loadEvents(AppLocalizations.of(context));
  }

  Future<void> _loadEvents(AppLocalizations l10n) async {
    try {
      final storedEvents = await widget.eventStore.load();
      final events = storedEvents ?? const <CalendarEvent>[];
      if (!mounted) {
        return;
      }
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _storageError = l10n.localEventsLoadError;
      });
    }
  }

  Future<bool> _createEvent({
    DateTime? initialStart,
    DateTime? initialEnd,
    Rect? anchorRect,
  }) async {
    final event = await _showEventEditorSheet(
      context,
      _weekStart,
      initialStart: initialStart,
      initialEnd: initialEnd,
      anchorRect: anchorRect,
      suggestionEvents: _events,
      categorySettings: widget.categorySettings,
      onSave: (event) async {
        final updatedEvents = [..._events, event]
          ..sort((a, b) => a.start.compareTo(b.start));
        return _persistMutation(
          updatedEvents,
          failureMessage: AppLocalizations.of(context).eventSaveError,
        );
      },
    );
    return event != null;
  }

  Future<void> _changeEventFromGrid(CalendarEvent changedEvent) async {
    final l10n = AppLocalizations.of(context);
    final updatedEvents =
        _events
            .map((event) => event.id == changedEvent.id ? changedEvent : event)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    await _persistMutation(
      updatedEvents,
      failureMessage: l10n.eventChangesSaveError,
    );
  }

  Future<void> _openEvent(CalendarEvent event, {Rect? anchorRect}) async {
    final action = await _showEventDetailsSheet(
      context,
      event,
      anchorRect: anchorRect,
    );
    if (action == null || !mounted) {
      return;
    }

    if (action == _EventAction.edit) {
      await _editEvent(event, anchorRect: anchorRect);
      return;
    }

    await _deleteEvent(event);
  }

  Future<void> _editEvent(CalendarEvent event, {Rect? anchorRect}) async {
    await _showEventEditorSheet(
      context,
      _weekStart,
      existingEvent: event,
      anchorRect: anchorRect,
      suggestionEvents: _events,
      categorySettings: widget.categorySettings,
      onSave: (updatedEvent) async {
        final updatedEvents =
            _events
                .map((item) => item.id == event.id ? updatedEvent : item)
                .toList()
              ..sort((a, b) => a.start.compareTo(b.start));
        return _persistMutation(
          updatedEvents,
          failureMessage: AppLocalizations.of(context).eventChangesSaveError,
        );
      },
    );
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final l10n = AppLocalizations.of(context);
    final shouldDelete = await _confirmDelete(context, event);
    if (!shouldDelete || !mounted) {
      return;
    }
    await _persistMutation(
      _events.where((item) => item.id != event.id).toList(),
      failureMessage: l10n.eventDeleteError,
    );
  }

  Future<void> _copyEventFromMenu(CalendarEvent event) async {
    final duplicate = CalendarEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: event.title,
      start: event.start,
      end: event.end,
      color: event.color,
      categoryId: event.categoryId,
      location: event.location,
    );
    final updatedEvents = [..._events, duplicate]
      ..sort((a, b) => a.start.compareTo(b.start));
    await _persistMutation(
      updatedEvents,
      failureMessage: AppLocalizations.of(context).eventCopyError,
    );
  }

  Future<void> _setEventCategory(CalendarEvent event, String categoryId) async {
    final category = _resolvedCategory(widget.categorySettings, categoryId);
    final updatedEvent = CalendarEvent(
      id: event.id,
      title: event.title,
      start: event.start,
      end: event.end,
      color: category.color,
      categoryId: category.id,
      location: event.location,
    );
    await _changeEventFromGrid(updatedEvent);
  }

  Future<void> _openEventContextMenu(
    CalendarEvent event, {
    required Rect anchorRect,
    required Offset position,
  }) async {
    final selection = await _showEventContextMenu(
      context,
      event,
      position: position,
      categorySettings: widget.categorySettings,
    );
    if (selection == null || !mounted) {
      return;
    }
    switch (selection.action) {
      case _EventContextAction.edit:
        await _editEvent(event, anchorRect: anchorRect);
        break;
      case _EventContextAction.copy:
        await _copyEventFromMenu(event);
        break;
      case _EventContextAction.delete:
        await _deleteEvent(event);
        break;
      case _EventContextAction.category:
        await _setEventCategory(event, selection.categoryId!);
        break;
    }
  }

  Future<bool> _persistMutation(
    List<CalendarEvent> updatedEvents, {
    required String failureMessage,
  }) async {
    final previousEvents = _events;
    setState(() {
      _events = updatedEvents;
      _storageError = null;
    });

    try {
      await widget.eventStore.save(updatedEvents);
      return true;
    } on Object {
      if (!mounted) {
        return false;
      }
      setState(() {
        _events = previousEvents;
        _storageError = failureMessage;
      });
      return false;
    }
  }

  void _moveTimeline(int offset) {
    if (offset == 0) {
      return;
    }
    if (_layout == _WeekLayout.month) {
      final target = DateTime(
        _monthStart.year,
        _monthStart.month + offset,
      );
      setState(() {
        _navigationDirection = offset.sign;
        _monthStart = target;
        _weekStart = _timelineStart(target, widget.calendarSettings);
      });
      return;
    }
    final dayOffset =
        widget.calendarSettings.anchorMode == CalendarAnchorMode.weekStart
        ? offset * DateTime.daysPerWeek
        : offset;
    setState(() {
      _navigationDirection = dayOffset.sign;
      _weekStart = _weekStart.add(Duration(days: dayOffset));
    });
  }

  void _returnToToday() {
    final now = _now();
    final target = _timelineStart(now, widget.calendarSettings);
    final targetMonth = DateTime(now.year, now.month);
    if (_isSameDay(target, _weekStart) &&
        (_layout != _WeekLayout.month ||
            _isSameDay(targetMonth, _monthStart))) {
      return;
    }
    setState(() {
      _navigationDirection = target.isAfter(_weekStart) ? 1 : -1;
      _weekStart = target;
      _monthStart = targetMonth;
    });
  }

  void _setLayout(_WeekLayout layout) {
    if (_layout == layout) {
      return;
    }
    setState(() {
      if (layout == _WeekLayout.month) {
        final now = DateTime(_now().year, _now().month, _now().day);
        final visibleEnd = _weekStart.add(const Duration(days: 7));
        final anchor = !now.isBefore(_weekStart) && now.isBefore(visibleEnd)
            ? now
            : _weekStart.add(const Duration(days: 3));
        _monthStart = DateTime(anchor.year, anchor.month);
      }
      _layout = layout;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = _now();
    final desktopPointers = _usesDesktopPointerRules(context);
    final days = List.generate(
      7,
      (index) => _weekStart.add(Duration(days: index)),
    );
    final events = _events
        .where((event) {
          final visibleEnd = _weekStart.add(const Duration(days: 7));
          return event.end.isAfter(_weekStart) &&
              event.start.isBefore(visibleEnd);
        })
        .map(
          (event) => _eventWithResolvedCategory(event, widget.categorySettings),
        )
        .toList();
    // The overview is a continuous stream rather than one week, so it receives
    // every event instead of the current week's slice.
    final allEvents = _events
        .map(
          (event) => _eventWithResolvedCategory(event, widget.categorySettings),
        )
        .toList();

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            _createEvent(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            _createEvent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _moveTimeline(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _moveTimeline(1),
        const SingleActivator(LogicalKeyboardKey.keyK): () => _moveTimeline(-1),
        const SingleActivator(LogicalKeyboardKey.keyJ): () => _moveTimeline(1),
        const SingleActivator(LogicalKeyboardKey.keyT): _returnToToday,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: WeekraColors.canvas,
          body: SafeArea(
            child: Column(
              children: [
                _WeekToolbar(
                  weekStart: _weekStart,
                  monthStart: _monthStart,
                  layout: _layout,
                  onPrevious: () => _moveTimeline(-1),
                  onNext: () => _moveTimeline(1),
                  onToday: _returnToToday,
                  onLayoutChanged: _setLayout,
                  onSettings: widget.onOpenSettings,
                ),
                if (_storageError != null)
                  _StorageErrorBanner(
                    message: _storageError!,
                    onDismiss: () => setState(() => _storageError = null),
                  ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragEnd: desktopPointers
                              ? null
                              : (details) {
                                  final velocity = details.primaryVelocity ?? 0;
                                  if (velocity.abs() < 350) {
                                    return;
                                  }
                                  _moveTimeline(velocity < 0 ? 1 : -1);
                                },
                          child: _WeekLayoutStage(
                            layout: _layout,
                            hourly: _WeekHourlyLayout(
                              key: const PageStorageKey('hourly-week-view'),
                              days: days,
                              events: events,
                              now: now,
                              navigationDirection: _navigationDirection,
                              onEventTap: _openEvent,
                              onCreateEvent:
                                  ({
                                    required start,
                                    required end,
                                    anchorRect,
                                  }) => _createEvent(
                                    initialStart: start,
                                    initialEnd: end,
                                    anchorRect: anchorRect,
                                  ),
                              onEventChanged: _changeEventFromGrid,
                              onEventContextMenu: _openEventContextMenu,
                            ),
                            overview: _WeekGridSummary(
                              key: const PageStorageKey('overview-week-view'),
                              events: allEvents,
                              today: now,
                              onEventTap: _openEvent,
                              onCreate: (day) => _createEvent(
                                initialStart: day.add(const Duration(hours: 9)),
                                initialEnd: day.add(const Duration(hours: 10)),
                              ),
                            ),
                            month: _MonthLayout(
                              key: const PageStorageKey('month-view'),
                              monthStart: _monthStart,
                              events: allEvents,
                              today: now,
                              onEventTap: _openEvent,
                              onCreate: (day) => _createEvent(
                                initialStart: day.add(const Duration(hours: 9)),
                                initialEnd: day.add(const Duration(hours: 10)),
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
    );
  }

  DateTime _now() => widget.clock?.call() ?? DateTime.now();
}
