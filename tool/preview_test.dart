import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/app/weekra_app.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';

const _previewKey = Key('weekra-preview');
final _fixedNow = DateTime(2026, 9, 9, 10, 32);

void main() {
  setUpAll(_loadPreviewFonts);

  testWidgets('renders the wide desktop week', (tester) async {
    await _pumpPreview(
      tester,
      const Size(1920, 1080),
      _previewEvents(crowded: false),
    );

    await expectLater(
      find.byKey(_previewKey),
      matchesGoldenFile('goldens/desktop-week-1920x1080.png'),
    );
  });

  testWidgets('renders a crowded narrow desktop week', (tester) async {
    await _pumpPreview(
      tester,
      const Size(1120, 760),
      _previewEvents(crowded: true),
    );

    await expectLater(
      find.byKey(_previewKey),
      matchesGoldenFile('goldens/desktop-crowded-1120x760.png'),
    );
  });

  testWidgets('renders an empty desktop week', (tester) async {
    await _pumpPreview(tester, const Size(1280, 800), const []);

    await expectLater(
      find.byKey(_previewKey),
      matchesGoldenFile('goldens/desktop-empty-1280x800.png'),
    );
  });

  testWidgets('renders the edge-aware desktop time card', (tester) async {
    await _pumpPreview(
      tester,
      const Size(1120, 760),
      _previewEvents(crowded: true),
    );

    await tester.tap(
      find.byKey(const Key('hourly-event-edge-adjust')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(_previewKey),
      matchesGoldenFile('goldens/desktop-time-card-edge-1120x760.png'),
    );
  });

  testWidgets('renders the mobile agenda', (tester) async {
    await _pumpPreview(
      tester,
      const Size(430, 932),
      _previewEvents(crowded: false),
    );

    await expectLater(
      find.byKey(_previewKey),
      matchesGoldenFile('goldens/mobile-week.png'),
    );
  });
}

Future<void> _pumpPreview(
  WidgetTester tester,
  Size size,
  List<CalendarEvent> events,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _previewKey,
      child: WeekraApp(
        eventStore: _PreviewEventStore(events),
        fontFamily: 'WeekraPreview',
        locale: const Locale('en'),
        clock: () => _fixedNow,
        enableAutomaticUpdates: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _loadPreviewFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('FLUTTER_ROOT is required to render previews.');
  }

  await Future.wait([
    _loadFont(
      'WeekraPreview',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ),
    _loadFont(
      'MaterialIcons',
      '$flutterRoot/bin/cache/artifacts/material_fonts/'
          'MaterialIcons-Regular.otf',
    ),
  ]);
}

Future<void> _loadFont(String family, String path) async {
  final bytes = await File(path).readAsBytes();
  final byteData = ByteData.view(
    bytes.buffer,
    bytes.offsetInBytes,
    bytes.lengthInBytes,
  );
  final loader = FontLoader(family)..addFont(Future<ByteData>.value(byteData));
  await loader.load();
}

List<CalendarEvent> _previewEvents({required bool crowded}) {
  final weekStart = DateTime(2026, 9, 7);

  DateTime at(int dayIndex, int hour, [int minute = 0]) {
    final day = weekStart.add(Duration(days: dayIndex));
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  final events = <CalendarEvent>[
    CalendarEvent(
      id: 'all-day',
      title: 'Product launch window',
      start: at(2, 0),
      end: at(3, 0),
      color: const Color(0xFFB7799E),
    ),
    CalendarEvent(
      id: 'standup',
      title: 'Stand-up',
      start: at(0, 9),
      end: at(0, 9, 20),
      color: const Color(0xFFF1776C),
    ),
    CalendarEvent(
      id: 'deep-work',
      title: 'Weekra deep work',
      start: at(0, 14),
      end: at(0, 16),
      color: const Color(0xFF70B8AF),
    ),
    CalendarEvent(
      id: 'long-title',
      title: 'Review the desktop information architecture and final copy',
      start: at(1, 10, 30),
      end: at(1, 12),
      color: const Color(0xFF7F9DD4),
      location: 'Design studio · Room 302',
    ),
    CalendarEvent(
      id: 'overlap-a',
      title: 'Research synthesis',
      start: at(2, 10),
      end: at(2, 11, 30),
      color: const Color(0xFFC6A15B),
    ),
    CalendarEvent(
      id: 'overlap-b',
      title: 'Partner call',
      start: at(2, 10, 30),
      end: at(2, 12),
      color: const Color(0xFF70B8AF),
    ),
    CalendarEvent(
      id: 'overlap-c',
      title: 'Quick review',
      start: at(2, 11),
      end: at(2, 11, 45),
      color: const Color(0xFFF1776C),
    ),
    CalendarEvent(
      id: 'workshop',
      title: 'Prototype workshop',
      start: at(3, 13),
      end: at(3, 16, 30),
      color: const Color(0xFF7F9DD4),
      location: 'Project room',
    ),
    CalendarEvent(
      id: 'workout',
      title: 'Workout',
      start: at(4, 18),
      end: at(4, 19, 15),
      color: const Color(0xFF72A57C),
    ),
    CalendarEvent(
      id: 'overnight',
      title: 'Overnight maintenance window',
      start: at(5, 22, 30),
      end: at(6, 1, 30),
      color: const Color(0xFFC6A15B),
    ),
    CalendarEvent(
      id: 'edge-adjust',
      title: 'Sunday planning review',
      start: at(6, 18),
      end: at(6, 19),
      color: const Color(0xFF7F9DD4),
    ),
  ];

  if (crowded) {
    events.addAll([
      CalendarEvent(
        id: 'crowded-1',
        title: 'Content review',
        start: at(1, 9),
        end: at(1, 11),
        color: const Color(0xFFB7799E),
      ),
      CalendarEvent(
        id: 'crowded-2',
        title: 'Engineering sync',
        start: at(1, 9, 30),
        end: at(1, 10, 45),
        color: const Color(0xFF70B8AF),
      ),
      CalendarEvent(
        id: 'crowded-3',
        title: 'Roadmap',
        start: at(3, 14),
        end: at(3, 15),
        color: const Color(0xFFF1776C),
      ),
    ]);
  }
  return events;
}

class _PreviewEventStore implements CalendarEventStore {
  _PreviewEventStore(this.events);

  final List<CalendarEvent> events;

  @override
  Future<List<CalendarEvent>?> load() async => List.of(events);

  @override
  Future<void> save(List<CalendarEvent> events) async {}
}
