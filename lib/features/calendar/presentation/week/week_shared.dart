part of '../week_screen.dart';

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
