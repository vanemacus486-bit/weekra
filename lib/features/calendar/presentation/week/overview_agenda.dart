part of '../week_screen.dart';

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
              color: WeekraColors.dayStrip,
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
                      fontWeight: FontWeight.w500,
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
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 18, 12),
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
                                const SizedBox(height: 8),
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
    final timeLabel = isAllDay ? l10n.allDay : '$start  –  $end';
    final metadata = event.location == null
        ? timeLabel
        : '$timeLabel  ·  ${event.location}';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(event),
        child: ConstrainedBox(
          key: Key('overview-event-${event.id}'),
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  key: Key('overview-event-marker-${event.id}'),
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: event.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
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
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        metadata,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: const TextStyle(
                          color: _mutedInk,
                          fontSize: 11,
                          height: 1.3,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
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
