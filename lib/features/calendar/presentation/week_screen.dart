import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';

const _accent = Color(0xFFFF6B5F);
const _ink = Color(0xFFF7F3EF);
const _mutedInk = Color(0xFFA9A6A3);
const _line = Color(0x24FFFFFF);

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
  }

  void _moveWeek(int offset) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: offset * 7));
    });
  }

  void _returnToToday() {
    setState(() {
      _weekStart = _startOfWeek(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (index) => _weekStart.add(Duration(days: index)),
    );
    final events = _sampleEvents();

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF33181B), Color(0xFF111318), Color(0xFF090A0D)],
            stops: [0, 0.48, 1],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _WeekToolbar(
                weekStart: _weekStart,
                onPrevious: () => _moveWeek(-1),
                onNext: () => _moveWeek(1),
                onToday: _returnToToday,
              ),
              Expanded(
                child: GestureDetector(
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
                    child: LayoutBuilder(
                      key: ValueKey(_weekStart),
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 760) {
                          return _WeekGrid(days: days, events: events);
                        }
                        return _WeekAgenda(days: days, events: events);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateEventPreview(context),
        backgroundColor: _ink,
        foregroundColor: const Color(0xFF17181C),
        tooltip: 'New event',
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }

  List<CalendarEvent> _sampleEvents() {
    return const [
      CalendarEvent(
        id: 'weekly-plan',
        dayIndex: 0,
        title: 'Plan the week',
        startMinutes: 540,
        durationMinutes: 60,
        color: Color(0xFFFF7B6F),
      ),
      CalendarEvent(
        id: 'deep-work',
        dayIndex: 0,
        title: 'Weekra deep work',
        startMinutes: 840,
        durationMinutes: 120,
        color: Color(0xFF63C8C2),
      ),
      CalendarEvent(
        id: 'class',
        dayIndex: 1,
        title: 'Systems class',
        startMinutes: 630,
        durationMinutes: 90,
        color: Color(0xFF8A9CF4),
        location: 'Room 302',
      ),
      CalendarEvent(
        id: 'english',
        dayIndex: 2,
        title: 'English practice',
        startMinutes: 900,
        durationMinutes: 60,
        color: Color(0xFFF0B55A),
      ),
      CalendarEvent(
        id: 'review',
        dayIndex: 3,
        title: 'MVP review',
        startMinutes: 660,
        durationMinutes: 45,
        color: Color(0xFFE882B4),
      ),
      CalendarEvent(
        id: 'workout',
        dayIndex: 4,
        title: 'Workout',
        startMinutes: 1080,
        durationMinutes: 75,
        color: Color(0xFF67C47B),
      ),
      CalendarEvent(
        id: 'walk',
        dayIndex: 6,
        title: 'Evening walk',
        startMinutes: 1140,
        durationMinutes: 60,
        color: Color(0xFF74A9E8),
      ),
    ];
  }
}

class _WeekToolbar extends StatelessWidget {
  const _WeekToolbar({
    required this.weekStart,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime weekStart;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WEEKRA  /  YOUR WEEK',
                  style: TextStyle(
                    color: _mutedInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _weekLabel(weekStart),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onToday, child: const Text('Today')),
          IconButton(
            onPressed: onPrevious,
            tooltip: 'Previous week',
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            onPressed: onNext,
            tooltip: 'Next week',
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _WeekAgenda extends StatelessWidget {
  const _WeekAgenda({required this.days, required this.events});

  final List<DateTime> days;
  final List<CalendarEvent> events;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 92),
      itemCount: days.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: _line),
      itemBuilder: (context, dayIndex) {
        final day = days[dayIndex];
        final dayEvents = events.where((event) => event.dayIndex == dayIndex).toList()
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
        return _AgendaDay(
          day: day,
          events: dayEvents,
          isToday: _isSameDay(day, DateTime.now()),
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
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 66,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _weekdayNames[day.weekday - 1].toUpperCase(),
                  style: TextStyle(
                    color: isToday ? _accent : _mutedInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? _accent : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: events.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: Text(
                      'Open day',
                      style: TextStyle(color: _mutedInk, fontSize: 13),
                    ),
                  )
                : Column(
                    children: [
                      for (var index = 0; index < events.length; index++) ...[
                        _AgendaEvent(event: events[index]),
                        if (index != events.length - 1) const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AgendaEvent extends StatelessWidget {
  const _AgendaEvent({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: event.location == null ? 42 : 52,
          decoration: BoxDecoration(
            color: event.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 11),
        SizedBox(
          width: 84,
          child: Text(
            '${_clock(event.startMinutes)}  →\n${_clock(event.endMinutes)}',
            style: const TextStyle(
              color: _mutedInk,
              fontSize: 11,
              height: 1.45,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (event.location != null) ...[
                const SizedBox(height: 3),
                Text(
                  event.location!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _mutedInk, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.days, required this.events});

  final List<DateTime> days;
  final List<CalendarEvent> events;

  static const startHour = 7;
  static const endHour = 22;
  static const hourHeight = 64.0;
  static const gutterWidth = 56.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - gutterWidth) / 7;
        final gridHeight = (endHour - startHour) * hourHeight;

        return Column(
          children: [
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  const SizedBox(width: gutterWidth),
                  for (final day in days)
                    Expanded(
                      child: _GridDayHeader(
                        day: day,
                        isToday: _isSameDay(day, DateTime.now()),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: _line),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 92),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: gridHeight,
                  child: Stack(
                    children: [
                      for (var hour = startHour; hour <= endHour; hour++)
                        Positioned(
                          top: (hour - startHour) * hourHeight,
                          left: 0,
                          right: 0,
                          child: Row(
                            children: [
                              SizedBox(
                                width: gutterWidth,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    '${hour.toString().padLeft(2, '0')}:00',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: _mutedInk,
                                      fontSize: 10,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(height: 1, color: _line)),
                            ],
                          ),
                        ),
                      for (var index = 0; index <= 7; index++)
                        Positioned(
                          left: gutterWidth + (columnWidth * index),
                          top: 0,
                          bottom: 0,
                          child: const VerticalDivider(width: 1, color: _line),
                        ),
                      for (final event in events)
                        if (event.endMinutes > startHour * 60 &&
                            event.startMinutes < endHour * 60)
                          _GridEvent(
                            event: event,
                            columnWidth: columnWidth,
                            gutterWidth: gutterWidth,
                            startHour: startHour,
                            hourHeight: hourHeight,
                          ),
                      if (_weekContainsToday(days))
                        _CurrentTimeLine(
                          gridWidth: constraints.maxWidth,
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
          ],
        );
      },
    );
  }
}

class _GridDayHeader extends StatelessWidget {
  const _GridDayHeader({required this.day, required this.isToday});

  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _weekdayNames[day.weekday - 1].substring(0, 3).toUpperCase(),
          style: TextStyle(
            color: isToday ? _accent : _mutedInk,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${day.day}',
          style: TextStyle(
            color: isToday ? _accent : _ink,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GridEvent extends StatelessWidget {
  const _GridEvent({
    required this.event,
    required this.columnWidth,
    required this.gutterWidth,
    required this.startHour,
    required this.hourHeight,
  });

  final CalendarEvent event;
  final double columnWidth;
  final double gutterWidth;
  final int startHour;
  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    final visibleStart = math.max(event.startMinutes, startHour * 60);
    final top = (visibleStart - startHour * 60) / 60 * hourHeight;
    final height = math.max(34.0, event.durationMinutes / 60 * hourHeight);

    return Positioned(
      left: gutterWidth + event.dayIndex * columnWidth + 4,
      top: top + 2,
      width: columnWidth - 8,
      height: height - 4,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 5),
        decoration: BoxDecoration(
          color: Color.fromRGBO(
            event.color.red,
            event.color.green,
            event.color.blue,
            0.22,
          ),
          border: Border(left: BorderSide(color: event.color, width: 3)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            if (height >= 54) ...[
              const SizedBox(height: 3),
              Text(
                _clock(event.startMinutes),
                style: const TextStyle(color: _mutedInk, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentTimeLine extends StatelessWidget {
  const _CurrentTimeLine({
    required this.gridWidth,
    required this.startHour,
    required this.endHour,
    required this.hourHeight,
    required this.gutterWidth,
  });

  final double gridWidth;
  final int startHour;
  final int endHour;
  final double hourHeight;
  final double gutterWidth;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    if (minutes < startHour * 60 || minutes > endHour * 60) {
      return const SizedBox.shrink();
    }
    final top = (minutes - startHour * 60) / 60 * hourHeight;

    return Positioned(
      left: gutterWidth - 4,
      top: top,
      width: gridWidth - gutterWidth + 4,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
          ),
          const Expanded(child: Divider(height: 1, thickness: 1, color: _accent)),
        ],
      ),
    );
  }
}

class _CreateEventPreview extends StatelessWidget {
  const _CreateEventPreview();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          14,
          24,
          22 + MediaQuery.of(context).viewInsets.bottom,
        ),
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
            const Text(
              'New event',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Event editing is the next MVP slice.',
              style: TextStyle(color: _mutedInk),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showCreateEventPreview(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1B1D22),
    showDragHandle: false,
    builder: (context) => const _CreateEventPreview(),
  );
}

DateTime _startOfWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _weekContainsToday(List<DateTime> days) {
  final today = DateTime.now();
  return days.any((day) => _isSameDay(day, today));
}

String _clock(int minutes) {
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _weekLabel(DateTime weekStart) {
  final weekEnd = weekStart.add(const Duration(days: 6));
  if (weekStart.month == weekEnd.month) {
    return '${_monthNames[weekStart.month - 1]} ${weekStart.year}';
  }
  return '${_monthNames[weekStart.month - 1].substring(0, 3)} / '
      '${_monthNames[weekEnd.month - 1].substring(0, 3)} ${weekEnd.year}';
}

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthNames = [
  'JANUARY',
  'FEBRUARY',
  'MARCH',
  'APRIL',
  'MAY',
  'JUNE',
  'JULY',
  'AUGUST',
  'SEPTEMBER',
  'OCTOBER',
  'NOVEMBER',
  'DECEMBER',
];
