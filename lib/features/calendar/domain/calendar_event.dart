import 'package:flutter/material.dart';

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.dayIndex,
    required this.title,
    required this.startMinutes,
    required this.durationMinutes,
    required this.color,
    this.location,
  });

  final String id;
  final int dayIndex;
  final String title;
  final int startMinutes;
  final int durationMinutes;
  final Color color;
  final String? location;

  int get endMinutes => startMinutes + durationMinutes;
}

