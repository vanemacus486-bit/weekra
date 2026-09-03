import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';

void main() {
  test('round-trips events through the local JSON store', () async {
    final directory = await Directory.systemTemp.createTemp('weekra_test_');
    addTearDown(() => directory.delete(recursive: true));
    final store = JsonCalendarEventStore(
      directoryProvider: () async => directory,
    );
    final event = CalendarEvent(
      id: 'event-1',
      title: 'English practice',
      start: DateTime(2026, 9, 3, 15),
      end: DateTime(2026, 9, 3, 16),
      color: const Color(0xFFF0B55A),
      location: 'Library',
    );

    expect(await store.load(), isNull);
    await store.save([event]);
    final loaded = await store.load();

    expect(loaded, hasLength(1));
    expect(loaded!.single.id, event.id);
    expect(loaded.single.title, event.title);
    expect(loaded.single.start, event.start);
    expect(loaded.single.end, event.end);
    expect(loaded.single.color, event.color);
    expect(loaded.single.location, event.location);
  });
}
