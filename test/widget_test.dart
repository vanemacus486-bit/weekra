import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/app/weekra_app.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';

void main() {
  testWidgets('shows the Weekra week view', (tester) async {
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore(),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WEEKRA / YOUR WEEK'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('creates and saves an event', (tester) async {
    final store = _MemoryEventStore();
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New event'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('event-title')), 'Study');
    await tester.ensureVisible(find.byKey(const Key('save-event')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();

    expect(store.savedEvents, hasLength(1));
    expect(store.savedEvents.single.title, 'Study');
    expect(find.text('Study'), findsOneWidget);
  });

  testWidgets('edits an existing event', (tester) async {
    final store = _MemoryEventStore([_event('Original title')]);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Original title'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-event')));
    await tester.pumpAndSettle();

    expect(find.text('Edit event'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('event-title')),
      'Updated title',
    );
    await tester.ensureVisible(find.byKey(const Key('save-event')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();

    expect(store.savedEvents, hasLength(1));
    expect(store.savedEvents.single.title, 'Updated title');
    expect(find.text('Updated title'), findsOneWidget);
  });

  testWidgets('deletes an existing event after confirmation', (tester) async {
    final store = _MemoryEventStore([_event('Remove me')]);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove me'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-event')));
    await tester.pumpAndSettle();

    expect(find.text('Delete event?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-event')));
    await tester.pumpAndSettle();

    expect(store.savedEvents, isEmpty);
    expect(find.text('Remove me'), findsNothing);
  });

  testWidgets('supports Simplified Chinese throughout the event flow', (
    tester,
  ) async {
    _useViewport(tester, const Size(320, 568));
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore(),
        locale: const Locale('zh'),
        textScaler: TextScaler.linear(1.6),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WEEKRA / 我的一周'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('暂无安排'), findsWidgets);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('新建日程'), findsOneWidget);
    expect(find.text('地点（可选）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pseudo-localization tolerates expanded text and large type', (
    tester,
  ) async {
    _useViewport(tester, const Size(320, 568));
    final store = _MemoryEventStore([
      _eventAtStartOfWeek(
        'A deliberately long calendar event title for layout verification',
      ),
    ]);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en', 'XA'),
        textScaler: TextScaler.linear(1.6),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('⟦WEEKRA / YOUR EXTRA SPACIOUS WEEK⟧'),
      findsOneWidget,
    );
    await tester.tap(
      find.text(
        'A deliberately long calendar event title for layout verification',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('⟦Edit event details⟧'), findsOneWidget);
    expect(find.text('⟦Delete this event⟧'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _useViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _MemoryEventStore implements CalendarEventStore {
  _MemoryEventStore([List<CalendarEvent> initialEvents = const []])
      : savedEvents = List.of(initialEvents);

  List<CalendarEvent> savedEvents;

  @override
  Future<List<CalendarEvent>?> load() async => List.of(savedEvents);

  @override
  Future<void> save(List<CalendarEvent> events) async {
    savedEvents = List.of(events);
  }
}

CalendarEvent _event(String title) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day, 9);
  return CalendarEvent(
    id: title,
    title: title,
    start: start,
    end: start.add(const Duration(hours: 1)),
    color: const Color(0xFFFF7B6F),
  );
}

CalendarEvent _eventAtStartOfWeek(String title) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: now.weekday - DateTime.monday));
  return CalendarEvent(
    id: title,
    title: title,
    start: start.add(const Duration(hours: 9)),
    end: start.add(const Duration(hours: 10)),
    color: const Color(0xFFFF7B6F),
  );
}
