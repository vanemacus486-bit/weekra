import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';

const _accent = Color(0xFFFF6B5F);
const _ink = Color(0xFFF7F3EF);
const _mutedInk = Color(0xFFA9A6A3);
const _line = Color(0x24FFFFFF);

class WeekScreen extends StatefulWidget {
  const WeekScreen({
    super.key,
    required this.eventStore,
  });

  final CalendarEventStore eventStore;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late DateTime _weekStart;
  List<CalendarEvent> _events = [];
  bool _isLoading = true;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final storedEvents = await widget.eventStore.load();
      final events = storedEvents ?? _seedEvents(_weekStart);
      if (storedEvents == null) {
        await widget.eventStore.save(events);
      }
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
        _storageError = 'Local events could not be loaded.';
      });
    }
  }

  Future<void> _createEvent() async {
    final event = await _showCreateEventSheet(context, _weekStart);
    if (event == null || !mounted) {
      return;
    }

    final previousEvents = _events;
    final updatedEvents = [..._events, event]
      ..sort((a, b) => a.start.compareTo(b.start));
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
        _storageError = 'The event could not be saved. Please try again.';
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
      _weekStart = _startOfWeek(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (index) => _weekStart.add(Duration(days: index)),
    );
    final events = _events.where((event) {
      final dayIndex = event.dayIndexIn(_weekStart);
      return dayIndex >= 0 && dayIndex < 7;
    }).toList();

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
        onPressed: _isLoading ? null : _createEvent,
        backgroundColor: _ink,
        foregroundColor: const Color(0xFF17181C),
        tooltip: 'New event',
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }

  List<CalendarEvent> _seedEvents(DateTime weekStart) {
    DateTime at(int dayIndex, int hour, [int minute = 0]) {
      final day = weekStart.add(Duration(days: dayIndex));
      return DateTime(day.year, day.month, day.day, hour, minute);
    }

    return [
      CalendarEvent(
        id: 'weekly-plan',
        title: 'Plan the week',
        start: at(0, 9),
        end: at(0, 10),
        color: const Color(0xFFFF7B6F),
      ),
      CalendarEvent(
        id: 'deep-work',
        title: 'Weekra deep work',
        start: at(0, 14),
        end: at(0, 16),
        color: const Color(0xFF63C8C2),
      ),
      CalendarEvent(
        id: 'class',
        title: 'Systems class',
        start: at(1, 10, 30),
        end: at(1, 12),
        color: const Color(0xFF8A9CF4),
        location: 'Room 302',
      ),
      CalendarEvent(
        id: 'english',
        title: 'English practice',
        start: at(2, 15),
        end: at(2, 16),
        color: const Color(0xFFF0B55A),
      ),
      CalendarEvent(
        id: 'review',
        title: 'MVP review',
        start: at(3, 11),
        end: at(3, 11, 45),
        color: const Color(0xFFE882B4),
      ),
      CalendarEvent(
        id: 'workout',
        title: 'Workout',
        start: at(4, 18),
        end: at(4, 19, 15),
        color: const Color(0xFF67C47B),
      ),
      CalendarEvent(
        id: 'walk',
        title: 'Evening walk',
        start: at(6, 19),
        end: at(6, 20),
        color: const Color(0xFF74A9E8),
      ),
    ];
  }
}

class _StorageErrorBanner extends StatelessWidget {
  const _StorageErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(message),
      leading: const Icon(Icons.error_outline_rounded),
      actions: [TextButton(onPressed: onDismiss, child: const Text('Dismiss'))],
    );
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
        final dayEvents = events
            .where((event) => event.dayIndexIn(days.first) == dayIndex)
            .toList()
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
                            dayIndex: event.dayIndexIn(days.first),
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
    required this.dayIndex,
    required this.columnWidth,
    required this.gutterWidth,
    required this.startHour,
    required this.hourHeight,
  });

  final CalendarEvent event;
  final int dayIndex;
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
      left: gutterWidth + dayIndex * columnWidth + 4,
      top: top + 2,
      width: columnWidth - 8,
      height: height - 4,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 5),
        decoration: BoxDecoration(
          color: event.color.withValues(alpha: 0.22),
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

class _CreateEventSheet extends StatefulWidget {
  const _CreateEventSheet({required this.weekStart});

  final DateTime weekStart;

  @override
  State<_CreateEventSheet> createState() => _CreateEventSheetState();
}

class _CreateEventSheetState extends State<_CreateEventSheet> {
  static const _eventColors = [
    Color(0xFFFF7B6F),
    Color(0xFF63C8C2),
    Color(0xFF8A9CF4),
    Color(0xFFF0B55A),
    Color(0xFFE882B4),
    Color(0xFF67C47B),
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
    final title = _titleController.text.trim();
    final start = _atTime(_selectedDate, _startTime);
    final end = _atTime(_selectedDate, _endTime);

    if (title.isEmpty) {
      setState(() => _validationMessage = 'Add an event title.');
      return;
    }
    if (!end.isAfter(start)) {
      setState(() => _validationMessage = 'End time must be after start time.');
      return;
    }

    final location = _locationController.text.trim();
    Navigator.of(context).pop(
      CalendarEvent(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
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
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 22),
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
              const SizedBox(height: 18),
              TextField(
                key: const Key('event-title'),
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('event-location'),
                controller: _locationController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              const Text('DAY', style: _fieldLabelStyle),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index < days.length; index++) ...[
                      ChoiceChip(
                        key: Key('event-day-$index'),
                        label: Text(
                          '${_weekdayNames[index].substring(0, 3)} ${days[index].day}',
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
              const Text('TIME', style: _fieldLabelStyle),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(isStart: true),
                      icon: const Icon(Icons.schedule_rounded, size: 18),
                      label: Text(_startTime.format(context)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9),
                    child: Icon(Icons.arrow_forward_rounded, size: 18),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(isStart: false),
                      icon: const Icon(Icons.schedule_rounded, size: 18),
                      label: Text(_endTime.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text('COLOR', style: _fieldLabelStyle),
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
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('save-event'),
                  onPressed: _save,
                  child: const Text('Save event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<CalendarEvent?> _showCreateEventSheet(
  BuildContext context,
  DateTime weekStart,
) {
  return showModalBottomSheet<CalendarEvent>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1B1D22),
    showDragHandle: false,
    builder: (context) => _CreateEventSheet(weekStart: weekStart),
  );
}

DateTime _atTime(DateTime date, TimeOfDay time) {
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

const _fieldLabelStyle = TextStyle(
  color: _mutedInk,
  fontSize: 10,
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
