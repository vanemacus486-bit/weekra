import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';
import 'package:weekra/features/calendar/domain/event_category.dart';

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
    expect(loaded.single.categoryId, EventCategories.uncategorizedId);
    expect(loaded.single.color, event.color);
    expect(loaded.single.location, event.location);
    expect(
      await File('${directory.path}/weekra_events_v1.json').readAsString(),
      contains('"categoryId":"uncategorized"'),
    );
  });

  test('maps a legacy palette color to a stable category id', () async {
    final directory = await Directory.systemTemp.createTemp('weekra_legacy_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/weekra_events_v1.json');
    await file.writeAsString(
      '[{"id":"legacy","title":"Legacy","start":"2026-09-03T15:00:00.000",'
      '"end":"2026-09-03T16:00:00.000","color":4285577391}]',
    );
    final store = JsonCalendarEventStore(
      directoryProvider: () async => directory,
    );

    final loaded = await store.load();

    expect(loaded, hasLength(1));
    expect(loaded!.single.categoryId, 'category-2');
    expect(loaded.single.color, const Color(0xFF70B8AF));
  });
}
