import 'package:flutter/material.dart';

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.color,
    this.location,
  }) : assert(end.isAfter(start), 'Event end must be after its start.');

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final Color color;
  final String? location;

  int get startMinutes => start.hour * 60 + start.minute;

  int get endMinutes => end.hour * 60 + end.minute;

  int get durationMinutes => end.difference(start).inMinutes;

  int dayIndexIn(DateTime weekStart) {
    final eventDay = DateTime(start.year, start.month, start.day);
    final firstDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return eventDay.difference(firstDay).inDays;
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'color': color.toARGB32(),
      'location': location,
    };
  }

  factory CalendarEvent.fromJson(Map<String, Object?> json) {
    return CalendarEvent(
      id: json['id']! as String,
      title: json['title']! as String,
      start: DateTime.parse(json['start']! as String),
      end: DateTime.parse(json['end']! as String),
      color: Color(json['color']! as int),
      location: json['location'] as String?,
    );
  }
}
