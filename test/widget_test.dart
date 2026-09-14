import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/app/weekra_app.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';
import 'package:weekra/features/calendar/domain/event_category.dart';

void main() {
  testWidgets('centers today and flows the visible dates one day at a time', (
    tester,
  ) async {
    _useViewport(tester, const Size(1280, 800));
    final now = DateTime(2026, 9, 14, 13, 30);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore(),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
        clock: () => now,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('hourly-header-20260911')),
      findsOneWidget,
    );
    final grid = tester.getRect(find.byKey(const Key('week-hourly-grid')));
    final today = tester.getRect(
      find.byKey(const Key('timeline-today-column')),
    );
    final gutterWidth = grid.width - today.width * 7;
    expect(
      today.center.dx,
      closeTo(grid.left + gutterWidth + today.width * 3.5, .1),
    );

    await tester.tap(find.byKey(const Key('timeline-next-day')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('hourly-header-20260912')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('hourly-header-20260911')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('hourly-header-20260912')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('hourly-header-20260911')),
      findsOneWidget,
    );
  });

  testWidgets('can create in both ends of the full day', (tester) async {
    _useViewport(tester, const Size(1280, 800));
    _useDesktopPlatform();
    final store = _MemoryEventStore();
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();
    final scroll = tester
        .widget<SingleChildScrollView>(find.byKey(const Key('hourly-scroll')))
        .controller!;
    for (final minute in [30, 23 * 60 + 45]) {
      scroll.jumpTo(minute < 60 ? 0 : scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final grid = tester.getRect(find.byKey(const Key('week-hourly-grid')));
      final point = Offset(
        grid.left + grid.width * .3,
        grid.top + grid.height * minute / (24 * 60) + 1,
      );
      await tester.tapAt(point, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('event-title')),
        'At $minute',
      );
      await tester.ensureVisible(find.byKey(const Key('save-event')));
      await tester.tap(find.byKey(const Key('save-event')));
      await tester.pumpAndSettle();
      expect(store.savedEvents.last.startMinutes, minute);
      expect(store.savedEvents.last.durationMinutes, minute > 1380 ? 15 : 60);
    }
    expect(store.savedEvents.last.end.hour, 0);
    expect(
      store.savedEvents.last.end.day,
      store.savedEvents.last.start.add(const Duration(days: 1)).day,
    );
    _restoreTestPlatform();
  });

  testWidgets('glass thumb retargets continuously on rapid reversal', (
    tester,
  ) async {
    _useViewport(tester, const Size(1280, 800));
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore(),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();
    final thumb = find.byKey(const Key('glass-layout-thumb'));
    final start = tester.getRect(thumb).left;
    await tester.tap(find.byKey(const Key('week-layout-grid')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final midway = tester.getRect(thumb).left;
    expect(midway, greaterThan(start));
    await tester.tap(find.byKey(const Key('week-layout-hourly')));
    await tester.pump();
    expect(tester.getRect(thumb).left, closeTo(midway, .1));
    await tester.pumpAndSettle();
    expect(tester.getRect(thumb).left, closeTo(start, .1));
    expect(
      find.byKey(const Key('week-hourly-layout')).hitTestable(),
      findsOneWidget,
    );
  });

  for (final size in [const Size(1280, 800), const Size(320, 568)]) {
    testWidgets('settings stays centered and scrollable at $size', (
      tester,
    ) async {
      _useViewport(tester, size);
      await tester.pumpWidget(
        WeekraApp(
          eventStore: _MemoryEventStore(),
          locale: const Locale('en', 'XA'),
          textScaler: TextScaler.linear(1.6),
          enableAutomaticUpdates: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(const Key('settings-card')));
      expect(rect.center.dx, closeTo(size.width / 2, 4));
      expect(rect.left, greaterThanOrEqualTo(16));
      expect(rect.bottom, lessThanOrEqualTo(size.height - 16));
      await tester.drag(
        find.byKey(const Key('settings-card')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows the Weekra week view', (tester) async {
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore(),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('W E E K R A'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('does not write preview data when storage is absent', (
    tester,
  ) async {
    final store = _MemoryEventStore.absent();
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(store.saveCalls, 0);
    expect(find.byKey(const Key('week-hourly-layout')), findsOneWidget);
  });

  testWidgets('lays overlapping events out in separate lanes', (tester) async {
    _useViewport(tester, const Size(1000, 900));
    final first = _eventAtStartOfWeek('Overlap A');
    final second = CalendarEvent(
      id: 'Overlap B',
      title: 'Overlap B',
      start: first.start.add(const Duration(minutes: 30)),
      end: first.end.add(const Duration(minutes: 30)),
      color: const Color(0xFF70B8AF),
    );
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore([first, second]),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    final firstRect = tester.getRect(
      find.byKey(const Key('hourly-event-Overlap A')),
    );
    final secondRect = tester.getRect(
      find.byKey(const Key('hourly-event-Overlap B')),
    );
    expect(
      firstRect.right <= secondRect.left || secondRect.right <= firstRect.left,
      isTrue,
    );
  });

  testWidgets('renders dense interaction fixtures in a wide desktop window', (
    tester,
  ) async {
    _useViewport(tester, const Size(1280, 800));
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore(_interactionFixtures()),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hourly-event-fixture-short')), findsOneWidget);
    expect(find.byKey(const Key('hourly-event-fixture-long')), findsOneWidget);
    expect(
      find.byKey(const Key('hourly-event-fixture-overnight')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('hourly-event-fixture-overnight-continuation-6')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders dense interaction fixtures in a narrow desktop window', (
    tester,
  ) async {
    _useViewport(tester, const Size(820, 680));
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore(_interactionFixtures()),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    final gridRect = tester.getRect(find.byKey(const Key('week-hourly-grid')));
    for (final id in [
      'fixture-overlap-a',
      'fixture-overlap-b',
      'fixture-overlap-c',
      'fixture-overlap-d',
    ]) {
      final eventRect = tester.getRect(find.byKey(Key('hourly-event-$id')));
      expect(eventRect.left, greaterThanOrEqualTo(gridRect.left));
      expect(eventRect.right, lessThanOrEqualTo(gridRect.right));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('preserves an overnight event through the time adjustment card', (
    tester,
  ) async {
    _useViewport(tester, const Size(1280, 800));
    _useDesktopPlatform();
    final overnight = _interactionFixtures().last;
    final store = _MemoryEventStore([overnight]);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('hourly-event-fixture-overnight-continuation-6')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('hourly-event-fixture-overnight-continuation-6')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adjust-time-card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();
    expect(store.savedEvents.single.durationMinutes, 180);
    expect(
      store.savedEvents.single.end.day,
      isNot(store.savedEvents.single.start.day),
    );
    _restoreTestPlatform();
  });

  testWidgets('preserves an overnight event through the full editor', (
    tester,
  ) async {
    _useViewport(tester, const Size(1280, 800));
    _useDesktopPlatform();
    final overnight = _interactionFixtures().last;
    final store = _MemoryEventStore([overnight]);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('hourly-event-fixture-overnight-continuation-6')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('hourly-event-fixture-overnight-continuation-6')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-event')));
    await tester.pumpAndSettle();

    final nextDayChip = tester.widget<FilterChip>(
      find.byKey(const Key('event-ends-next-day')),
    );
    expect(nextDayChip.selected, isTrue);
    await tester.ensureVisible(find.byKey(const Key('save-event')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();

    expect(store.savedEvents.single.durationMinutes, 180);
    _restoreTestPlatform();
  });

  testWidgets('keeps all seven columns usable at 125 percent display scale', (
    tester,
  ) async {
    _useScaledViewport(tester, const Size(1120, 760), 1.25);
    _useDesktopPlatform();
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore([
          _eventAtStartOfWeek('Scaled desktop event'),
        ]),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('week-hourly-layout')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Mon').hitTestable(), findsOneWidget);
    expect(find.text('Sun').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    _restoreTestPlatform();
  });

  testWidgets('switches between Grid and Hourly on a phone', (tester) async {
    _useViewport(tester, const Size(390, 844));
    final store = _MemoryEventStore([_eventAtStartOfWeek('Mobile week event')]);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('week-grid-layout')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('week-hourly-layout')).hitTestable(),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('week-layout-hourly')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('week-hourly-layout')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Mobile week event').hitTestable(), findsOneWidget);

    await tester.tap(find.byKey(const Key('week-layout-grid')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('week-grid-layout')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('New event'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('event-title')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.enterText(find.byKey(const Key('event-title')), 'Study');
    await tester.ensureVisible(find.byKey(const Key('save-event')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();

    expect(store.savedEvents, hasLength(1));
    expect(store.savedEvents.single.title, 'Study');
    expect(find.text('Study').hitTestable(), findsOneWidget);
  });

  testWidgets('suggests a local category and preserves a manual correction', (
    tester,
  ) async {
    final history = _event('Study', categoryId: 'category-2');
    final store = _MemoryEventStore([history]);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-title')), 'Study');
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Suggested · Category 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-category-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event-category-category-3')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-title')), 'Study ');
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('Category 3'), findsOneWidget);
    expect(find.text('Suggested · Category 2'), findsNothing);

    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();
    expect(store.savedEvents.last.categoryId, 'category-3');
  });

  testWidgets('keeps editor input when persistence fails', (tester) async {
    final store = _MemoryEventStore()..failNextSave = true;
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('event-title')),
      'Keep this draft',
    );
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('event-title')), findsOneWidget);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(
      find.text('The event could not be saved. Please try again.'),
      findsWidgets,
    );
    expect(store.savedEvents, isEmpty);
  });

  testWidgets('keyboard save ignores active IME composition', (tester) async {
    final store = _MemoryEventStore();
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('zh'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '学习',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(store.savedEvents, isEmpty);
    expect(find.byKey(const Key('event-title')), findsOneWidget);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '学习',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange.empty,
      ),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(store.savedEvents.single.title, '学习');
  });

  testWidgets('clicking an empty desktop slot previews then cancels creation', (
    tester,
  ) async {
    _useViewport(tester, const Size(900, 760));
    _useDesktopPlatform();
    final store = _MemoryEventStore();
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    final gridRect = tester.getRect(find.byKey(const Key('week-hourly-grid')));
    await tester.tapAt(
      Offset(
        gridRect.left + gridRect.width * 0.22,
        tester.getRect(find.byKey(const Key('hourly-scroll'))).top + 110,
      ),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('draft-event')), findsOneWidget);
    expect(find.text('New event'), findsNothing);
    await tester.tap(find.byKey(const Key('cancel-event-editor')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('draft-event')), findsNothing);
    expect(store.savedEvents, isEmpty);
    _restoreTestPlatform();
  });

  testWidgets('creates an event by dragging an empty desktop time range', (
    tester,
  ) async {
    _useViewport(tester, const Size(900, 1000));
    _useDesktopPlatform();
    final store = _MemoryEventStore();
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    final grid = find.byKey(const Key('week-hourly-grid'));
    final gridRect = tester.getRect(grid);
    final gesture = await tester.startGesture(
      Offset(
        gridRect.left + gridRect.width * 0.2,
        tester.getRect(find.byKey(const Key('hourly-scroll'))).top + 128,
      ),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 90));
    await tester.pump();

    expect(find.byKey(const Key('draft-event')), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('New event'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('event-title')),
      'Dragged event',
    );
    await tester.ensureVisible(find.byKey(const Key('save-event')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();

    expect(store.savedEvents, hasLength(1));
    expect(store.savedEvents.single.title, 'Dragged event');
    expect(store.savedEvents.single.start.minute % 15, 0);
    expect(store.savedEvents.single.durationMinutes, greaterThan(60));
    expect(store.savedEvents.single.durationMinutes % 15, 0);
    _restoreTestPlatform();
  });

  testWidgets('drags an event directly with the desktop primary button', (
    tester,
  ) async {
    _useViewport(tester, const Size(900, 1000));
    _useDesktopPlatform();
    final original = _eventAtStartOfWeek('Move me');
    final store = _MemoryEventStore([original]);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    final event = find.byKey(const Key('hourly-event-Move me'));
    final gridWidth = tester
        .getSize(find.byKey(const Key('week-hourly-grid')))
        .width;
    final gesture = await tester.startGesture(
      tester.getCenter(event),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(Offset(gridWidth / 7, 32));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final moved = store.savedEvents.single;
    expect(moved.start.day, original.start.add(const Duration(days: 1)).day);
    expect(moved.start.hour, 9);
    expect(moved.start.minute, 30);
    expect(moved.durationMinutes, original.durationMinutes);
    _restoreTestPlatform();
  });

  testWidgets('Escape cancels a desktop drag-to-create preview', (
    tester,
  ) async {
    _useViewport(tester, const Size(900, 760));
    _useDesktopPlatform();
    final store = _MemoryEventStore();
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    final gridRect = tester.getRect(find.byKey(const Key('week-hourly-grid')));
    final gesture = await tester.startGesture(
      Offset(
        gridRect.left + gridRect.width * 0.3,
        tester.getRect(find.byKey(const Key('hourly-scroll'))).top + 100,
      ),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(find.byKey(const Key('draft-event')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key('draft-event')), findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(store.savedEvents, isEmpty);
    _restoreTestPlatform();
  });

  testWidgets('right click opens a bounded time adjustment card', (
    tester,
  ) async {
    _useViewport(tester, const Size(900, 760));
    _useDesktopPlatform();
    final original = _eventAtStartOfWeek('Adjust me');
    final store = _MemoryEventStore([original]);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('hourly-event-Adjust me')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('adjust-time-card'));
    expect(card, findsOneWidget);
    final cardRect = tester.getRect(card);
    expect(cardRect.left, greaterThanOrEqualTo(0));
    expect(cardRect.right, lessThanOrEqualTo(900));
    expect(cardRect.top, greaterThanOrEqualTo(0));
    expect(cardRect.bottom, lessThanOrEqualTo(760));

    await tester.tap(find.byKey(const Key('increase-event-duration')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();
    expect(store.savedEvents.single.durationMinutes, 75);
    _restoreTestPlatform();
  });

  testWidgets('rapid layout changes settle on the latest requested view', (
    tester,
  ) async {
    _useViewport(tester, const Size(1000, 760));
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore([_eventAtStartOfWeek('Stable')]),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('week-layout-grid')));
    await tester.pump(const Duration(milliseconds: 45));
    await tester.tap(find.byKey(const Key('week-layout-hourly')));
    await tester.pump(const Duration(milliseconds: 45));
    await tester.tap(find.byKey(const Key('week-layout-grid')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('week-grid-layout')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stretches a selected event from its end handle', (tester) async {
    _useViewport(tester, const Size(900, 1000));
    final original = _eventAtStartOfWeek('Resize me');
    final store = _MemoryEventStore([original]);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('hourly-event-Resize me')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    final endHandle = find.byKey(const Key('event-resize-end-Resize me'));
    expect(endHandle, findsOneWidget);
    final resizeGesture = await tester.startGesture(
      tester.getCenter(endHandle),
    );
    await resizeGesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await resizeGesture.moveBy(const Offset(0, 32));
    await tester.pump();
    await resizeGesture.up();
    await tester.pumpAndSettle();

    expect(store.savedEvents.single.start, original.start);
    expect(store.savedEvents.single.end.isAfter(original.end), isTrue);
    expect(store.savedEvents.single.end.minute % 15, 0);
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

    await tester.tap(find.text('Original title').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-event')));
    await tester.pumpAndSettle();

    expect(find.text('Edit event'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('event-title')),
      'Updated title',
    );
    await tester.ensureVisible(find.byKey(const Key('save-event')));
    await tester.tap(find.byKey(const Key('save-event')));
    await tester.pumpAndSettle();

    expect(store.savedEvents, hasLength(1));
    expect(store.savedEvents.single.title, 'Updated title');
    expect(find.text('Updated title').hitTestable(), findsOneWidget);
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

    await tester.tap(find.text('Remove me').hitTestable());
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

    expect(find.text('W E E K R A'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('暂无安排'), findsWidgets);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('新建日程'), findsNothing);
    expect(find.text('更多'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-more')));
    await tester.pumpAndSettle();
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

    expect(find.text('⟦W E E K R A⟧'), findsOneWidget);
    await tester.tap(
      find
          .text(
            'A deliberately long calendar event title for layout verification',
          )
          .hitTestable(),
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

void _useScaledViewport(WidgetTester tester, Size logicalSize, double scale) {
  tester.view.devicePixelRatio = scale;
  tester.view.physicalSize = Size(
    logicalSize.width * scale,
    logicalSize.height * scale,
  );
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void _useDesktopPlatform() {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
}

void _restoreTestPlatform() {
  debugDefaultTargetPlatformOverride = null;
}

class _MemoryEventStore implements CalendarEventStore {
  _MemoryEventStore([List<CalendarEvent> initialEvents = const []])
    : savedEvents = List.of(initialEvents),
      _returnsNull = false;

  _MemoryEventStore.absent() : savedEvents = [], _returnsNull = true;

  List<CalendarEvent> savedEvents;
  bool _returnsNull;
  int saveCalls = 0;
  bool failNextSave = false;

  @override
  Future<List<CalendarEvent>?> load() async =>
      _returnsNull ? null : List.of(savedEvents);

  @override
  Future<void> save(List<CalendarEvent> events) async {
    saveCalls += 1;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Simulated local persistence failure');
    }
    _returnsNull = false;
    savedEvents = List.of(events);
  }
}

CalendarEvent _event(
  String title, {
  String categoryId = EventCategories.uncategorizedId,
}) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day, 9);
  return CalendarEvent(
    id: title,
    title: title,
    start: start,
    end: start.add(const Duration(hours: 1)),
    categoryId: categoryId,
    color: EventCategories.colorFor(categoryId),
  );
}

CalendarEvent _eventAtStartOfWeek(String title) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 3));
  return CalendarEvent(
    id: title,
    title: title,
    start: start.add(const Duration(hours: 9)),
    end: start.add(const Duration(hours: 10)),
    color: const Color(0xFFFF7B6F),
  );
}

List<CalendarEvent> _interactionFixtures() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(const Duration(days: 3));

  DateTime at(int day, int hour, [int minute = 0]) {
    return weekStart.add(Duration(days: day, hours: hour, minutes: minute));
  }

  CalendarEvent event(
    String id,
    String title,
    DateTime start,
    DateTime end,
    Color color,
  ) {
    return CalendarEvent(
      id: id,
      title: title,
      start: start,
      end: end,
      color: color,
    );
  }

  return [
    event(
      'fixture-short',
      'Short event',
      at(0, 8),
      at(0, 8, 15),
      const Color(0xFFF1776C),
    ),
    event(
      'fixture-long',
      'A deliberately long event title that must remain bounded and readable',
      at(1, 13),
      at(1, 15),
      const Color(0xFF7F9DD4),
    ),
    for (var index = 0; index < 4; index++)
      event(
        'fixture-overlap-${String.fromCharCode(97 + index)}',
        'Overlap ${index + 1}',
        at(3, 10, index * 15),
        at(3, 12, index * 15),
        const Color(0xFF70B8AF),
      ),
    event(
      'fixture-overnight',
      'Overnight maintenance',
      at(5, 22, 30),
      at(6, 1, 30),
      const Color(0xFFC6A15B),
    ),
  ];
}
