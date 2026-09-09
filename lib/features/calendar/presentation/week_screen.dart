import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:weekra/app/weekra_design.dart';
import 'package:weekra/app/weekra_theme.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';
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

typedef _CreateEventCallback = void Function({
  required DateTime start,
  required DateTime end,
});

class WeekScreen extends StatefulWidget {
  const WeekScreen({
    super.key,
    required this.eventStore,
    this.theme = WeekraTheme.ember,
    this.onOpenSettings,
    this.clock,
  });

  final CalendarEventStore eventStore;
  final WeekraTheme theme;
  final VoidCallback? onOpenSettings;
  final DateTime Function()? clock;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}
class _WeekScreenState extends State<WeekScreen> {
  late DateTime _weekStart;
  _WeekLayout _layout = _WeekLayout.grid;
  List<CalendarEvent> _events = [];
  bool _isLoading = true;
  bool _didStartLoading = false;
  bool _didChooseInitialLayout = false;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(_now());
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

  Future<void> _createEvent({DateTime? initialStart, DateTime? initialEnd}) async {
    final l10n = AppLocalizations.of(context);
    final event = await _showEventEditorSheet(
      context,
      _weekStart,
      initialStart: initialStart,
      initialEnd: initialEnd,
    );
    if (event == null || !mounted) {
      return;
    }

    final updatedEvents = [..._events, event]
      ..sort((a, b) => a.start.compareTo(b.start));
    await _persistMutation(
      updatedEvents,
      failureMessage: l10n.eventSaveError,
    );
  }

  Future<void> _changeEventFromGrid(CalendarEvent changedEvent) async {
    final l10n = AppLocalizations.of(context);
    final updatedEvents = _events
        .map((event) => event.id == changedEvent.id ? changedEvent : event)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    await _persistMutation(
      updatedEvents,
      failureMessage: l10n.eventChangesSaveError,
    );
  }

  Future<void> _openEvent(CalendarEvent event) async {
    final l10n = AppLocalizations.of(context);
    final action = await _showEventDetailsSheet(context, event);
    if (action == null || !mounted) {
      return;
    }

    if (action == _EventAction.edit) {
      final updatedEvent = await _showEventEditorSheet(
        context,
        _weekStart,
        existingEvent: event,
      );
      if (updatedEvent == null || !mounted) {
        return;
      }
      final updatedEvents = _events
          .map((item) => item.id == event.id ? updatedEvent : item)
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
      await _persistMutation(
        updatedEvents,
        failureMessage: l10n.eventChangesSaveError,
      );
      return;
    }

    final shouldDelete = await _confirmDelete(context, event);
    if (!shouldDelete || !mounted) {
      return;
    }
    await _persistMutation(
      _events.where((item) => item.id != event.id).toList(),
      failureMessage: l10n.eventDeleteError,
    );
  }

  Future<void> _persistMutation(
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
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _events = previousEvents;
        _storageError = failureMessage;
      });
    }
  }

  void _moveWeek(int offset) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: offset * 7));
    });
  }

  void _returnToToday() {
    setState(() {
      _weekStart = _startOfWeek(_now());
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
    final l10n = AppLocalizations.of(context);
    final now = _now();
    final days = List.generate(
      7,
      (index) => _weekStart.add(Duration(days: index)),
    );
    final events = _events.where((event) {
      final dayIndex = event.dayIndexIn(_weekStart);
      return dayIndex >= 0 && dayIndex < 7;
    }).toList();

    return Scaffold(
      backgroundColor: WeekraColors.canvas,
      body: SafeArea(
          child: Column(
            children: [
              _WeekToolbar(
                weekStart: _weekStart,
                layout: _layout,
                onPrevious: () => _moveWeek(-1),
                onNext: () => _moveWeek(1),
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
                        onHorizontalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity.abs() < 350) {
                            return;
                          }
                          _moveWeek(velocity < 0 ? 1 : -1);
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: KeyedSubtree(
                            key: ValueKey((_weekStart, _layout)),
                            child: _layout == _WeekLayout.hourly
                                ? _WeekHourlyLayout(
                                    days: days,
                                    events: events,
                                    now: now,
                                    onEventTap: _openEvent,
                                    onCreateEvent: ({
                                      required start,
                                      required end,
                                    }) => _createEvent(
                                      initialStart: start,
                                      initialEnd: end,
                                    ),
                                    onEventChanged: _changeEventFromGrid,
                                  )
                                : _WeekGridSummary(
                                    days: days,
                                    events: events,
                                    today: now,
                                    onEventTap: _openEvent,
                                  ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _isLoading ? null : () => _createEvent(),
        tooltip: l10n.newEventTooltip,
        child: const Icon(Icons.add_rounded, size: 24),
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
      content: Text(
        message,
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
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
            fontSize: 10,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.45,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _weekLabel(materialL10n, weekStart),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 23,
            height: 1.1,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.55,
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
            compact: todayLabelWidth >
                (constraints.maxWidth < 420 ? 76 : 120),
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
                child: IconButton(
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
          IconButton(
            onPressed: onPrevious,
            tooltip: l10n.previousWeekTooltip,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
          ),
          if (compact)
            IconButton(
              onPressed: onToday,
              tooltip: l10n.today,
              color: accent,
              icon: const Icon(Icons.today_outlined, size: 18),
            )
          else
            TextButton(
              onPressed: onToday,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(
                l10n.today,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          IconButton(
            onPressed: onNext,
            tooltip: l10n.nextWeekTooltip,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ToolbarSurface extends StatelessWidget {
  const _ToolbarSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: WeekraMetrics.controlHeight,
      decoration: BoxDecoration(
        color: WeekraColors.surface,
        borderRadius: BorderRadius.circular(WeekraMetrics.controlRadius),
        border: Border.all(color: _subtleLine),
      ),
      child: child,
    );
  }
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
    return Semantics(
      container: true,
      label: l10n.weekLayoutPickerLabel,
      child: _ToolbarSurface(
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}

class _WeekLayoutOption extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final contentColor = selected ? accent : _mutedInk;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: WeekraMetrics.controlHeight - 4,
            constraints: BoxConstraints(minWidth: label == null ? 40 : 78),
            margin: const EdgeInsets.all(2),
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: label == null ? 9 : 10,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: contentColor),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: contentColor,
                        fontSize: 12,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekGridSummary extends StatelessWidget {
  const _WeekGridSummary({
    required this.days,
    required this.events,
    required this.today,
    required this.onEventTap,
  });

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final DateTime today;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('week-grid-layout'),
      padding: const EdgeInsetsDirectional.fromSTEB(18, 4, 18, 92),
      itemCount: days.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: _line),
      itemBuilder: (context, dayIndex) {
        final day = days[dayIndex];
        final dayEvents = events
            .where((event) => event.dayIndexIn(days.first) == dayIndex)
            .toList()
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
        return _AgendaDay(
          day: day,
          events: dayEvents,
          isToday: _isSameDay(day, today),
          onEventTap: onEventTap,
        );
      },
    );
  }
}

class _AgendaDay extends StatelessWidget {
  const _AgendaDay({
    required this.day,
    required this.events,
    required this.isToday,
    required this.onEventTap,
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final bool isToday;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isToday ? accent.withValues(alpha: 0.035) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              flex: 2,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _weekdayName(l10n, day.weekday),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isToday ? accent : _mutedInk,
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      padding: const EdgeInsets.all(5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isToday ? accent : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          color: isToday ? WeekraColors.onAccent : _ink,
                          fontSize: 21,
                          height: 1.1,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 5,
              child: events.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Text(
                        l10n.openDay,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(
                          color: _mutedInk,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (var index = 0; index < events.length; index++) ...[
                          _AgendaEvent(
                            event: events[index],
                            onTap: onEventTap,
                          ),
                          if (index != events.length - 1)
                            const SizedBox(height: 12),
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

class _AgendaEvent extends StatelessWidget {
  const _AgendaEvent({required this.event, required this.onTap});

  final CalendarEvent event;
  final ValueChanged<CalendarEvent> onTap;

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
        padding: const EdgeInsetsDirectional.only(start: 11),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: event.color, width: 3),
          ),
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

class _WeekHourlyLayout extends StatefulWidget {
  const _WeekHourlyLayout({
    required this.days,
    required this.events,
    required this.now,
    required this.onEventTap,
    required this.onCreateEvent,
    required this.onEventChanged,
  });

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final DateTime now;
  final ValueChanged<CalendarEvent> onEventTap;
  final _CreateEventCallback onCreateEvent;
  final ValueChanged<CalendarEvent> onEventChanged;

  @override
  State<_WeekHourlyLayout> createState() => _WeekHourlyLayoutState();
}

class _WeekHourlyLayoutState extends State<_WeekHourlyLayout> {
  final _gridKey = GlobalKey();
  CalendarEvent? _draftEvent;
  CalendarEvent? _movingEvent;
  CalendarEvent? _resizeOrigin;
  CalendarEvent? _resizingEvent;
  String? _selectedEventId;
  _ResizeEdge? _resizeEdge;
  double _resizeDy = 0;
  int? _lastFeedbackStep;
  int? _createAnchorDayIndex;
  int? _createAnchorMinute;

  @override
  void didUpdateWidget(covariant _WeekHourlyLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedEventId != null &&
        !widget.events.any((event) => event.id == _selectedEventId)) {
      _selectedEventId = null;
    }
  }

  Offset? _gridPosition(Offset globalPosition) {
    final renderObject = _gridKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.globalToLocal(globalPosition);
  }

  void _selectNewSlot(
    Offset globalPosition, {
    required double gutterWidth,
    required double columnWidth,
    required int startHour,
    required int endHour,
    required double hourHeight,
  }) {
    final position = _gridPosition(globalPosition);
    if (position == null || position.dx < gutterWidth) {
      setState(() {
        _draftEvent = null;
        _selectedEventId = null;
      });
      return;
    }

    final dayIndex = ((position.dx - gutterWidth) / columnWidth)
        .floor()
        .clamp(0, widget.days.length - 1)
        .toInt();
    final firstMinute = startHour * 60;
    final lastMinute = math.min(
      endHour * 60,
      24 * 60 - _gridSnapMinutes,
    );
    final lastStartMinute = math.min(
      lastMinute - _defaultEventMinutes,
      24 * 60 - _gridSnapMinutes - _defaultEventMinutes,
    );
    final minute = _snapMinutes(
      firstMinute + position.dy / hourHeight * 60,
    ).clamp(firstMinute, lastStartMinute).toInt();
    final day = widget.days[dayIndex];
    final start = _dateAtMinute(day, minute);

    setState(() {
      _selectedEventId = null;
      _draftEvent = CalendarEvent(
        id: '_draft',
        title: '',
        start: start,
        end: start.add(const Duration(minutes: _defaultEventMinutes)),
        color: Theme.of(context).colorScheme.primary,
      );
    });
    HapticFeedback.selectionClick();
  }

  void _startCreating(
    Offset globalPosition, {
    required double gutterWidth,
    required double columnWidth,
    required int startHour,
    required int endHour,
    required double hourHeight,
  }) {
    _selectNewSlot(
      globalPosition,
      gutterWidth: gutterWidth,
      columnWidth: columnWidth,
      startHour: startHour,
      endHour: endHour,
      hourHeight: hourHeight,
    );
    final draft = _draftEvent;
    if (draft == null) {
      return;
    }
    _createAnchorDayIndex = draft.dayIndexIn(widget.days.first);
    _createAnchorMinute = draft.startMinutes;
    _lastFeedbackStep = draft.startMinutes;
  }

  void _updateCreating(
    Offset globalPosition, {
    required int startHour,
    required int endHour,
    required double hourHeight,
  }) {
    final dayIndex = _createAnchorDayIndex;
    final anchor = _createAnchorMinute;
    final position = _gridPosition(globalPosition);
    if (dayIndex == null || anchor == null || position == null) {
      return;
    }
    final firstMinute = startHour * 60;
    final lastMinute = math.min(
      endHour * 60,
      24 * 60 - _gridSnapMinutes,
    );
    final current = _snapMinutes(
      firstMinute + position.dy / hourHeight * 60,
    ).clamp(firstMinute, lastMinute).toInt();
    final startMinute = math.min(anchor, current);
    final endMinute = math.max(
      math.max(anchor, current),
      startMinute + _minimumEventMinutes,
    ).clamp(firstMinute + _minimumEventMinutes, lastMinute).toInt();
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
  }

  void _confirmDraft() {
    final draft = _draftEvent;
    if (draft == null) {
      return;
    }
    setState(() => _draftEvent = null);
    widget.onCreateEvent(start: draft.start, end: draft.end);
  }

  void _selectEvent(CalendarEvent event) {
    if (_selectedEventId == event.id) {
      widget.onEventTap(event);
      return;
    }
    setState(() {
      _draftEvent = null;
      _selectedEventId = event.id;
    });
    HapticFeedback.selectionClick();
  }

  void _startMoving(CalendarEvent event) {
    setState(() {
      _draftEvent = null;
      _selectedEventId = event.id;
      _movingEvent = event;
      _resizingEvent = null;
      _resizeOrigin = null;
      _resizeEdge = null;
      _lastFeedbackStep = null;
    });
    HapticFeedback.mediumImpact();
  }

  void _updateMoving(
    LongPressMoveUpdateDetails details, {
    required double gutterWidth,
    required double columnWidth,
    required int startHour,
    required int endHour,
    required double hourHeight,
  }) {
    final moving = _movingEvent;
    final position = _gridPosition(details.globalPosition);
    if (moving == null || position == null) {
      return;
    }

    final dayIndex = ((position.dx - gutterWidth) / columnWidth)
        .floor()
        .clamp(0, widget.days.length - 1)
        .toInt();
    final firstMinute = startHour * 60;
    final lastMinute = math.min(
      endHour * 60,
      24 * 60 - _gridSnapMinutes,
    );
    final duration = math.min(
      math.max(_minimumEventMinutes, moving.durationMinutes),
      lastMinute - firstMinute,
    );
    final maxStart = math.max(firstMinute, lastMinute - duration);
    final minute = _snapMinutes(
      firstMinute + position.dy / hourHeight * 60 - duration / 2,
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
    });
  }

  void _startResizing(CalendarEvent event, _ResizeEdge edge) {
    setState(() {
      _draftEvent = null;
      _selectedEventId = event.id;
      _movingEvent = null;
      _resizeOrigin = event;
      _resizingEvent = event;
      _resizeEdge = edge;
      _resizeDy = 0;
      _lastFeedbackStep = null;
    });
    HapticFeedback.selectionClick();
  }

  void _updateResizing(
    DragUpdateDetails details, {
    required int startHour,
    required int endHour,
    required double hourHeight,
  }) {
    final origin = _resizeOrigin;
    final edge = _resizeEdge;
    if (origin == null || edge == null) {
      return;
    }
    _resizeDy += details.primaryDelta ?? 0;
    final delta = _snapMinutes(_resizeDy / hourHeight * 60);
    final day = DateTime(origin.start.year, origin.start.month, origin.start.day);
    final firstMinute = startHour * 60;
    final lastMinute = math.min(
      endHour * 60,
      24 * 60 - _gridSnapMinutes,
    );
    late final CalendarEvent resized;
    late final int feedbackStep;

    if (edge == _ResizeEdge.start) {
      final latestStart = origin.endMinutes - _minimumEventMinutes;
      final minute = (origin.startMinutes + delta).clamp(
        firstMinute,
        latestStart,
      ).toInt();
      feedbackStep = minute;
      resized = _copyEvent(origin, start: _dateAtMinute(day, minute));
    } else {
      final earliestEnd = origin.startMinutes + _minimumEventMinutes;
      final minute = (origin.endMinutes + delta).clamp(
        earliestEnd,
        lastMinute,
      ).toInt();
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
      _resizeDy = 0;
      _lastFeedbackStep = null;
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
      _resizeDy = 0;
      _lastFeedbackStep = null;
    });
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final allDayEvents =
            widget.events.where(_isAllDayEvent).toList(growable: false);
        final timedEvents = widget.events
            .where((event) => !_isAllDayEvent(event))
            .toList(growable: false);
        final displayedTimedEvents =
            timedEvents.map(_displayEvent).toList(growable: false);
        final visibleRange = _visibleHourRange(displayedTimedEvents);
        final startHour = visibleRange.$1;
        final endHour = visibleRange.$2;
        final hourHeight = narrow ? 54.0 : 64.0;
        final gutterWidth = _timeGutterWidth(context, startHour, endHour);
        final columnWidth = (constraints.maxWidth - gutterWidth) / 7;
        final gridHeight = (endHour - startHour) * hourHeight;
        final todayIndex = widget.days.indexWhere(
          (day) => _isSameDay(day, widget.now),
        );

        return Column(
          key: const Key('week-hourly-layout'),
          children: [
            SizedBox(
              height: narrow ? 58 : 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: gutterWidth),
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
            if (allDayEvents.isNotEmpty) ...[
              const Divider(height: 1, color: _subtleLine),
              _AllDayBand(
                days: widget.days,
                events: allDayEvents,
                today: widget.now,
                gutterWidth: gutterWidth,
                onEventTap: widget.onEventTap,
              ),
            ],
            const Divider(height: 1, color: _line),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.only(bottom: 92),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: gridHeight,
                  child: KeyedSubtree(
                    key: const Key('week-hourly-grid'),
                    child: GestureDetector(
                      key: _gridKey,
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _selectNewSlot(
                        details.globalPosition,
                        gutterWidth: gutterWidth,
                        columnWidth: columnWidth,
                        startHour: startHour,
                        endHour: endHour,
                        hourHeight: hourHeight,
                      ),
                      onLongPressStart: (details) => _startCreating(
                        details.globalPosition,
                        gutterWidth: gutterWidth,
                        columnWidth: columnWidth,
                        startHour: startHour,
                        endHour: endHour,
                        hourHeight: hourHeight,
                      ),
                      onLongPressMoveUpdate: (details) => _updateCreating(
                        details.globalPosition,
                        startHour: startHour,
                        endHour: endHour,
                        hourHeight: hourHeight,
                      ),
                      onLongPressEnd: (_) => _finishCreating(),
                      onLongPressCancel: _finishCreating,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (todayIndex >= 0)
                            PositionedDirectional(
                              start: gutterWidth + todayIndex * columnWidth,
                              top: 0,
                              bottom: 0,
                              width: columnWidth,
                              child: ColoredBox(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.035),
                              ),
                            ),
                          for (var hour = startHour;
                              hour <= endHour;
                              hour++)
                            _HourRule(
                              top: (hour - startHour) * hourHeight,
                              gutterWidth: gutterWidth,
                              label: _formatTime(context, hour * 60),
                            ),
                          for (var index = 1; index < 7; index++)
                            PositionedDirectional(
                              start: gutterWidth + columnWidth * index,
                              top: 0,
                              bottom: 0,
                              child: const VerticalDivider(
                                width: 1,
                                color: _subtleLine,
                              ),
                            ),
                          for (final placement
                              in _eventPlacements(displayedTimedEvents))
                            Builder(
                              builder: (context) {
                                final displayedEvent = placement.event;
                                final originalEvent = widget.events.firstWhere(
                                  (event) => event.id == displayedEvent.id,
                                );
                                return _GridEvent(
                                  event: displayedEvent,
                                  dayIndex: displayedEvent.dayIndexIn(
                                    widget.days.first,
                                  ),
                                  lane: placement.lane,
                                  laneCount: placement.laneCount,
                                  columnWidth: columnWidth,
                                  gutterWidth: gutterWidth,
                                  startHour: startHour,
                                  hourHeight: hourHeight,
                                  narrow: narrow,
                                  isSelected:
                                      _selectedEventId == originalEvent.id,
                                  isManipulating:
                                      _movingEvent?.id == originalEvent.id,
                                  onTap: () => _selectEvent(originalEvent),
                                  onLongPressStart: (_) =>
                                      _startMoving(originalEvent),
                                  onLongPressMoveUpdate: (details) =>
                                      _updateMoving(
                                    details,
                                    gutterWidth: gutterWidth,
                                    columnWidth: columnWidth,
                                    startHour: startHour,
                                    endHour: endHour,
                                    hourHeight: hourHeight,
                                  ),
                                  onLongPressEnd: (_) => _finishMoving(),
                                  onLongPressCancel: _cancelMoving,
                                  onResizeStart: (edge) =>
                                      _startResizing(originalEvent, edge),
                                  onResizeUpdate: (details) => _updateResizing(
                                    details,
                                    startHour: startHour,
                                    endHour: endHour,
                                    hourHeight: hourHeight,
                                  ),
                                  onResizeEnd: (_) => _finishResizing(),
                                  onResizeCancel: _cancelResizing,
                                );
                              },
                            ),
                          if (_draftEvent case final draft?)
                            _GridDraftEvent(
                              event: draft,
                              dayIndex: draft.dayIndexIn(widget.days.first),
                              columnWidth: columnWidth,
                              gutterWidth: gutterWidth,
                              startHour: startHour,
                              hourHeight: hourHeight,
                              compact: narrow,
                              onTap: _confirmDraft,
                              onResizeStart: (edge) =>
                                  _startDraftResizing(draft, edge),
                              onResizeUpdate: (details) => _updateDraftResize(
                                details,
                                startHour: startHour,
                                endHour: endHour,
                                hourHeight: hourHeight,
                              ),
                              onResizeEnd: (_) => _finishDraftResize(),
                              onResizeCancel: _cancelDraftResize,
                            ),
                          if (todayIndex >= 0)
                            _CurrentTimeLine(
                              now: widget.now,
                              todayIndex: todayIndex,
                              columnWidth: columnWidth,
                              startHour: startHour,
                              endHour: endHour,
                              hourHeight: hourHeight,
                              gutterWidth: gutterWidth,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _updateDraftResize(
    DragUpdateDetails details, {
    required int startHour,
    required int endHour,
    required double hourHeight,
  }) {
    final origin = _resizeOrigin;
    final edge = _resizeEdge;
    if (origin == null || edge == null || origin.id != '_draft') {
      return;
    }
    _resizeDy += details.primaryDelta ?? 0;
    final delta = _snapMinutes(_resizeDy / hourHeight * 60);
    final day = DateTime(origin.start.year, origin.start.month, origin.start.day);
    final firstMinute = startHour * 60;
    final lastMinute = math.min(
      endHour * 60,
      24 * 60 - _gridSnapMinutes,
    );
    late final CalendarEvent resized;
    late final int feedbackStep;
    if (edge == _ResizeEdge.start) {
      final minute = (origin.startMinutes + delta).clamp(
        firstMinute,
        origin.endMinutes - _minimumEventMinutes,
      ).toInt();
      feedbackStep = minute;
      resized = _copyEvent(origin, start: _dateAtMinute(day, minute));
    } else {
      final minute = (origin.endMinutes + delta).clamp(
        origin.startMinutes + _minimumEventMinutes,
        lastMinute,
      ).toInt();
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
      _resizeDy = 0;
      _lastFeedbackStep = null;
    });
    HapticFeedback.selectionClick();
  }

  void _finishDraftResize() {
    setState(() {
      _resizeOrigin = null;
      _resizingEvent = null;
      _resizeEdge = null;
      _resizeDy = 0;
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
      _resizeDy = 0;
      _lastFeedbackStep = null;
    });
  }
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
      color: isToday ? accent.withValues(alpha: 0.045) : Colors.transparent,
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
          Container(
            width: narrow ? 26 : 29,
            height: narrow ? 26 : 29,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isToday ? accent : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${day.day}',
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: isToday ? WeekraColors.onAccent : _ink,
                fontSize: narrow ? 16 : 18,
                height: 1,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
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
    required this.onEventTap,
  });

  final List<DateTime> days;
  final List<CalendarEvent> events;
  final DateTime today;
  final double gutterWidth;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final byDay = List.generate(
      7,
      (index) => events
          .where((event) => event.dayIndexIn(days.first) == index)
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
          for (var dayIndex = 0; dayIndex < 7; dayIndex++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                color: _isSameDay(days[dayIndex], today)
                    ? accent.withValues(alpha: 0.045)
                    : Colors.transparent,
                child: Column(
                  children: [
                    for (var index = 0;
                        index < byDay[dayIndex].length;
                        index++) ...[
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
    );
  }
}

class _AllDayEvent extends StatelessWidget {
  const _AllDayEvent({required this.event, required this.onTap});

  final CalendarEvent event;
  final ValueChanged<CalendarEvent> onTap;

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
              color: Color.alphaBlend(
                event.color.withValues(alpha: 0.1),
                WeekraColors.surfaceRaised,
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: event.color.withValues(alpha: 0.3)),
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

class _HourRule extends StatelessWidget {
  const _HourRule({
    required this.top,
    required this.gutterWidth,
    required this.label,
  });

  final double top;
  final double gutterWidth;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: top,
      start: 0,
      end: 0,
      child: Row(
        children: [
          SizedBox(
            width: gutterWidth,
            child: Transform.translate(
              offset: const Offset(0, -6),
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
          const Expanded(child: Divider(height: 1, color: _line)),
        ],
      ),
    );
  }
}

class _GridEvent extends StatelessWidget {
  const _GridEvent({
    required this.event,
    required this.dayIndex,
    required this.lane,
    required this.laneCount,
    required this.columnWidth,
    required this.gutterWidth,
    required this.startHour,
    required this.hourHeight,
    required this.narrow,
    required this.isSelected,
    required this.isManipulating,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMoveUpdate,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onResizeCancel,
  });

  final CalendarEvent event;
  final int dayIndex;
  final int lane;
  final int laneCount;
  final double columnWidth;
  final double gutterWidth;
  final int startHour;
  final double hourHeight;
  final bool narrow;
  final bool isSelected;
  final bool isManipulating;
  final VoidCallback onTap;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;
  final GestureLongPressEndCallback onLongPressEnd;
  final VoidCallback onLongPressCancel;
  final ValueChanged<_ResizeEdge> onResizeStart;
  final GestureDragUpdateCallback onResizeUpdate;
  final GestureDragEndCallback onResizeEnd;
  final GestureDragCancelCallback onResizeCancel;

  @override
  Widget build(BuildContext context) {
    final visibleStart = math.max(event.startMinutes, startHour * 60);
    final visibleEnd = math.min(event.endMinutes, 24 * 60);
    final top = (visibleStart - startHour * 60) / 60 * hourHeight;
    final rawHeight = (visibleEnd - visibleStart) / 60 * hourHeight;
    final bodyHeight = math.max(28.0, rawHeight - 4);
    final handlePadding = isSelected && !isManipulating ? 12.0 : 0.0;
    final outerInset = narrow ? 2.0 : 5.0;
    const laneGap = 2.0;
    final usableWidth = columnWidth - outerInset * 2;
    final laneWidth = math.max(
      12.0,
      (usableWidth - laneGap * (laneCount - 1)) / laneCount,
    );
    final start = gutterWidth +
        dayIndex * columnWidth +
        outerInset +
        lane * (laneWidth + laneGap);
    final startLabel = _formatTime(context, event.startMinutes);
    final timeRange =
        '$startLabel – ${_formatTime(context, event.endMinutes)}';
    final isShort = bodyHeight < 44;
    final showInlineTime = isShort && laneWidth >= 96;
    final selectionColor = isSelected ? _ink : Colors.transparent;

    return PositionedDirectional(
      start: start,
      top: top + 2 - handlePadding,
      width: laneWidth,
      height: bodyHeight + handlePadding * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            start: 0,
            end: 0,
            top: handlePadding,
            height: bodyHeight,
            child: Semantics(
              button: true,
              selected: isSelected,
              label: '${event.title}, $timeRange',
              hint: AppLocalizations.of(context).moveEventHint,
              child: AnimatedScale(
                scale: isManipulating ? 1.015 : 1,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: GestureDetector(
                  key: Key('hourly-event-${event.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  onLongPressStart: onLongPressStart,
                  onLongPressMoveUpdate: onLongPressMoveUpdate,
                  onLongPressEnd: onLongPressEnd,
                  onLongPressCancel: onLongPressCancel,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsetsDirectional.fromSTEB(
                      narrow ? 5 : 7,
                      isShort ? 4 : 6,
                      narrow ? 4 : 6,
                      isShort ? 3 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        event.color.withValues(
                          alpha: isManipulating ? 0.18 : 0.1,
                        ),
                        WeekraColors.surfaceRaised,
                      ),
                      border: Border.all(
                        color: isSelected
                            ? selectionColor
                            : event.color.withValues(alpha: 0.3),
                        width: isSelected ? 1 : 0.75,
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
                          : null,
                    ),
                    child: isShort
                        ? Row(
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
                              if (showInlineTime) ...[
                                const SizedBox(width: 5),
                                Text(
                                  startLabel,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: _mutedInk,
                                    fontSize: 9,
                                    height: 1,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                maxLines: bodyHeight >= 82 ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: narrow ? 10.5 : 12.5,
                                  height: 1.15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              if (event.location != null &&
                                  bodyHeight >= 86) ...[
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
                          ),
                  ),
                ),
              ),
            ),
          ),
          if (isSelected && !isManipulating) ...[
            _GridResizeHandle(
              key: Key('event-resize-start-${event.id}'),
              edge: _ResizeEdge.start,
              color: event.color,
              semanticLabel: AppLocalizations.of(context).resizeEventStart,
              onStart: onResizeStart,
              onUpdate: onResizeUpdate,
              onEnd: onResizeEnd,
              onCancel: onResizeCancel,
            ),
            _GridResizeHandle(
              key: Key('event-resize-end-${event.id}'),
              edge: _ResizeEdge.end,
              color: event.color,
              semanticLabel: AppLocalizations.of(context).resizeEventEnd,
              onStart: onResizeStart,
              onUpdate: onResizeUpdate,
              onEnd: onResizeEnd,
              onCancel: onResizeCancel,
            ),
          ],
        ],
      ),
    );
  }
}

class _GridDraftEvent extends StatelessWidget {
  const _GridDraftEvent({
    required this.event,
    required this.dayIndex,
    required this.columnWidth,
    required this.gutterWidth,
    required this.startHour,
    required this.hourHeight,
    required this.compact,
    required this.onTap,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onResizeCancel,
  });

  final CalendarEvent event;
  final int dayIndex;
  final double columnWidth;
  final double gutterWidth;
  final int startHour;
  final double hourHeight;
  final bool compact;
  final VoidCallback onTap;
  final ValueChanged<_ResizeEdge> onResizeStart;
  final GestureDragUpdateCallback onResizeUpdate;
  final GestureDragEndCallback onResizeEnd;
  final GestureDragCancelCallback onResizeCancel;

  @override
  Widget build(BuildContext context) {
    final top = (event.startMinutes - startHour * 60) / 60 * hourHeight;
    final bodyHeight = math.max(
      compact ? 28.0 : 34.0,
      event.durationMinutes / 60 * hourHeight,
    ) - 4;
    const handlePadding = 12.0;
    return PositionedDirectional(
      start: gutterWidth + dayIndex * columnWidth + (compact ? 2 : 4),
      top: top + 2 - handlePadding,
      width: columnWidth - (compact ? 4 : 8),
      height: bodyHeight + handlePadding * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            start: 0,
            end: 0,
            top: handlePadding,
            height: bodyHeight,
            child: Semantics(
              button: true,
              label: AppLocalizations.of(context).confirmNewEventTime,
              child: GestureDetector(
                key: const Key('draft-event'),
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    compact ? 4 : 7,
                    compact ? 3 : 5,
                    compact ? 3 : 6,
                    compact ? 3 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
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
    );
  }
}

class _GridResizeHandle extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: 0,
      end: 0,
      top: edge == _ResizeEdge.start ? 0 : null,
      bottom: edge == _ResizeEdge.end ? 0 : null,
      height: 24,
      child: Semantics(
        slider: true,
        label: semanticLabel,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: (_) => onStart(edge),
            onVerticalDragUpdate: onUpdate,
            onVerticalDragEnd: onEnd,
            onVerticalDragCancel: onCancel,
            child: Center(
              child: Container(
                width: 18,
                height: 7,
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: color, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 4),
                  ],
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
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.gutterWidth,
  });

  final DateTime now;
  final int todayIndex;
  final double columnWidth;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final double gutterWidth;

  @override
  Widget build(BuildContext context) {
    final minutes = now.hour * 60 + now.minute;
    if (minutes < startHour * 60 || minutes > endHour * 60) {
      return const SizedBox.shrink();
    }
    final top = (minutes - startHour * 60) / 60 * hourHeight;
    final accent = Theme.of(context).colorScheme.primary;

    return PositionedDirectional(
      start: gutterWidth + todayIndex * columnWidth - 3,
      top: top - 3,
      width: columnWidth + 3,
      height: 7,
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 1.25,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({
    required this.weekStart,
    this.existingEvent,
    this.initialStart,
    this.initialEnd,
  }) : assert(
         (initialStart == null) == (initialEnd == null),
         'An initial time range must include both start and end.',
       );

  final DateTime weekStart;
  final CalendarEvent? existingEvent;
  final DateTime? initialStart;
  final DateTime? initialEnd;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  static const _eventColors = [
    Color(0xFFF1776C),
    Color(0xFF70B8AF),
    Color(0xFF7F9DD4),
    Color(0xFFC6A15B),
    Color(0xFFB7799E),
    Color(0xFF72A57C),
  ];

  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  Color _selectedColor = _eventColors.first;
  String? _validationMessage;

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
      _selectedColor = existingEvent.color;
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
      return;
    }
    final today = DateTime.now();
    final weekEnd = widget.weekStart.add(const Duration(days: 7));
    final isInWeek = !today.isBefore(widget.weekStart) && today.isBefore(weekEnd);
    _selectedDate = isInWeek ? today : widget.weekStart;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
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

  void _save() {
    final l10n = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    final start = _atTime(_selectedDate, _startTime);
    final end = _atTime(_selectedDate, _endTime);

    if (title.isEmpty) {
      setState(() => _validationMessage = l10n.eventTitleRequired);
      return;
    }
    if (!end.isAfter(start)) {
      setState(() => _validationMessage = l10n.eventEndAfterStart);
      return;
    }

    final location = _locationController.text.trim();
    Navigator.of(context).pop(
      CalendarEvent(
        id: widget.existingEvent?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        start: start,
        end: end,
        color: _selectedColor,
        location: location.isEmpty ? null : location,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final days = List.generate(
      7,
      (index) => widget.weekStart.add(Duration(days: index)),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                widget.existingEvent == null
                    ? l10n.newEventTitle
                    : l10n.editEventTitle,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const Key('event-title'),
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.titleLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('event-location'),
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.locationOptionalLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.daySection,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _fieldLabelStyle,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index < days.length; index++) ...[
                      ChoiceChip(
                        key: Key('event-day-$index'),
                        label: Text(
                          '${_weekdayShortName(l10n, days[index].weekday)} '
                          '${days[index].day}',
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                        ),
                        selected: _isSameDay(days[index], _selectedDate),
                        onSelected: (_) {
                          setState(() {
                            _selectedDate = days[index];
                            _validationMessage = null;
                          });
                        },
                      ),
                      if (index != days.length - 1) const SizedBox(width: 7),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.timeSection,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _fieldLabelStyle,
              ),
              const SizedBox(height: 8),
              _TimeRangeFields(
                startTime: _startTime,
                endTime: _endTime,
                onStartPressed: () => _pickTime(isStart: true),
                onEndPressed: () => _pickTime(isStart: false),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.colorSection,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _fieldLabelStyle,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                children: [
                  for (final color in _eventColors)
                    InkWell(
                      onTap: () => setState(() => _selectedColor = color),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: color == _selectedColor
                              ? Border.all(color: _ink, width: 3)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _validationMessage!,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('save-event'),
                  onPressed: _save,
                  child: Text(
                    widget.existingEvent == null
                        ? l10n.saveEvent
                        : l10n.saveChanges,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeRangeFields extends StatelessWidget {
  const _TimeRangeFields({
    required this.startTime,
    required this.endTime,
    required this.onStartPressed,
    required this.onEndPressed,
  });

  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final VoidCallback onStartPressed;
  final VoidCallback onEndPressed;

  @override
  Widget build(BuildContext context) {
    Widget button(TimeOfDay time, VoidCallback onPressed) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.schedule_rounded, size: 18),
        label: Text(
          MaterialLocalizations.of(context).formatTimeOfDay(
            time,
            alwaysUse24HourFormat:
                MediaQuery.alwaysUse24HourFormatOf(context),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledBody = MediaQuery.textScalerOf(context).scale(16);
        final shouldStack = constraints.maxWidth < 330 || scaledBody > 21;
        if (shouldStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              button(startTime, onStartPressed),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Icon(Icons.arrow_downward_rounded, size: 18),
              ),
              button(endTime, onEndPressed),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: button(startTime, onStartPressed)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 9),
              child: Icon(Icons.arrow_forward_rounded, size: 18),
            ),
            Expanded(child: button(endTime, onEndPressed)),
          ],
        );
      },
    );
  }
}

enum _EventAction { edit, delete }

class _EventDetailsSheet extends StatelessWidget {
  const _EventDetailsSheet({required this.event});

  final CalendarEvent event;

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
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: l10n.closeTooltip,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _EventDetailRow(
              icon: Icons.calendar_today_outlined,
              text: MaterialLocalizations.of(context).formatFullDate(
                event.start,
              ),
            ),
            const SizedBox(height: 12),
            _EventDetailRow(
              icon: Icons.schedule_rounded,
              text: '${_formatTime(context, event.startMinutes)} – '
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

Future<_EventAction?> _showEventDetailsSheet(
  BuildContext context,
  CalendarEvent event,
) {
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
  CalendarEvent? existingEvent,
  DateTime? initialStart,
  DateTime? initialEnd,
}) {
  return showModalBottomSheet<CalendarEvent>(
    context: context,
    isScrollControlled: true,
    backgroundColor: WeekraColors.surface,
    showDragHandle: false,
    builder: (context) => _EventEditorSheet(
      weekStart: weekStart,
      existingEvent: existingEvent,
      initialStart: initialStart,
      initialEnd: initialEnd,
    ),
  );
}

DateTime _atTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

DateTime _dateAtMinute(DateTime date, int minute) {
  return DateTime(date.year, date.month, date.day).add(Duration(minutes: minute));
}

int _snapMinutes(num minutes) {
  return (minutes / _gridSnapMinutes).round() * _gridSnapMinutes;
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
    location: event.location,
  );
}

const _fieldLabelStyle = TextStyle(
  color: _mutedInk,
  fontSize: 10,
  height: 1.2,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.3,
);

DateTime _startOfWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isAllDayEvent(CalendarEvent event) {
  return event.start.hour == 0 &&
      event.start.minute == 0 &&
      event.durationMinutes >= 23 * 60;
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
    final dayKey = event.start.year * 10000 + event.start.month * 100 + event.start.day;
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
        var lane = laneEnds.indexWhere((end) => end <= event.startMinutes);
        if (lane == -1) {
          lane = laneEnds.length;
          laneEnds.add(event.endMinutes);
        } else {
          laneEnds[lane] = event.endMinutes;
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
      groupEnd = math.max(groupEnd, event.endMinutes);
    }
    placeGroup();
  }
  return placements;
}

(int, int) _visibleHourRange(List<CalendarEvent> events) {
  var startHour = 7;
  var endHour = 22;
  for (final event in events) {
    startHour = math.min(startHour, event.startMinutes ~/ 60);
    endHour = math.max(endHour, (event.endMinutes / 60).ceil());
  }
  final safeStart = math.max(0, math.min(startHour, 23));
  final safeEnd = math.max(safeStart + 1, math.min(endHour, 24));
  return (safeStart, safeEnd);
}

String _formatTime(BuildContext context, int minutes) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
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

String _weekLabel(
  MaterialLocalizations localizations,
  DateTime weekStart,
) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  if (weekStart.month == weekEnd.month) {
    return localizations.formatMonthYear(weekStart);
  }
  return '${localizations.formatMonthYear(weekStart)} / '
      '${localizations.formatMonthYear(weekEnd)}';
}

String _weekdayName(AppLocalizations l10n, int weekday) {
  return switch (weekday) {
    DateTime.monday => l10n.weekdayMonday,
    DateTime.tuesday => l10n.weekdayTuesday,
    DateTime.wednesday => l10n.weekdayWednesday,
    DateTime.thursday => l10n.weekdayThursday,
    DateTime.friday => l10n.weekdayFriday,
    DateTime.saturday => l10n.weekdaySaturday,
    DateTime.sunday => l10n.weekdaySunday,
    _ => throw ArgumentError.value(weekday, 'weekday'),
  };
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
