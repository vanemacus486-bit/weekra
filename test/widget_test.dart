import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/app/weekra_app.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';

void main() {
  testWidgets('shows the Weekra week view', (tester) async {
    await tester.pumpWidget(WeekraApp(eventStore: _MemoryEventStore()));
    await tester.pumpAndSettle();

    expect(find.text('WEEKRA  /  YOUR WEEK'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('creates and saves an event', (tester) async {
    final store = _MemoryEventStore();
    await tester.pumpWidget(WeekraApp(eventStore: store));
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
    await tester.pumpWidget(WeekraApp(eventStore: store));
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
    await tester.pumpWidget(WeekraApp(eventStore: store));
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
