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

const _ink = WeekraColors.textPrimary;
const _mutedInk = WeekraColors.textSecondary;
const _tertiaryInk = WeekraColors.textTertiary;
const _line = WeekraColors.divider;
const _subtleLine = WeekraColors.dividerSubtle;
const _gridSnapMinutes = 15;
const _minimumEventMinutes = 15;
const _defaultEventMinutes = 60;

enum _WeekLayout { hourly, grid }

enum _ResizeEdge { start, end }

typedef _CreateEventCallback = Future<bool> Function({
  required DateTime start,
  required DateTime end,
  Rect? anchorRect,
});

typedef _OpenEventCallback = Future<void> Function(
  CalendarEvent event, {
  Rect? anchorRect,
});

typedef _EventContextMenuCallback = Future<void> Function(
  CalendarEvent event, {
  required Rect anchorRect,
  required Offset position,
});

typedef _SaveEventCallback = Future<bool> Function(CalendarEvent event);

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
    _weekStart = _timelineStart(_now(), widget.calendarSettings);
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
    final target = _timelineStart(_now(), widget.calendarSettings);
    if (_isSameDay(target, _weekStart)) {
      return;
    }
    setState(() {
      _navigationDirection = target.isAfter(_weekStart) ? 1 : -1;
      _weekStart = target;
    });
  }

  void _setLayout(_WeekLayout layout) {
    if (_layout == layout) {
      return;
    }
    setState(() => _layout = layout);
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

class _StorageErrorBanner extends StatelessWidget {
  const _StorageErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MaterialBanner(
      content: Text(message, softWrap: true, overflow: TextOverflow.visible),
      leading: const Icon(Icons.error_outline_rounded),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: Text(
            l10n.dismiss,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _WeekLayoutStage extends StatelessWidget {
  const _WeekLayoutStage({
    required this.layout,
    required this.hourly,
    required this.overview,
  });

  final _WeekLayout layout;
  final Widget hourly;
  final Widget overview;

  @override
  Widget build(BuildContext context) {
    final duration = WeekraMotion.resolve(context, WeekraMotion.content);

    Widget layer({required _WeekLayout value, required Widget child}) {
      final active = layout == value;
      return Positioned.fill(
        child: IgnorePointer(
          ignoring: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: duration,
              curve: WeekraMotion.standard,
              child: TickerMode(
                enabled: active,
                child: RepaintBoundary(child: child),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        layer(value: _WeekLayout.hourly, child: hourly),
        layer(value: _WeekLayout.grid, child: overview),
      ],
    );
  }
}

class _WeekToolbar extends StatelessWidget {
  const _WeekToolbar({
    required this.weekStart,
    required this.layout,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onLayoutChanged,
    required this.onSettings,
  });

  final DateTime weekStart;
  final _WeekLayout layout;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<_WeekLayout> onLayoutChanged;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.weekToolbarEyebrow,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _tertiaryInk,
            fontSize: 9,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _weekLabel(materialL10n, weekStart),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 27,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.7,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        WeekraMetrics.pageGutter,
        14,
        18,
        12,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScaler = MediaQuery.textScalerOf(context);
          final shouldStack =
              constraints.maxWidth < 680 || textScaler.scale(14) > 18;
          final showSwitcherLabels =
              constraints.maxWidth >= 900 && textScaler.scale(12) <= 15;
          final todayLabelWidth = _singleLineTextWidth(
            context,
            l10n.today,
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          );
          final navigation = _WeekNavigation(
            compact: todayLabelWidth > (constraints.maxWidth < 420 ? 76 : 120),
            onPrevious: onPrevious,
            onToday: onToday,
            onNext: onNext,
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WeekLayoutSwitcher(
                layout: layout,
                showLabels: showSwitcherLabels,
                onChanged: onLayoutChanged,
              ),
              const SizedBox(width: 8),
              _ToolbarSurface(
                child: WeekraIconButton(
                  key: const Key('open-settings'),
                  onPressed: onSettings,
                  tooltip: l10n.settingsTooltip,
                  icon: const Icon(Icons.tune_rounded, size: 19),
                ),
              ),
            ],
          );

          if (shouldStack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: heading),
                    navigation,
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actions,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: heading),
              navigation,
              const SizedBox(width: 10),
              actions,
            ],
          );
        },
      ),
    );
  }
}

class _WeekNavigation extends StatelessWidget {
  const _WeekNavigation({
    required this.compact,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
  });

  final bool compact;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return _ToolbarSurface(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WeekraIconButton(
            key: const Key('timeline-previous-day'),
            onPressed: onPrevious,
            tooltip: l10n.previousWeekTooltip,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
          ),
          if (compact)
            WeekraIconButton(
              key: const Key('timeline-today'),
              onPressed: onToday,
              tooltip: l10n.today,
              color: accent,
              icon: const Icon(Icons.today_outlined, size: 18),
            )
          else
            _TodayButton(onPressed: onToday, label: l10n.today, color: accent),
          WeekraIconButton(
            key: const Key('timeline-next-day'),
            onPressed: onNext,
            tooltip: l10n.nextWeekTooltip,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _TodayButton extends StatefulWidget {
  const _TodayButton({
    required this.onPressed,
    required this.label,
    required this.color,
  });

  final VoidCallback onPressed;
  final String label;
  final Color color;

  @override
  State<_TodayButton> createState() => _TodayButtonState();
}

class _TodayButtonState extends State<_TodayButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: WeekraPressableScale(
        child: Semantics(
          key: const Key('timeline-today'),
          button: true,
          label: widget.label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              hoverColor: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: WeekraMotion.resolve(context, WeekraMotion.quick),
                curve: WeekraMotion.standard,
                constraints: const BoxConstraints(
                  minWidth: 58,
                  minHeight: WeekraMetrics.controlHeight,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _hovered
                      ? WeekraColors.surfaceRaised
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.color,
                      fontSize: 13,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarSurface extends StatelessWidget {
  const _ToolbarSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      GlassSurface(radius: 20, child: SizedBox(height: 42, child: child));
}

class _WeekLayoutSwitcher extends StatelessWidget {
  const _WeekLayoutSwitcher({
    required this.layout,
    required this.showLabels,
    required this.onChanged,
  });

  final _WeekLayout layout;
  final bool showLabels;
  final ValueChanged<_WeekLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
    final labelWidth = math.max(
      _singleLineTextWidth(context, l10n.weekLayoutHourly, labelStyle),
      _singleLineTextWidth(context, l10n.weekLayoutGrid, labelStyle),
    );
    final width = showLabels ? math.max(204.0, labelWidth * 2 + 108) : 88.0;
    return Semantics(
      container: true,
      label: l10n.weekLayoutPickerLabel,
      child: GlassSegmentedControl(
        width: width,
        selectedIndex: layout == _WeekLayout.hourly ? 0 : 1,
        onChanged: (index) =>
            onChanged(index == 0 ? _WeekLayout.hourly : _WeekLayout.grid),
        children: [
          _WeekLayoutOption(
            key: const Key('week-layout-hourly'),
            icon: Icons.view_week_outlined,
            label: showLabels ? l10n.weekLayoutHourly : null,
            semanticLabel: l10n.weekLayoutHourly,
            selected: layout == _WeekLayout.hourly,
            onTap: () => onChanged(_WeekLayout.hourly),
          ),
          _WeekLayoutOption(
            key: const Key('week-layout-grid'),
            icon: Icons.grid_view_rounded,
            label: showLabels ? l10n.weekLayoutGrid : null,
            semanticLabel: l10n.weekLayoutGrid,
            selected: layout == _WeekLayout.grid,
            onTap: () => onChanged(_WeekLayout.grid),
          ),
        ],
      ),
    );
  }
}

class _WeekLayoutOption extends StatefulWidget {
  const _WeekLayoutOption({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String? label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_WeekLayoutOption> createState() => _WeekLayoutOptionState();
}

class _WeekLayoutOptionState extends State<_WeekLayoutOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final duration = WeekraMotion.resolve(context, WeekraMotion.control);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: WeekraPressableScale(
        child: Semantics(
          button: true,
          selected: widget.selected,
          label: widget.semanticLabel,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              hoverColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: WeekraMotion.resolve(context, WeekraMotion.quick),
                curve: WeekraMotion.standard,
                height: WeekraMetrics.controlHeight - 4,
                margin: const EdgeInsets.all(2),
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: widget.label == null ? 9 : 10,
                ),
                decoration: BoxDecoration(
                  color: _hovered
                      ? WeekraColors.surfaceRaised.withValues(
                          alpha: widget.selected ? .28 : .82,
                        )
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: widget.selected ? 1 : 0),
                  duration: duration,
                  curve: WeekraMotion.standard,
                  builder: (context, value, child) {
                    final hoverValue = _hovered ? 1.0 : value;
                    final contentColor = Color.lerp(
                      _mutedInk,
                      _ink,
                      hoverValue,
                    )!;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.icon, size: 17, color: contentColor),
                        if (widget.label != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.label!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: contentColor,
                                fontSize: 12,
                                height: 1.15,
                                fontWeight: FontWeight.lerp(
                                  FontWeight.w500,
                                  FontWeight.w700,
                                  value,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The overview agenda.
///
/// It is a continuous day stream rather than a single week: the reader can keep
/// scrolling past either end, and the list grows as they approach an edge.
class _WeekGridSummary extends StatefulWidget {
  const _WeekGridSummary({
    super.key,
    required this.today,
    required this.events,
    required this.onEventTap,
    required this.onCreate,
  });

  final DateTime today;
  final List<CalendarEvent> events;
  final _OpenEventCallback onEventTap;
  final ValueChanged<DateTime> onCreate;

  @override
  State<_WeekGridSummary> createState() => _WeekGridSummaryState();
}

class _WeekGridSummaryState extends State<_WeekGridSummary> {
  /// Days rendered on each side of today to begin with.
  static const _initialDays = 45;

  /// Days added every time the reader gets close to an end.
  static const _extendStep = 45;

  /// How close to an end triggers the next extension, in pixels.
  static const _extendThreshold = 600.0;

  static const _todayAnchorKey = Key('overview-today-anchor');
  static const _bottomInset = 92.0;

  late int _pastDays;
  late int _futureDays;

  @override
  void initState() {
    super.initState();
    _pastDays = _initialDays;
    _futureDays = _initialDays;
  }

  DateTime get _origin => DateUtils.dateOnly(widget.today);

  int _dayKey(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

  bool _handleScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (!metrics.hasPixels) {
      return false;
    }
    final extendPast = metrics.extentBefore < _extendThreshold;
    final extendFuture = metrics.extentAfter < _extendThreshold;
    if (!extendPast && !extendFuture) {
      return false;
    }
    setState(() {
      if (extendPast) _pastDays += _extendStep;
      if (extendFuture) _futureDays += _extendStep;
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final byDay = <int, List<CalendarEvent>>{};
    for (final event in widget.events) {
      byDay.putIfAbsent(_dayKey(event.start), () => []).add(event);
    }
    for (final dayEvents in byDay.values) {
      dayEvents.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    }

    Widget dayRow({
      required DateTime day,
      required bool showTopRule,
    }) {
      return _AgendaDay(
        day: day,
        events: byDay[_dayKey(day)] ?? const <CalendarEvent>[],
        isToday: _isSameDay(day, widget.today),
        showTopRule: showTopRule,
        onEventTap: widget.onEventTap,
        onCreate: widget.onCreate,
      );
    }

    final agenda = ColoredBox(
      color: WeekraColors.overviewSurface,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: CustomScrollView(
          key: const Key('week-grid-layout'),
          center: _todayAnchorKey,
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return dayRow(
                  day: _origin.subtract(Duration(days: index + 1)),
                  showTopRule: true,
                );
              }, childCount: _pastDays),
            ),
            SliverList(
              key: _todayAnchorKey,
              delegate: SliverChildBuilderDelegate((context, index) {
                return dayRow(
                  day: _origin.add(Duration(days: index)),
                  showTopRule: index > 0,
                );
              }, childCount: _futureDays),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < WeekraMetrics.overviewPanelBreakpoint) {
          return agenda;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 11, child: agenda),
            Expanded(flex: 9, child: _TodayPanel(today: widget.today)),
          ],
        );
      },
    );
  }
}

/// Global anchor beside the overview agenda.
///
/// It always reports the real current date, so browsing other weeks never
/// changes what "today" means.
class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      key: const Key('overview-today-panel'),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _line)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 22, 24, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              l10n.today,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _tertiaryInk,
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              MaterialLocalizations.of(context).formatFullDate(today),
              textAlign: TextAlign.center,
              softWrap: true,
              style: const TextStyle(
                color: _ink,
                fontSize: 19,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaDay extends StatelessWidget {
  const _AgendaDay({
    required this.day,
    required this.events,
    required this.isToday,
    required this.showTopRule,
    required this.onEventTap,
    required this.onCreate,
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final bool isToday;

  /// The overview is one continuous page, so the day boundary is drawn as a
  /// rule on top of the event area. The first day has nothing above it.
  final bool showTopRule;
  final _OpenEventCallback onEventTap;
  final ValueChanged<DateTime> onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onCreate(day),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const Key('overview-day-column'),
              width: WeekraMetrics.dayColumnWidth,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              color: isToday
                  ? WeekraColors.dayStripToday
                  : WeekraColors.dayStrip,
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
                      fontSize: 10,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isToday ? accent : _ink,
                      fontSize: 20,
                      height: 1.15,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: showTopRule
                      ? const Border(top: BorderSide(color: _line))
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 18, 12),
                  child: events.isEmpty
                      ? const SizedBox(height: 44)
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < events.length;
                              index++
                            ) ...[
                              _AgendaEvent(
                                event: events[index],
                                onTap: onEventTap,
                              ),
                              if (index != events.length - 1)
                                _AgendaGap(
                                  gapStartMinutes: events[index].endMinutes,
                                  gapEndMinutes: events[index + 1].startMinutes,
                                ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgendaEvent extends StatelessWidget {
  const _AgendaEvent({required this.event, required this.onTap});

  final CalendarEvent event;
  final _OpenEventCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final start = _formatTime(context, event.startMinutes);
    final end = _formatTime(context, event.endMinutes);
    final isAllDay = _isAllDayEvent(event);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(event),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 10, 9),
        decoration: BoxDecoration(
          gradient: WeekraEventStyle.gradient(event.color),
          border: Border.all(
            color: event.color.withValues(alpha: .20),
            width: .75,
          ),
          borderRadius: BorderRadius.circular(WeekraMetrics.eventRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                isAllDay ? l10n.allDay : '$start\n$end',
                maxLines: 2,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(
                  color: _mutedInk,
                  fontSize: 11,
                  height: 1.45,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (event.location != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.location!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _mutedInk,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Separator between two events of the same overview day.
///
/// Events that run back to back keep a quiet spacing. When the day holds
/// unbooked time between them, the separator sinks below the row surface so
/// the free stretch stays visible at a glance.
class _AgendaGap extends StatelessWidget {
  const _AgendaGap({
    required this.gapStartMinutes,
    required this.gapEndMinutes,
  });

  final int gapStartMinutes;
  final int gapEndMinutes;

  @override
  Widget build(BuildContext context) {
    // A zero end minute means the event runs to midnight, so whatever follows
    // either overlaps it or starts on the next day. Neither is unbooked time.
    if (gapStartMinutes == 0 || gapEndMinutes <= gapStartMinutes) {
      return const SizedBox(height: 12);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: WeekraColors.dayGap,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

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
      _focusMinute = (event.startMinutes + event.endMinutes) ~/ 2;
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
        final seamExtent = incomingOffset.abs();
        final movesForward = _transitionDirection > 0;
        return Stack(
          fit: StackFit.expand,
          children: [
            _FlowingDateLayer(
              key: _layerKey(outgoingChild),
              horizontalOffset: outgoingOffset,
              clip: movesForward
                  ? _FlowingDateClip.leading
                  : _FlowingDateClip.trailing,
              clipExtent: seamExtent,
              interactive: false,
              child: outgoingChild,
            ),
            _FlowingDateLayer(
              key: _layerKey(_currentChild),
              horizontalOffset: incomingOffset,
              clip: movesForward
                  ? _FlowingDateClip.exceptLeading
                  : _FlowingDateClip.exceptTrailing,
              clipExtent: seamExtent,
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

enum _FlowingDateClip { full, leading, trailing, exceptLeading, exceptTrailing }

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
      _FlowingDateClip.exceptLeading => Rect.fromLTWH(
        clippedExtent,
        0,
        size.width - clippedExtent,
        size.height,
      ),
      _FlowingDateClip.exceptTrailing => Rect.fromLTWH(
        0,
        0,
        size.width - clippedExtent,
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

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({
    required this.weekStart,
    required this.suggestionEvents,
    required this.categorySettings,
    required this.onSave,
    this.existingEvent,
    this.initialStart,
    this.initialEnd,
    this.floating = false,
  }) : assert(
         (initialStart == null) == (initialEnd == null),
         'An initial time range must include both start and end.',
       );

  final DateTime weekStart;
  final List<CalendarEvent> suggestionEvents;
  final CategorySettings categorySettings;
  final _SaveEventCallback onSave;
  final CalendarEvent? existingEvent;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final bool floating;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _titleFocusNode = FocusNode(debugLabel: 'Event title');
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  bool _endsNextDay = false;
  String _selectedCategoryId = EventCategories.uncategorizedId;
  String? _suggestedCategoryId;
  bool _categoryUserSelected = false;
  bool _categoryChangedByUser = false;
  bool _moreExpanded = false;
  bool _isSaving = false;
  String? _validationMessage;
  Timer? _suggestionTimer;
  int _suggestionRevision = 0;

  @override
  void initState() {
    super.initState();
    final existingEvent = widget.existingEvent;
    if (existingEvent != null) {
      _titleController.text = existingEvent.title;
      _locationController.text = existingEvent.location ?? '';
      _selectedDate = DateTime(
        existingEvent.start.year,
        existingEvent.start.month,
        existingEvent.start.day,
      );
      _startTime = TimeOfDay.fromDateTime(existingEvent.start);
      _endTime = TimeOfDay.fromDateTime(existingEvent.end);
      _endsNextDay = !_isSameDay(existingEvent.start, existingEvent.end);
      _selectedCategoryId = existingEvent.categoryId;
      _categoryUserSelected = true;
      _moreExpanded = (existingEvent.location ?? '').isNotEmpty || _endsNextDay;
      _titleController.addListener(_titleChanged);
      return;
    }
    final initialStart = widget.initialStart;
    final initialEnd = widget.initialEnd;
    if (initialStart != null && initialEnd != null) {
      _selectedDate = DateTime(
        initialStart.year,
        initialStart.month,
        initialStart.day,
      );
      _startTime = TimeOfDay.fromDateTime(initialStart);
      _endTime = TimeOfDay.fromDateTime(initialEnd);
      _endsNextDay = !_isSameDay(initialStart, initialEnd);
      _titleController.addListener(_titleChanged);
      return;
    }
    final today = DateTime.now();
    final weekEnd = widget.weekStart.add(const Duration(days: 7));
    final isInWeek =
        !today.isBefore(widget.weekStart) && today.isBefore(weekEnd);
    _selectedDate = isInWeek ? today : widget.weekStart;
    _titleController.addListener(_titleChanged);
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _titleController.removeListener(_titleChanged);
    _titleController.dispose();
    _locationController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _titleChanged() {
    if (_categoryUserSelected) {
      return;
    }
    final revision = ++_suggestionRevision;
    _suggestionTimer?.cancel();
    _suggestionTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted ||
          revision != _suggestionRevision ||
          _categoryUserSelected) {
        return;
      }
      final existingId = widget.existingEvent?.id;
      final suggestion = suggestCategoryForTitle(
        _titleController.text,
        widget.suggestionEvents
            .where((event) => event.id != existingId)
            .map((event) => (title: event.title, categoryId: event.categoryId)),
      );
      setState(() {
        _suggestedCategoryId = suggestion;
        _selectedCategoryId = suggestion ?? EventCategories.uncategorizedId;
      });
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: widget.weekStart,
      lastDate: widget.weekStart.add(const Duration(days: 6)),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedDate = picked;
      _validationMessage = null;
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialTime = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
      _validationMessage = null;
    });
  }

  bool get _hasActiveComposition {
    final composing = _titleController.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  Future<void> _save() async {
    if (_isSaving || _hasActiveComposition) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    final start = _atTime(_selectedDate, _startTime);
    final end = _atTime(
      _selectedDate,
      _endTime,
    ).add(Duration(days: _endsNextDay ? 1 : 0));

    if (title.isEmpty) {
      setState(() => _validationMessage = l10n.eventTitleRequired);
      return;
    }
    if (!end.isAfter(start)) {
      setState(() => _validationMessage = l10n.eventEndAfterStart);
      return;
    }

    final location = _locationController.text.trim();
    final category = _resolvedCategory(
      widget.categorySettings,
      _selectedCategoryId,
    );
    final displayColor =
        category.id == EventCategories.uncategorizedId &&
            !_categoryChangedByUser
        ? widget.existingEvent?.color ?? category.color
        : category.color;
    final event = CalendarEvent(
      id:
          widget.existingEvent?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      start: start,
      end: end,
      categoryId: category.id,
      color: displayColor,
      location: location.isEmpty ? null : location,
    );
    setState(() {
      _isSaving = true;
      _validationMessage = null;
    });
    final saved = await widget.onSave(event);
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop(event);
      return;
    }
    setState(() {
      _isSaving = false;
      _validationMessage = widget.existingEvent == null
          ? l10n.eventSaveError
          : l10n.eventChangesSaveError;
    });
    _titleFocusNode.requestFocus();
  }

  void _selectCategory(String categoryId) {
    _suggestionTimer?.cancel();
    _suggestionRevision += 1;
    setState(() {
      _selectedCategoryId = categoryId;
      _suggestedCategoryId = null;
      _categoryUserSelected = true;
      _categoryChangedByUser = true;
    });
  }

  void _cancel() {
    if (!_isSaving) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final category = _resolvedCategory(
      widget.categorySettings,
      _selectedCategoryId,
    );
    final categoryName = _categoryName(
      l10n,
      widget.categorySettings,
      category.id,
    );
    final visibleCategoryName = _suggestedCategoryId == category.id
        ? l10n.suggestedCategory(categoryName)
        : categoryName;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.escape): _cancel,
      },
      child: FocusTraversalGroup(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!widget.floating)
                        Expanded(
                          child: Align(
                            child: Container(
                              width: 34,
                              height: 3,
                              decoration: BoxDecoration(
                                color: WeekraColors.outline,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      KeyedSubtree(
                        key: const Key('close-event-editor'),
                        child: WeekraIconButton(
                          key: const Key('cancel-event-editor'),
                          onPressed: _isSaving ? null : _cancel,
                          tooltip: l10n.closeTooltip,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    key: const Key('event-title'),
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    autofocus: true,
                    enabled: !_isSaving,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.25,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.titleLabel,
                      hintStyle: const TextStyle(
                        color: _tertiaryInk,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsetsDirectional.only(
                        start: 2,
                        end: 2,
                        bottom: 8,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: _line),
                  const SizedBox(height: 8),
                  _CompactDateTimeFields(
                    dateLabel: materialL10n.formatMediumDate(_selectedDate),
                    startLabel: materialL10n.formatTimeOfDay(
                      _startTime,
                      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                        context,
                      ),
                    ),
                    endLabel: materialL10n.formatTimeOfDay(
                      _endTime,
                      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                        context,
                      ),
                    ),
                    endsNextDay: _endsNextDay,
                    onDatePressed: _pickDate,
                    onStartPressed: () => _pickTime(isStart: true),
                    onEndPressed: () => _pickTime(isStart: false),
                  ),
                  const SizedBox(height: 8),
                  PopupMenuButton<String>(
                    key: const Key('event-category-menu'),
                    enabled: !_isSaving,
                    tooltip: l10n.categorySection,
                    onSelected: _selectCategory,
                    color: WeekraColors.surfaceRaised,
                    position: PopupMenuPosition.under,
                    itemBuilder: (context) => [
                      _categoryMenuItem(
                        l10n,
                        widget.categorySettings,
                        _resolvedCategory(
                          widget.categorySettings,
                          EventCategories.uncategorizedId,
                        ),
                      ),
                      for (final option in EventCategories.values)
                        _categoryMenuItem(
                          l10n,
                          widget.categorySettings,
                          _resolvedCategory(widget.categorySettings, option.id),
                        ),
                    ],
                    child: _CategoryTag(
                      color: category.color,
                      label: visibleCategoryName,
                    ),
                  ),
                  AnimatedSize(
                    duration: WeekraMotion.resolve(
                      context,
                      WeekraMotion.control,
                    ),
                    curve: WeekraMotion.standard,
                    alignment: Alignment.topCenter,
                    child: !_moreExpanded
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  key: const Key('event-location'),
                                  controller: _locationController,
                                  enabled: !_isSaving,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    hintText: l10n.locationOptionalLabel,
                                    prefixIcon: const Icon(
                                      Icons.place_outlined,
                                      size: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FilterChip(
                                  key: const Key('event-ends-next-day'),
                                  avatar: const Icon(
                                    Icons.nights_stay_outlined,
                                    size: 16,
                                  ),
                                  label: Text(l10n.endsNextDayLabel),
                                  selected: _endsNextDay,
                                  onSelected: _isSaving
                                      ? null
                                      : (selected) {
                                          setState(() {
                                            _endsNextDay = selected;
                                            _validationMessage = null;
                                          });
                                        },
                                ),
                              ],
                            ),
                          ),
                  ),
                  if (_validationMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _validationMessage!,
                      softWrap: true,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final moreButton = TextButton.icon(
                        key: const Key('event-more'),
                        onPressed: _isSaving
                            ? null
                            : () => setState(
                                () => _moreExpanded = !_moreExpanded,
                              ),
                        icon: Icon(
                          _moreExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                        ),
                        label: Text(_moreExpanded ? l10n.less : l10n.more),
                      );
                      final saveButton = FilledButton.icon(
                        key: const Key('save-event'),
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox.square(
                                dimension: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.keyboard_return_rounded,
                                size: 16,
                              ),
                        label: Text(
                          widget.existingEvent == null
                              ? l10n.saveEvent
                              : l10n.saveChanges,
                        ),
                      );
                      final stack =
                          constraints.maxWidth < 310 ||
                          MediaQuery.textScalerOf(context).scale(13) > 18;
                      if (stack) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            saveButton,
                            const SizedBox(height: 4),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: moreButton,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [moreButton, const Spacer(), saveButton],
                      );
                    },
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

class _CompactDateTimeFields extends StatelessWidget {
  const _CompactDateTimeFields({
    required this.dateLabel,
    required this.startLabel,
    required this.endLabel,
    required this.endsNextDay,
    required this.onDatePressed,
    required this.onStartPressed,
    required this.onEndPressed,
  });

  final String dateLabel;
  final String startLabel;
  final String endLabel;
  final bool endsNextDay;
  final VoidCallback onDatePressed;
  final VoidCallback onStartPressed;
  final VoidCallback onEndPressed;

  @override
  Widget build(BuildContext context) {
    Widget field({
      required Key key,
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
    }) {
      return Expanded(
        child: InkWell(
          key: key,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: _mutedInk),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: _line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackDate =
              constraints.maxWidth < 430 ||
              MediaQuery.textScalerOf(context).scale(12) > 16;
          final dateField = field(
            key: const Key('event-date'),
            icon: Icons.calendar_today_outlined,
            label: dateLabel,
            onPressed: onDatePressed,
          );
          final timeFields = Row(
            children: [
              field(
                key: const Key('event-start-time'),
                icon: Icons.schedule_rounded,
                label: startLabel,
                onPressed: onStartPressed,
              ),
              const Text('–', style: TextStyle(color: _tertiaryInk)),
              field(
                key: const Key('event-end-time'),
                icon: Icons.schedule_rounded,
                label: endsNextDay ? '$endLabel +1' : endLabel,
                onPressed: onEndPressed,
              ),
            ],
          );
          if (stackDate) {
            return Column(
              children: [
                Row(children: [dateField]),
                const Divider(height: 1, color: _subtleLine),
                timeFields,
              ],
            );
          }
          return Row(
            children: [
              dateField,
              Container(width: 1, height: 24, color: _subtleLine),
              Expanded(flex: 2, child: timeFields),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 9, 8, 9),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _mutedInk,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.expand_more_rounded,
              size: 17,
              color: _tertiaryInk,
            ),
          ],
        ),
      ),
    );
  }
}

PopupMenuItem<String> _categoryMenuItem(
  AppLocalizations l10n,
  CategorySettings categorySettings,
  EventCategory category,
) {
  return PopupMenuItem<String>(
    key: Key('event-category-${category.id}'),
    value: category.id,
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: category.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(_categoryName(l10n, categorySettings, category.id)),
      ],
    ),
  );
}

enum _EventAction { edit, delete }

enum _EventContextAction { edit, copy, delete, category }

class _EventContextSelection {
  const _EventContextSelection(this.action, {this.categoryId});

  final _EventContextAction action;
  final String? categoryId;
}

Future<_EventContextSelection?> _showEventContextMenu(
  BuildContext context,
  CalendarEvent event, {
  required Offset position,
  required CategorySettings categorySettings,
}) {
  final l10n = AppLocalizations.of(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final localPosition = overlay.globalToLocal(position);
  final menuPosition = RelativeRect.fromLTRB(
    localPosition.dx,
    localPosition.dy,
    overlay.size.width - localPosition.dx,
    overlay.size.height - localPosition.dy,
  );

  PopupMenuItem<_EventContextSelection> actionItem({
    required Key key,
    required _EventContextAction action,
    required IconData icon,
    required String label,
    Color? color,
  }) {
    return PopupMenuItem<_EventContextSelection>(
      key: key,
      value: _EventContextSelection(action),
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? _mutedInk),
          const SizedBox(width: 11),
          Text(label, style: TextStyle(color: color ?? _ink, fontSize: 13)),
        ],
      ),
    );
  }

  PopupMenuItem<_EventContextSelection> categoryItem(EventCategory category) {
    final selected = event.categoryId == category.id;
    return PopupMenuItem<_EventContextSelection>(
      key: Key('event-context-category-${category.id}'),
      value: _EventContextSelection(
        _EventContextAction.category,
        categoryId: category.id,
      ),
      height: 38,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              _categoryName(l10n, categorySettings, category.id),
              style: const TextStyle(color: _ink, fontSize: 13),
            ),
          ),
          if (selected)
            Icon(
              Icons.check_rounded,
              size: 17,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }

  return showMenu<_EventContextSelection>(
    context: context,
    position: menuPosition,
    color: WeekraColors.surfaceRaised.withValues(alpha: .98),
    surfaceTintColor: Colors.transparent,
    elevation: 14,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: WeekraColors.outline),
    ),
    constraints: const BoxConstraints(minWidth: 210, maxWidth: 250),
    items: [
      actionItem(
        key: const Key('event-context-edit'),
        action: _EventContextAction.edit,
        icon: Icons.edit_outlined,
        label: l10n.edit,
      ),
      actionItem(
        key: const Key('event-context-copy'),
        action: _EventContextAction.copy,
        icon: Icons.content_copy_rounded,
        label: l10n.copy,
      ),
      actionItem(
        key: const Key('event-context-delete'),
        action: _EventContextAction.delete,
        icon: Icons.delete_outline_rounded,
        label: l10n.delete,
        color: Theme.of(context).colorScheme.error,
      ),
      const PopupMenuDivider(height: 9),
      PopupMenuItem<_EventContextSelection>(
        key: const Key('event-context-category-heading'),
        enabled: false,
        height: 30,
        child: Text(
          l10n.categorySection,
          style: const TextStyle(
            color: _tertiaryInk,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      categoryItem(
        _resolvedCategory(categorySettings, EventCategories.uncategorizedId),
      ),
      for (final category in EventCategories.values)
        categoryItem(_resolvedCategory(categorySettings, category.id)),
    ],
  );
}

class _EventDetailsSheet extends StatelessWidget {
  const _EventDetailsSheet({required this.event, this.floating = false});

  final CalendarEvent event;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!floating) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _mutedInk,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 52,
                  decoration: BoxDecoration(
                    color: event.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    event.title,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                WeekraIconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: l10n.closeTooltip,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _EventDetailRow(
              icon: Icons.calendar_today_outlined,
              text: MaterialLocalizations.of(context)
                  .formatFullDate(event.start),
            ),
            const SizedBox(height: 12),
            _EventDetailRow(
              icon: Icons.schedule_rounded,
              text:
                  '${_formatTime(context, event.startMinutes)} – '
                  '${_formatTime(context, event.endMinutes)}',
            ),
            if (event.location != null) ...[
              const SizedBox(height: 12),
              _EventDetailRow(
                icon: Icons.location_on_outlined,
                text: event.location!,
              ),
            ],
            const SizedBox(height: 26),
            _EventActionButtons(
              onEdit: () => Navigator.of(context).pop(_EventAction.edit),
              onDelete: () => Navigator.of(context).pop(_EventAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDetailRow extends StatelessWidget {
  const _EventDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _mutedInk),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: const TextStyle(color: _ink, fontSize: 14, height: 1.3),
          ),
        ),
      ],
    );
  }
}

class _EventActionButtons extends StatelessWidget {
  const _EventActionButtons({required this.onEdit, required this.onDelete});

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget editButton() => FilledButton.icon(
      key: const Key('edit-event'),
      onPressed: onEdit,
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: Text(
        l10n.edit,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );

    Widget deleteButton() => OutlinedButton.icon(
      key: const Key('delete-event'),
      onPressed: onDelete,
      icon: const Icon(Icons.delete_outline_rounded, size: 18),
      label: Text(
        l10n.delete,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledBody = MediaQuery.textScalerOf(context).scale(16);
        final shouldStack = constraints.maxWidth < 330 || scaledBody > 21;
        if (shouldStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              editButton(),
              const SizedBox(height: 10),
              deleteButton(),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: editButton()),
            const SizedBox(width: 10),
            Expanded(child: deleteButton()),
          ],
        );
      },
    );
  }
}

class _FloatingCardSurface extends StatelessWidget {
  const _FloatingCardSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => GlassSurface(
    // Dialog-sized blur should stay composited instead of rebuilding for every
    // mouse move while the user is typing or choosing a time.
    responsive: false,
    child: child,
  );
}

class _AnchoredCardLayout extends StatelessWidget {
  const _AnchoredCardLayout({
    required this.anchorRect,
    required this.maxWidth,
    required this.maxHeight,
    required this.child,
  });

  final Rect anchorRect;
  final double maxWidth;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const margin = 16.0;
          const gap = 12.0;
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          final usableHeight = math.max(
            0.0,
            constraints.maxHeight - bottomInset,
          );
          final width = math.min(maxWidth, constraints.maxWidth - margin * 2);
          final height = math.min(maxHeight, usableHeight - margin * 2);
          final canFitRight =
              constraints.maxWidth - anchorRect.right - margin >= width + gap;
          final canFitLeft = anchorRect.left - margin >= width + gap;
          final left = canFitRight
              ? anchorRect.right + gap
              : canFitLeft
              ? anchorRect.left - width - gap
              : (anchorRect.center.dx - width / 2).clamp(
                  margin,
                  constraints.maxWidth - width - margin,
                );
          final roomBelow = usableHeight - anchorRect.bottom - margin;
          final roomAbove = anchorRect.top - margin;
          final top = !canFitRight && !canFitLeft && roomBelow >= height + gap
              ? anchorRect.bottom + gap
              : !canFitRight && !canFitLeft && roomAbove >= height + gap
              ? anchorRect.top - height - gap
              : (anchorRect.center.dy - height / 2).clamp(
                  margin,
                  math.max(margin, usableHeight - height - margin),
                );
          return Stack(
            children: [
              Positioned(
                left: left.toDouble(),
                top: top.toDouble(),
                width: width,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: height),
                  child: _FloatingCardSurface(child: child),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<_EventAction?> _showEventDetailsSheet(
  BuildContext context,
  CalendarEvent event, {
  Rect? anchorRect,
}) {
  if (_canUseAnchoredCard(context, anchorRect)) {
    return _showAnchoredCard<_EventAction>(
      context,
      anchorRect: anchorRect!,
      maxWidth: 420,
      maxHeight: 500,
      builder: (context) => _EventDetailsSheet(event: event, floating: true),
    );
  }
  return showModalBottomSheet<_EventAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WeekraColors.surface,
    showDragHandle: false,
    builder: (context) => _EventDetailsSheet(event: event),
  );
}

Future<bool> _confirmDelete(BuildContext context, CalendarEvent event) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        l10n.deleteEventTitle,
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
      content: Text(
        l10n.deleteEventMessage(event.title),
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            l10n.cancel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        FilledButton(
          key: const Key('confirm-delete-event'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            l10n.delete,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<CalendarEvent?> _showEventEditorSheet(
  BuildContext context,
  DateTime weekStart, {
  required List<CalendarEvent> suggestionEvents,
  required CategorySettings categorySettings,
  required _SaveEventCallback onSave,
  CalendarEvent? existingEvent,
  DateTime? initialStart,
  DateTime? initialEnd,
  Rect? anchorRect,
}) {
  if (_canUseAnchoredCard(context, anchorRect)) {
    return _showAnchoredCard<CalendarEvent>(
      context,
      anchorRect: anchorRect!,
      maxWidth: 400,
      maxHeight: 560,
      builder: (context) => _EventEditorSheet(
        weekStart: weekStart,
        suggestionEvents: suggestionEvents,
        categorySettings: categorySettings,
        onSave: onSave,
        existingEvent: existingEvent,
        initialStart: initialStart,
        initialEnd: initialEnd,
        floating: true,
      ),
    );
  }
  return showGlassDialog<CalendarEvent>(
    context,
    maxWidth: 400,
    maxHeight: 560,
    builder: (context) => _EventEditorSheet(
      weekStart: weekStart,
      suggestionEvents: suggestionEvents,
      categorySettings: categorySettings,
      onSave: onSave,
      existingEvent: existingEvent,
      initialStart: initialStart,
      initialEnd: initialEnd,
      floating: true,
    ),
  );
}

Future<T?> _showAnchoredCard<T>(
  BuildContext context, {
  required Rect anchorRect,
  required double maxWidth,
  required double maxHeight,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x2E000000),
    transitionDuration: WeekraMotion.resolve(context, WeekraMotion.panel),
    pageBuilder: (dialogContext, _, _) => _AnchoredCardLayout(
      anchorRect: anchorRect,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      child: builder(dialogContext),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: WeekraMotion.emphasized,
        reverseCurve: WeekraMotion.standard,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

bool _canUseAnchoredCard(BuildContext context, Rect? anchorRect) {
  return anchorRect != null &&
      MediaQuery.sizeOf(context).width >= 700 &&
      _usesDesktopPointerRules(context);
}

bool _usesDesktopPointerRules(BuildContext context) {
  return switch (Theme.of(context).platform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };
}

Rect? _globalRectFor(BuildContext? context) {
  final renderObject = context?.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

DateTime _atTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

DateTime _dateAtMinute(DateTime date, int minute) {
  return DateTime(
    date.year,
    date.month,
    date.day,
  ).add(Duration(minutes: minute));
}

int _snapMinutes(num minutes) {
  return (minutes / _gridSnapMinutes).round() * _gridSnapMinutes;
}

int _hourStartForMinute(num minutes) {
  return (minutes / Duration.minutesPerHour).floor() * Duration.minutesPerHour;
}

CalendarEvent _copyEvent(
  CalendarEvent event, {
  DateTime? start,
  DateTime? end,
}) {
  return CalendarEvent(
    id: event.id,
    title: event.title,
    start: start ?? event.start,
    end: end ?? event.end,
    color: event.color,
    categoryId: event.categoryId,
    location: event.location,
  );
}

String _categoryName(
  AppLocalizations l10n,
  CategorySettings categorySettings,
  String categoryId,
) {
  final fallback = switch (categoryId) {
    'category-1' => l10n.categoryOne,
    'category-2' => l10n.categoryTwo,
    'category-3' => l10n.categoryThree,
    'category-4' => l10n.categoryFour,
    'category-5' => l10n.categoryFive,
    'category-6' => l10n.categorySix,
    _ => l10n.uncategorized,
  };
  return categorySettings.nameFor(categoryId, fallback);
}

EventCategory _resolvedCategory(
  CategorySettings categorySettings,
  String categoryId,
) {
  final fallback =
      EventCategories.byId(categoryId) ?? EventCategories.uncategorized;
  return EventCategory(
    id: fallback.id,
    color: categorySettings.colorFor(fallback.id, fallback.color),
  );
}

CalendarEvent _eventWithResolvedCategory(
  CalendarEvent event,
  CategorySettings categorySettings,
) {
  final category = _resolvedCategory(categorySettings, event.categoryId);
  final color = category.id == EventCategories.uncategorizedId
      ? event.color
      : category.color;
  if (color.toARGB32() == event.color.toARGB32()) {
    return event;
  }
  return CalendarEvent(
    id: event.id,
    title: event.title,
    start: event.start,
    end: event.end,
    color: color,
    categoryId: event.categoryId,
    location: event.location,
  );
}

DateTime _timelineStart(DateTime date, CalendarViewSettings settings) {
  final day = DateTime(date.year, date.month, date.day);
  if (settings.anchorMode == CalendarAnchorMode.today) {
    return day.subtract(Duration(days: settings.todayColumn));
  }
  final daysSinceStart = (day.weekday - settings.weekStartsOn) % 7;
  return day.subtract(Duration(days: daysSinceStart));
}

bool _sameCalendarSettings(
  CalendarViewSettings first,
  CalendarViewSettings second,
) {
  return first.anchorMode == second.anchorMode &&
      first.todayColumn == second.todayColumn &&
      first.weekStartsOn == second.weekStartsOn;
}

int _dateKey(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isAllDayEvent(CalendarEvent event) {
  return event.start.hour == 0 &&
      event.start.minute == 0 &&
      event.durationMinutes >= 23 * 60;
}

bool _eventOccursOnDay(CalendarEvent event, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  return event.start.isBefore(dayEnd) && event.end.isAfter(dayStart);
}

Iterable<CalendarEvent> _timedEventSegments(
  CalendarEvent event,
  DateTime weekStart,
) sync* {
  final visibleStart = event.start.isAfter(weekStart) ? event.start : weekStart;
  final weekEnd = weekStart.add(const Duration(days: 7));
  final visibleEnd = event.end.isBefore(weekEnd) ? event.end : weekEnd;
  if (!visibleEnd.isAfter(visibleStart)) {
    return;
  }

  var dayStart = DateTime(
    visibleStart.year,
    visibleStart.month,
    visibleStart.day,
  );
  while (dayStart.isBefore(visibleEnd)) {
    final dayEnd = dayStart.add(const Duration(days: 1));
    final segmentStart = event.start.isAfter(dayStart) ? event.start : dayStart;
    final segmentEnd = event.end.isBefore(dayEnd) ? event.end : dayEnd;
    if (segmentEnd.isAfter(segmentStart)) {
      yield _copyEvent(event, start: segmentStart, end: segmentEnd);
    }
    dayStart = dayEnd;
  }
}

class _EventPlacement {
  const _EventPlacement({
    required this.event,
    required this.lane,
    required this.laneCount,
  });

  final CalendarEvent event;
  final int lane;
  final int laneCount;
}

class _LaneAssignment {
  const _LaneAssignment(this.event, this.lane);

  final CalendarEvent event;
  final int lane;
}

List<_EventPlacement> _eventPlacements(Iterable<CalendarEvent> source) {
  final byDay = <int, List<CalendarEvent>>{};
  for (final event in source) {
    final dayKey =
        event.start.year * 10000 + event.start.month * 100 + event.start.day;
    byDay.putIfAbsent(dayKey, () => []).add(event);
  }

  final placements = <_EventPlacement>[];
  for (final dayEvents in byDay.values) {
    dayEvents.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final group = <CalendarEvent>[];
    var groupEnd = -1;

    void placeGroup() {
      if (group.isEmpty) return;
      final laneEnds = <int>[];
      final assignments = <_LaneAssignment>[];
      for (final event in group) {
        final eventEnd = _eventEndMinuteForLayout(event);
        var lane = laneEnds.indexWhere((end) => end <= event.startMinutes);
        if (lane == -1) {
          lane = laneEnds.length;
          laneEnds.add(eventEnd);
        } else {
          laneEnds[lane] = eventEnd;
        }
        assignments.add(_LaneAssignment(event, lane));
      }
      for (final assignment in assignments) {
        placements.add(
          _EventPlacement(
            event: assignment.event,
            lane: assignment.lane,
            laneCount: laneEnds.length,
          ),
        );
      }
      group.clear();
    }

    for (final event in dayEvents) {
      if (group.isNotEmpty && event.startMinutes >= groupEnd) {
        placeGroup();
        groupEnd = -1;
      }
      group.add(event);
      groupEnd = math.max(groupEnd, _eventEndMinuteForLayout(event));
    }
    placeGroup();
  }
  return placements;
}

int _eventEndMinuteForLayout(CalendarEvent event) {
  return _isSameDay(event.start, event.end) ? event.endMinutes : 24 * 60;
}

String _formatTime(BuildContext context, int minutes) {
  if (minutes == 24 * 60) return '24:00';
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

double _timeGutterWidth(BuildContext context, int startHour, int endHour) {
  const style = TextStyle(
    fontSize: 10,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  final textDirection = Directionality.of(context);
  final textScaler = MediaQuery.textScalerOf(context);
  var widest = 0.0;
  for (var hour = startHour; hour <= endHour; hour++) {
    final painter = TextPainter(
      text: TextSpan(text: _formatTime(context, hour * 60), style: style),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  return widest + 16;
}

double _singleLineTextWidth(
  BuildContext context,
  String text,
  TextStyle style,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

String _weekLabel(MaterialLocalizations localizations, DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  if (weekStart.month == weekEnd.month) {
    return localizations.formatMonthYear(weekStart);
  }
  return '${localizations.formatMonthYear(weekStart)} / '
      '${localizations.formatMonthYear(weekEnd)}';
}

String _weekdayShortName(AppLocalizations l10n, int weekday) {
  return switch (weekday) {
    DateTime.monday => l10n.weekdayShortMonday,
    DateTime.tuesday => l10n.weekdayShortTuesday,
    DateTime.wednesday => l10n.weekdayShortWednesday,
    DateTime.thursday => l10n.weekdayShortThursday,
    DateTime.friday => l10n.weekdayShortFriday,
    DateTime.saturday => l10n.weekdayShortSaturday,
    DateTime.sunday => l10n.weekdayShortSunday,
    _ => throw ArgumentError.value(weekday, 'weekday'),
  };
}
