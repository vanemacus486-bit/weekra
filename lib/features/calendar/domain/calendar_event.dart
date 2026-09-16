import 'package:flutter/material.dart';
import 'package:weekra/features/calendar/domain/event_category.dart';

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required Color color,
    String? categoryId,
    this.location,
  }) : categoryId =
           EventCategories.byId(categoryId)?.id ??
           EventCategories.idForLegacyColor(color),
       _color = color,
       assert(end.isAfter(start), 'Event end must be after its start.');

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String categoryId;
  final Color _color;
  final String? location;

  Color get color => _color;

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
      'categoryId': categoryId,
      // Kept as a downgrade-safe display fallback. Category identity and
      // future statistics use categoryId, never this color value.
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
      color: Color(
        (json['color'] as int?) ??
            EventCategories.uncategorized.color.toARGB32(),
      ),
      categoryId: json['categoryId'] as String?,
      location: json['location'] as String?,
    );
  }
}
