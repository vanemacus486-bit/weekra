part of '../week_screen.dart';

/// A quiet, Timepage-inspired month: dates stay primary and events read as
/// small pieces of ink rather than cards competing with the calendar grid.
class _MonthLayout extends StatelessWidget {
  const _MonthLayout({
    super.key,
    required this.monthStart,
    required this.events,
    required this.today,
    required this.onEventTap,
    required this.onCreate,
  });

  final DateTime monthStart;
  final List<CalendarEvent> events;
  final DateTime today;
  final _OpenEventCallback onEventTap;
  final ValueChanged<DateTime> onCreate;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(monthStart.year, monthStart.month);
    final lastOfMonth = DateTime(monthStart.year, monthStart.month + 1, 0);
    final gridStart = firstOfMonth.subtract(
      Duration(days: firstOfMonth.weekday - DateTime.monday),
    );
    final trailingDays = (DateTime.sunday - lastOfMonth.weekday) % 7;
    final gridEnd = lastOfMonth.add(Duration(days: trailingDays));
    final dayCount = gridEnd.difference(gridStart).inDays + 1;
    final rowCount = dayCount ~/ DateTime.daysPerWeek;
    final days = List.generate(
      dayCount,
      (index) => gridStart.add(Duration(days: index)),
    );

    return ColoredBox(
      key: const Key('month-layout'),
      color: WeekraColors.canvas,
      child: Column(
        children: [
          const _MonthWeekdayHeader(),
          Expanded(
            child: Column(
              children: [
                for (var row = 0; row < rowCount; row++)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (
                          var column = 0;
                          column < DateTime.daysPerWeek;
                          column++
                        )
                          Expanded(
                            child: _MonthDayCell(
                              day: days[row * DateTime.daysPerWeek + column],
                              displayedMonth: firstOfMonth.month,
                              today: today,
                              events: _eventsForDay(
                                events,
                                days[row * DateTime.daysPerWeek + column],
                              ),
                              onEventTap: onEventTap,
                              onCreate: onCreate,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<CalendarEvent> _eventsForDay(
    List<CalendarEvent> source,
    DateTime day,
  ) {
    final result = source.where((event) => _eventOccursOnDay(event, day)).toList()
      ..sort((first, second) {
        final firstAllDay = _isAllDayEvent(first);
        final secondAllDay = _isAllDayEvent(second);
        if (firstAllDay != secondAllDay) return firstAllDay ? -1 : 1;
        final startOrder = first.start.compareTo(second.start);
        if (startOrder != 0) return startOrder;
        return first.title.compareTo(second.title);
      });
    return result;
  }
}

class _MonthWeekdayHeader extends StatelessWidget {
  const _MonthWeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final names = [
      l10n.weekdayShortMonday,
      l10n.weekdayShortTuesday,
      l10n.weekdayShortWednesday,
      l10n.weekdayShortThursday,
      l10n.weekdayShortFriday,
      l10n.weekdayShortSaturday,
      l10n.weekdayShortSunday,
    ];
    return SizedBox(
      height: 38,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: WeekraColors.divider),
          ),
        ),
        child: Row(
          children: [
            for (final name in names)
              Expanded(
                child: Center(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _mutedInk,
                      fontSize: 11,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
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

class _MonthDayCell extends StatefulWidget {
  const _MonthDayCell({
    required this.day,
    required this.displayedMonth,
    required this.today,
    required this.events,
    required this.onEventTap,
    required this.onCreate,
  });

  final DateTime day;
  final int displayedMonth;
  final DateTime today;
  final List<CalendarEvent> events;
  final _OpenEventCallback onEventTap;
  final ValueChanged<DateTime> onCreate;

  @override
  State<_MonthDayCell> createState() => _MonthDayCellState();
}

class _MonthDayCellState extends State<_MonthDayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final outsideMonth = widget.day.month != widget.displayedMonth;
    final isToday = _isSameDay(widget.day, widget.today);
    final key = _dateKey(widget.day);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        key: ValueKey('month-day-$key'),
        color: _hovered
            ? WeekraColors.surface.withValues(alpha: .72)
            : WeekraColors.canvas,
        child: InkWell(
          onTap: () => widget.onCreate(widget.day),
          hoverColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: WeekraColors.divider),
                bottom: BorderSide(color: WeekraColors.divider),
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(9, 7, 8, 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const rowHeight = 19.0;
                  final rowCapacity = math.max(
                    1,
                    ((constraints.maxHeight - 29) / rowHeight).floor(),
                  ).toInt();
                  final needsMore = widget.events.length > rowCapacity;
                  final availableEventRows = needsMore
                      ? math.max(1, rowCapacity - 1)
                      : rowCapacity;
                  final visibleCount = math.min(
                    3,
                    math.min(widget.events.length, availableEventRows),
                  ).toInt();
                  final visibleEvents = widget.events.take(visibleCount);
                  final remaining = widget.events.length - visibleCount;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 25,
                        child: Align(
                          alignment: AlignmentDirectional.topStart,
                          child: _MonthDateNumber(
                            day: widget.day.day,
                            isToday: isToday,
                            outsideMonth: outsideMonth,
                          ),
                        ),
                      ),
                      for (final event in visibleEvents)
                        SizedBox(
                          height: rowHeight,
                          child: _MonthEventRow(
                            day: widget.day,
                            event: event,
                            onTap: () => widget.onEventTap(event),
                          ),
                        ),
                      if (remaining > 0)
                        SizedBox(
                          key: ValueKey('month-more-$key'),
                          height: rowHeight,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(start: 8),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                '+$remaining',
                                style: const TextStyle(
                                  color: _tertiaryInk,
                                  fontSize: 10,
                                  height: 1,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthDateNumber extends StatelessWidget {
  const _MonthDateNumber({
    required this.day,
    required this.isToday,
    required this.outsideMonth,
  });

  final int day;
  final bool isToday;
  final bool outsideMonth;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: WeekraMotion.resolve(context, WeekraMotion.quick),
      width: 23,
      height: 23,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isToday ? accent : Colors.transparent,
      ),
      child: Text(
        '$day',
        style: TextStyle(
          color: isToday
              ? WeekraColors.onAccent
              : outsideMonth
              ? _tertiaryInk
              : _mutedInk,
          fontSize: 11,
          height: 1,
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _MonthEventRow extends StatelessWidget {
  const _MonthEventRow({
    required this.day,
    required this.event,
    required this.onTap,
  });

  final DateTime day;
  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = _isAllDayEvent(event)
        ? l10n.allDay
        : _monthEventTime(event, day);
    final dayKey = _dateKey(day);
    return Semantics(
      button: true,
      label: '${event.title}, $time',
      child: InkWell(
        key: ValueKey('month-event-${event.id}-$dayKey'),
        onTap: onTap,
        hoverColor: event.color.withValues(alpha: .08),
        splashFactory: NoSplash.splashFactory,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 1),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: event.color,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(dimension: 4),
              ),
              const SizedBox(width: 4),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: WeekraColors.textSecondary,
                    fontSize: 11,
                    height: 1.05,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 1,
                  color: event.color.withValues(alpha: .34),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                time,
                maxLines: 1,
                style: const TextStyle(
                  color: _tertiaryInk,
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _monthEventTime(CalendarEvent event, DateTime day) {
  if (!_isSameDay(event.start, day)) return '↳';
  final minute = event.start.minute;
  if (minute == 0) return '${event.start.hour}';
  return '${event.start.hour}:${minute.toString().padLeft(2, '0')}';
}
