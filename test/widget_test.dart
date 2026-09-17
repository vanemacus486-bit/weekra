import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/app/glass_surface.dart';
import 'package:weekra/app/weekra_design.dart';
import 'package:weekra/app/weekra_app.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';
import 'package:weekra/features/calendar/domain/event_category.dart';
import 'package:weekra/features/settings/data/app_settings_store.dart';
import 'package:weekra/features/settings/domain/app_settings.dart';

void main() {
  test('control theme distinguishes hover, press, and disabled states', () {
    final theme = WeekraDesign.dark();
    final iconStyle = theme.iconButtonTheme.style!;
    expect(
      iconStyle.backgroundColor!.resolve({WidgetState.hovered}),
      WeekraColors.surfaceRaised,
    );
    expect(
      iconStyle.backgroundColor!.resolve({WidgetState.pressed}),
      WeekraColors.surfacePressed,
    );
    expect(
      iconStyle.foregroundColor!.resolve({WidgetState.hovered}),
      WeekraColors.textPrimary,
    );
    expect(
      iconStyle.foregroundColor!.resolve({WidgetState.disabled}),
      WeekraColors.textTertiary,
    );

    final textStyle = theme.textButtonTheme.style!;
    expect(
      textStyle.backgroundColor!.resolve({WidgetState.hovered}),
      WeekraColors.surfaceRaised,
    );
    expect(
      textStyle.backgroundColor!.resolve({WidgetState.pressed}),
      WeekraColors.surfacePressed,
    );
  });

  testWidgets('toolbar icon compresses while the pointer is down', (
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

    final control = find.byKey(const Key('open-settings'));
    final scale = find.descendant(
      of: control,
      matching: find.byType(AnimatedScale),
    );
    expect(scale, findsOneWidget);

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: tester.getCenter(control));
    await pointer.down(tester.getCenter(control));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(scale).scale, .94);

    await pointer.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
    await pointer.removePointer();
  });

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

  testWidgets('rapid timeline changes retarget without cross-fading', (
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

    await tester.tap(find.byKey(const Key('timeline-next-day')));
    await tester.pump(const Duration(milliseconds: 70));
    final incoming = find.byKey(const ValueKey('hourly-header-20260912'));
    expect(
      find.byKey(const ValueKey('hourly-header-20260911')),
      findsOneWidget,
    );
    expect(incoming, findsOneWidget);
    expect(
      find.ancestor(of: incoming, matching: find.byType(Opacity)),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('timeline-next-day')));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('hourly-header-20260912')),
      findsOneWidget,
    );

    Finder flowingDateLayers() => find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('flowing-date-layer-');
    });

    for (var index = 0; index < 10; index++) {
      await tester.tap(find.byKey(const Key('timeline-next-day')));
      await tester.pump(const Duration(milliseconds: 12));
      final keys = tester
          .widgetList(flowingDateLayers())
          .map((widget) => widget.key)
          .toList(growable: false);
      expect(keys.toSet(), hasLength(keys.length));
      expect(keys.length, lessThanOrEqualTo(4));
      expect(
        find.descendant(
          of: flowingDateLayers(),
          matching: find.byType(RepaintBoundary),
        ),
        findsNothing,
      );
    }
    for (var index = 0; index < 10; index++) {
      await tester.tap(find.byKey(const Key('timeline-previous-day')));
      await tester.pump(const Duration(milliseconds: 12));
      final keys = tester
          .widgetList(flowingDateLayers())
          .map((widget) => widget.key)
          .toList(growable: false);
      expect(keys.toSet(), hasLength(keys.length));
      expect(keys.length, lessThanOrEqualTo(4));
      expect(
        find.descendant(
          of: flowingDateLayers(),
          matching: find.byType(RepaintBoundary),
        ),
        findsNothing,
      );
    }
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('hourly-header-20260912')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('hourly-canvas-20260912')),
      findsOneWidget,
    );
    expect(flowingDateLayers(), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline slide reveals only the newly entering date', (
    tester,
  ) async {
    _useViewport(tester, const Size(1280, 800));
    final now = DateTime(2026, 9, 14, 13, 30);
    final sharedEvent = CalendarEvent(
      id: 'shared-during-navigation',
      title: 'Shared event',
      start: DateTime(2026, 9, 12, 9),
      end: DateTime(2026, 9, 12, 10),
      color: const Color(0xFFFF7B6F),
    );
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore([sharedEvent]),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
        clock: () => now,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('timeline-next-day')));
    await tester.pump(const Duration(milliseconds: 70));

    final incomingLayer = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('flowing-date-layer-') &&
          key.value.contains('hourly-canvas-20260912');
    });
    expect(incomingLayer, findsOneWidget);
    final layerClip = find.descendant(
      of: incomingLayer,
      matching: find.byWidgetPredicate(
        (widget) => widget is ClipRect && widget.clipper != null,
      ),
    );
    expect(layerClip, findsOneWidget);

    final viewportSize = tester.getSize(incomingLayer);
    final clipper = tester.widget<ClipRect>(layerClip).clipper!;
    final visibleIncoming = clipper.getClip(viewportSize);
    final dayWidth = viewportSize.width / 7;
    expect(visibleIncoming.width, greaterThan(0));
    expect(visibleIncoming.width, lessThan(dayWidth));
    expect(visibleIncoming.right, closeTo(viewportSize.width, .1));

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('hourly-canvas-20260912')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('single click starts at the containing whole hour', (
    tester,
  ) async {
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
    for (final target in [(12, 0), (23 * 60 + 48, 23 * 60)]) {
      final grid = tester.getRect(find.byKey(const Key('week-hourly-grid')));
      final point = Offset(
        grid.left + grid.width * .3,
        grid.top + grid.height * target.$1 / (24 * 60),
      );
      await tester.tapAt(point, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('event-title')),
        'At ${target.$2}',
      );
      await tester.ensureVisible(find.byKey(const Key('save-event')));
      await tester.tap(find.byKey(const Key('save-event')));
      await tester.pumpAndSettle();
      expect(store.savedEvents.last.startMinutes, target.$2);
      expect(store.savedEvents.last.durationMinutes, 60);
    }
    expect(store.savedEvents.last.end.hour, 0);
    expect(
      store.savedEvents.last.end.day,
      store.savedEvents.last.start.add(const Duration(days: 1)).day,
    );
    _restoreTestPlatform();
  });

  testWidgets('keeps the 24:00 boundary visible inside the viewport', (
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

    final grid = tester.getRect(find.byKey(const Key('week-hourly-grid')));
    final dayEnd = find.byKey(const Key('timeline-day-end'));
    final dayEndRect = tester.getRect(dayEnd);

    expect(
      find.descendant(of: dayEnd, matching: find.text('24:00')),
      findsOneWidget,
    );
    expect(dayEndRect.top, greaterThanOrEqualTo(grid.top));
    expect(dayEndRect.bottom, closeTo(grid.bottom, .1));
  });

  testWidgets('fits all 24 hours and magnifies a short event in place', (
    tester,
  ) async {
    _useViewport(tester, const Size(1280, 800));
    _useDesktopPlatform();
    final now = DateTime(2026, 9, 14, 13, 30);
    final event = CalendarEvent(
      id: 'focus-short',
      title: 'Quick check-in',
      start: DateTime(2026, 9, 11, 14),
      end: DateTime(2026, 9, 11, 14, 15),
      color: const Color(0xFFF1776C),
    );
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore([event]),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
        clock: () => now,
      ),
    );
    await tester.pumpAndSettle();

    final grid = tester.getRect(find.byKey(const Key('week-hourly-grid')));
    final viewport = tester.getRect(find.byKey(const Key('hourly-viewport')));
    expect(grid.height, closeTo(viewport.height, .1));
    expect(
      find.descendant(
        of: find.byKey(const Key('week-hourly-layout')),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );

    final surface = find.byKey(const Key('hourly-event-surface-focus-short-0'));
    final overviewHeight = tester.getRect(surface).height;
    await tester.tap(
      find.byKey(const Key('hourly-event-focus-short')),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-focus-lens')), findsOneWidget);
    expect(tester.getRect(surface).height, greaterThan(overviewHeight * 2));
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

  testWidgets('glass specular light follows and releases the pointer', (
    tester,
  ) async {
    _useViewport(tester, const Size(600, 400));
    await tester.pumpWidget(
      MaterialApp(
        theme: WeekraDesign.dark().copyWith(platform: TargetPlatform.windows),
        home: const Center(
          child: GlassSurface(
            key: Key('responsive-glass-test'),
            child: SizedBox(width: 220, height: 100),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = find.byKey(const Key('responsive-glass-test'));
    final specular = find.descendant(
      of: surface,
      matching: find.byKey(const Key('glass-specular-layer')),
    );
    expect(specular, findsOneWidget);
    final rect = tester.getRect(surface);
    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: rect.center);
    await pointer.moveTo(Offset(rect.right - 5, rect.top + 5));
    await tester.pumpAndSettle();

    RadialGradient gradient() {
      final box = tester.widget<DecoratedBox>(specular);
      return (box.decoration as BoxDecoration).gradient! as RadialGradient;
    }

    final followed = gradient().center as Alignment;
    expect(followed.x, greaterThan(.65));
    expect(followed.y, lessThan(-.65));

    await pointer.moveTo(const Offset(10, 10));
    await tester.pumpAndSettle();
    final released = gradient().center as Alignment;
    expect(released.x, closeTo(-.72, .01));
    expect(released.y, closeTo(-.92, .01));
    await pointer.removePointer();
  });

  testWidgets('touch platforms use the static glass profile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WeekraDesign.dark().copyWith(platform: TargetPlatform.android),
        home: const GlassSurface(
          key: Key('static-glass-test'),
          child: SizedBox(width: 220, height: 100),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('static-glass-test')),
        matching: find.byKey(const Key('glass-specular-layer')),
      ),
      findsNothing,
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

  testWidgets('applies and saves the chosen calendar arrangement', (
    tester,
  ) async {
    _useViewport(tester, const Size(1280, 800));
    final now = DateTime(2026, 9, 14, 13, 30);
    final settingsStore = _MemoryAppSettingsStore();
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore(),
        settingsStore: settingsStore,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
        clock: () => now,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-today-column-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-settings')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('hourly-header-20260913')),
      findsOneWidget,
    );
    expect(settingsStore.saved.calendar.todayColumn, 1);

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-anchor-week-start')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('calendar-week-start-${DateTime.wednesday}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-settings')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('hourly-header-20260909')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('timeline-next-day')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('hourly-header-20260916')),
      findsOneWidget,
    );
    expect(
      settingsStore.saved.calendar.anchorMode,
      CalendarAnchorMode.weekStart,
    );
    expect(settingsStore.saved.calendar.weekStartsOn, DateTime.wednesday);
  });

  testWidgets('renames and recolors a category throughout the calendar', (
    tester,
  ) async {
    _useViewport(tester, const Size(1280, 800));
    _useDesktopPlatform();
    final now = DateTime(2026, 9, 14, 13, 30);
    final event = CalendarEvent(
      id: 'custom-category-event',
      title: 'Study session',
      start: DateTime(2026, 9, 11, 9),
      end: DateTime(2026, 9, 11, 10),
      categoryId: 'category-1',
      color: EventCategories.colorFor('category-1'),
    );
    final settingsStore = _MemoryAppSettingsStore();
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore([event]),
        settingsStore: settingsStore,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
        clock: () => now,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-category-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('category-name-field-category-1')),
      'Course',
    );
    await tester.tap(find.byKey(const Key('category-color-choice-6')));
    await tester.tap(find.byKey(const Key('save-category-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-settings')));
    await tester.pumpAndSettle();

    expect(
      settingsStore.saved.categories.nameFor('category-1', 'fallback'),
      'Course',
    );
    expect(
      settingsStore.saved.categories.colorFor('category-1', Colors.black),
      const Color(0xFF5BB7D2),
    );
    await tester.tap(
      find.byKey(const Key('hourly-event-custom-category-event')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Course'), findsOneWidget);
    _restoreTestPlatform();
  });

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

  testWidgets('copies an overnight event from its continuation menu', (
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
    expect(find.byKey(const Key('event-context-copy')), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-context-copy')));
    await tester.pumpAndSettle();
    expect(store.savedEvents, hasLength(2));
    expect(
      store.savedEvents.map((event) => event.durationMinutes),
      everyElement(180),
    );
    expect(
      store.savedEvents.map((event) => event.title),
      everyElement(overnight.title),
    );
    expect(store.savedEvents[0].id, isNot(store.savedEvents[1].id));
    for (final event in store.savedEvents) {
      expect(event.end.day, isNot(event.start.day));
    }
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

  testWidgets('keeps a fixed today panel beside a wide overview', (
    tester,
  ) async {
    _useViewport(tester, const Size(1280, 800));
    _useDesktopPlatform();
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore([_eventAtStartOfWeek('Wide overview')]),
        locale: const Locale('en'),
        clock: () => DateTime(2026, 9, 16, 10, 32),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('week-layout-grid')));
    await tester.pumpAndSettle();

    final panel = find.byKey(const Key('overview-today-panel'));
    expect(panel, findsOneWidget);
    expect(
      find.descendant(of: panel, matching: find.textContaining('2026')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('overview-day-column')).first).width,
      64,
    );
    expect(tester.takeException(), isNull);
    _restoreTestPlatform();
  });

  testWidgets('drops the today panel on a narrow overview', (tester) async {
    _useViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore([_eventAtStartOfWeek('Narrow overview')]),
        locale: const Locale('en'),
        clock: () => DateTime(2026, 9, 16, 10, 32),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('week-grid-layout')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byKey(const Key('overview-today-panel')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses compact marker-led event rows in the overview', (
    tester,
  ) async {
    _useViewport(tester, const Size(390, 844));
    final event = _eventOnToday('Compact overview event');
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore([event]),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(Key('overview-event-${event.id}'));
    final marker = find.byKey(Key('overview-event-marker-${event.id}'));
    expect(row.hitTestable(), findsOneWidget);
    // Font metrics vary by platform, but the agenda row should remain close to
    // the 44 px touch target instead of expanding into a filled event card.
    expect(tester.getSize(row).height, lessThanOrEqualTo(60));
    expect(tester.getSize(marker), const Size(4, 36));
    expect(tester.takeException(), isNull);
  });

  testWidgets('alternates day surfaces and keeps the today boundary', (
    tester,
  ) async {
    _useViewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore(),
        locale: const Locale('en'),
        clock: () => DateTime(2026, 9, 17, 10),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    BoxDecoration decorationFor(int day) {
      final surface = find.byKey(
        Key('overview-day-surface-2026-9-$day'),
      );
      return tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
    }

    final today = decorationFor(17);
    final tomorrow = decorationFor(18);
    final dayAfterTomorrow = decorationFor(19);
    expect(today.color, isNot(tomorrow.color));
    expect(tomorrow.color, isNot(dayAfterTomorrow.color));
    expect(today.color, dayAfterTomorrow.color);
    final todayBorder = today.border! as Border;
    expect(todayBorder.top.width, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the overview streams past a single week', (tester) async {
    _useViewport(tester, const Size(1280, 800));
    _useDesktopPlatform();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final beyondWeek = today.add(const Duration(days: 20));
    await tester.pumpWidget(
      WeekraApp(
        eventStore: _MemoryEventStore([
          _eventOnToday('Stream fixture'),
          CalendarEvent(
            id: 'beyond-the-week',
            title: 'Beyond the week',
            start: beyondWeek.add(const Duration(hours: 9)),
            end: beyondWeek.add(const Duration(hours: 10)),
            color: const Color(0xFF6E8CA8),
          ),
        ]),
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('week-layout-grid')));
    await tester.pumpAndSettle();

    // Today anchors the stream, so it is on screen without scrolling.
    expect(find.text('Stream fixture').hitTestable(), findsOneWidget);
    // A day three weeks out lies past a single week and is not visible yet.
    expect(find.text('Beyond the week').hitTestable(), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Beyond the week'),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('week-grid-layout')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();

    // The stream keeps going across the week boundary.
    expect(find.text('Beyond the week').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    _restoreTestPlatform();
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

  testWidgets('draft creation keeps the 24-hour scale and events stationary', (
    tester,
  ) async {
    _useViewport(tester, const Size(1280, 800));
    _useDesktopPlatform();
    final store = _MemoryEventStore([
      _eventAtStartOfWeek('Stable during creation'),
    ]);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    final existing = find.byKey(
      const Key('hourly-event-Stable during creation'),
    );
    final before = tester.getRect(existing);
    final grid = tester.getRect(find.byKey(const Key('week-hourly-grid')));
    await tester.tapAt(
      Offset(grid.left + grid.width * .72, grid.top + grid.height * .43),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    final after = tester.getRect(existing);
    expect(find.byKey(const Key('draft-event')), findsOneWidget);
    expect(find.byKey(const Key('timeline-focus-lens')), findsNothing);
    expect(after.top, closeTo(before.top, .1));
    expect(after.height, closeTo(before.height, .1));

    await tester.tap(find.byKey(const Key('cancel-event-editor')));
    await tester.pumpAndSettle();
    _restoreTestPlatform();
  });

  testWidgets(
    'clicking the grid around an editor cancels without fallthrough',
    (tester) async {
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

      final grid = tester.getRect(find.byKey(const Key('week-hourly-grid')));
      await tester.tapAt(
        Offset(grid.left + grid.width * .22, grid.top + grid.height * .32),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draft-event')), findsOneWidget);
      expect(find.byKey(const Key('cancel-event-editor')), findsOneWidget);

      await tester.tapAt(
        Offset(grid.right - 12, grid.bottom - 30),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cancel-event-editor')), findsNothing);
      expect(find.byKey(const Key('draft-event')), findsNothing);
      expect(store.savedEvents, isEmpty);
      _restoreTestPlatform();
    },
  );

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
    const dragStartMinute = 8 * 60 + 15;
    final gesture = await tester.startGesture(
      Offset(
        gridRect.left + gridRect.width * 0.2,
        gridRect.top + gridRect.height * dragStartMinute / (24 * 60),
      ),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 120));
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
    expect(store.savedEvents.single.startMinutes, dragStartMinute);
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
    expect(moved.start.minute, 15);
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

  testWidgets('right click opens a bounded action and category menu', (
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

    final edit = find.byKey(const Key('event-context-edit'));
    final copy = find.byKey(const Key('event-context-copy'));
    final delete = find.byKey(const Key('event-context-delete'));
    final lastCategory = find.byKey(
      const Key('event-context-category-category-6'),
    );
    expect(edit, findsOneWidget);
    expect(copy, findsOneWidget);
    expect(delete, findsOneWidget);
    expect(lastCategory, findsOneWidget);
    expect(tester.getRect(edit).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(lastCategory).bottom, lessThanOrEqualTo(760));

    await tester.tap(
      find.byKey(const Key('event-context-category-category-3')),
    );
    await tester.pumpAndSettle();
    expect(store.savedEvents.single.categoryId, 'category-3');
    expect(
      store.savedEvents.single.color,
      EventCategories.colorFor('category-3'),
    );
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

  testWidgets('resizes directly from an event edge without visible handles', (
    tester,
  ) async {
    _useViewport(tester, const Size(900, 1000));
    _useDesktopPlatform();
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

    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
    expect(find.byKey(const Key('event-resize-end-Resize me')), findsNothing);
    final surface = tester.getRect(
      find.byKey(const Key('hourly-event-surface-Resize me-0')),
    );
    final resizeGesture = await tester.startGesture(
      Offset(surface.center.dx, surface.bottom - 2),
      kind: PointerDeviceKind.mouse,
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
    _restoreTestPlatform();
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
    _useDesktopPlatform();
    final store = _MemoryEventStore([_event('Remove me')]);
    await tester.pumpWidget(
      WeekraApp(
        eventStore: store,
        locale: const Locale('en'),
        enableAutomaticUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('hourly-event-Remove me')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event-context-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Delete event?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-event')));
    await tester.pumpAndSettle();

    expect(store.savedEvents, isEmpty);
    expect(find.text('Remove me'), findsNothing);
    _restoreTestPlatform();
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
    // The overview no longer prints a placeholder for empty days.
    expect(find.text('暂无安排'), findsNothing);

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
      _eventOnToday(
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

class _MemoryAppSettingsStore implements AppSettingsStore {
  _MemoryAppSettingsStore() : saved = const AppSettings();

  AppSettings saved;
  int saveCalls = 0;

  @override
  Future<AppSettings> load() async => saved;

  @override
  Future<void> save(AppSettings settings) async {
    saveCalls += 1;
    saved = settings;
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

/// The overview is a continuous stream anchored on today, so fixtures that must
/// be visible without scrolling belong on today rather than earlier in the week.
CalendarEvent _eventOnToday(String title) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return CalendarEvent(
    id: title,
    title: title,
    start: today.add(const Duration(hours: 9)),
    end: today.add(const Duration(hours: 10)),
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
