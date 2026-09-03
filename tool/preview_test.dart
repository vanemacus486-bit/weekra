import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/app/weekra_app.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';

const _previewKey = Key('weekra-preview');

void main() {
  setUpAll(_loadPreviewFont);

  testWidgets('renders the mobile week view', (tester) async {
    await _pumpPreview(tester, const Size(430, 932));

    await expectLater(
      find.byKey(_previewKey),
      matchesGoldenFile('goldens/mobile-week.png'),
    );
  });

  testWidgets('renders mobile event details', (tester) async {
    await _pumpPreview(tester, const Size(430, 932));
    await tester.tap(find.text('Plan the week'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(_previewKey),
      matchesGoldenFile('goldens/mobile-event-details.png'),
    );
  });

  testWidgets('renders the desktop week grid', (tester) async {
    await _pumpPreview(tester, const Size(1280, 800));

    await expectLater(
      find.byKey(_previewKey),
      matchesGoldenFile('goldens/desktop-week.png'),
    );
  });
}

Future<void> _pumpPreview(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _previewKey,
      child: WeekraApp(
        eventStore: _PreviewEventStore(_previewEvents()),
        fontFamily: 'WeekraPreview',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _loadPreviewFont() async {
  final bytes = await File(
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  ).readAsBytes();
  final byteData = ByteData.view(
    bytes.buffer,
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );
  final loader = FontLoader('WeekraPreview')
    ..addFont(Future<ByteData>.value(byteData));
  await loader.load();
}

List<CalendarEvent> _previewEvents() {
  final now = DateTime.now();
  final weekStart = DateTime(now.year, now.month, now.day).subtract(
    Duration(days: now.weekday - DateTime.monday),
  );

  DateTime at(int dayIndex, int hour, [int minute = 0]) {
    final day = weekStart.add(Duration(days: dayIndex));
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  return [
    CalendarEvent(
      id: 'plan',
      title: 'Plan the week',
      start: at(0, 9),
      end: at(0, 10),
      color: const Color(0xFFFF7B6F),
      location: 'Library',
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

class _PreviewEventStore implements CalendarEventStore {
  _PreviewEventStore(this.events);

  final List<CalendarEvent> events;

  @override
  Future<List<CalendarEvent>?> load() async => events;

  @override
  Future<void> save(List<CalendarEvent> events) async {}
}
