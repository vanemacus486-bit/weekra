import 'package:flutter/material.dart';
import 'package:weekra/app/weekra_app.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';

final _fixedNow = DateTime(2026, 9, 9, 10, 32);

void main() {
  runApp(
    WeekraApp(
      eventStore: _DesktopSmokeEventStore(_desktopEvents()),
      locale: const Locale('zh'),
      clock: () => _fixedNow,
      enableAutomaticUpdates: false,
    ),
  );
}

List<CalendarEvent> _desktopEvents() {
  final weekStart = DateTime(2026, 9, 7);

  DateTime at(int dayIndex, int hour, [int minute = 0]) {
    return weekStart.add(
      Duration(days: dayIndex, hours: hour, minutes: minute),
    );
  }

  CalendarEvent event(
    String id,
    String title,
    DateTime start,
    DateTime end,
    Color color, {
    String? location,
  }) {
    return CalendarEvent(
      id: id,
      title: title,
      start: start,
      end: end,
      color: color,
      location: location,
    );
  }

  return [
    event(
      'launch-window',
      '产品发布窗口',
      at(2, 0),
      at(3, 0),
      const Color(0xFFB7799E),
    ),
    event(
      'standup',
      '站会',
      at(0, 9),
      at(0, 9, 20),
      const Color(0xFFF1776C),
    ),
    event(
      'deep-work',
      'Weekra 深度工作',
      at(0, 14),
      at(0, 16),
      const Color(0xFF70B8AF),
    ),
    event(
      'long-title',
      '检查桌面信息架构、交互动画和最终文案',
      at(1, 10, 30),
      at(1, 12),
      const Color(0xFF7F9DD4),
      location: '设计工作室 · 302 室',
    ),
    event(
      'overlap-a',
      '调研整理',
      at(2, 10),
      at(2, 11, 30),
      const Color(0xFFC6A15B),
    ),
    event(
      'overlap-b',
      '合作方电话',
      at(2, 10, 30),
      at(2, 12),
      const Color(0xFF70B8AF),
    ),
    event(
      'overlap-c',
      '快速复核',
      at(2, 11),
      at(2, 11, 45),
      const Color(0xFFF1776C),
    ),
    event(
      'workshop',
      '原型工作坊',
      at(3, 13),
      at(3, 16, 30),
      const Color(0xFF7F9DD4),
      location: '项目室',
    ),
    event(
      'roadmap',
      '路线图讨论',
      at(3, 14),
      at(3, 15),
      const Color(0xFFF1776C),
    ),
    event(
      'workout',
      '锻炼',
      at(4, 18),
      at(4, 19, 15),
      const Color(0xFF72A57C),
    ),
    event(
      'edge-adjust',
      '周日计划复盘',
      at(6, 18),
      at(6, 19),
      const Color(0xFF7F9DD4),
    ),
  ];
}

class _DesktopSmokeEventStore implements CalendarEventStore {
  _DesktopSmokeEventStore(this.events);

  final List<CalendarEvent> events;

  @override
  Future<List<CalendarEvent>?> load() async => List.of(events);

  @override
  Future<void> save(List<CalendarEvent> events) async {}
}
