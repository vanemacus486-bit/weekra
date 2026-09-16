import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/app/weekra_theme.dart';
import 'package:weekra/features/settings/domain/app_settings.dart';

void main() {
  test('keeps compatible defaults for settings saved before 0.6.1', () {
    final settings = AppSettings.fromJson({
      'theme': 'lagoon',
      'language': 'chinese',
    });

    expect(settings.theme, WeekraTheme.lagoon);
    expect(settings.language, WeekraLanguage.chinese);
    expect(settings.calendar.anchorMode, CalendarAnchorMode.today);
    expect(settings.calendar.todayColumn, 3);
    expect(settings.calendar.weekStartsOn, DateTime.monday);
    expect(settings.categories.customizations, isEmpty);
  });

  test('round-trips calendar arrangement and category appearance', () {
    final original = AppSettings(
      calendar: const CalendarViewSettings(
        anchorMode: CalendarAnchorMode.weekStart,
        todayColumn: 5,
        weekStartsOn: DateTime.sunday,
      ),
      categories: const CategorySettings().customize(
        'category-2',
        name: 'Study',
        color: const Color(0xFF5BB7D2),
      ),
    );

    final restored = AppSettings.fromJson(original.toJson());

    expect(restored.calendar.anchorMode, CalendarAnchorMode.weekStart);
    expect(restored.calendar.todayColumn, 5);
    expect(restored.calendar.weekStartsOn, DateTime.sunday);
    expect(restored.categories.nameFor('category-2', 'fallback'), 'Study');
    expect(
      restored.categories.colorFor('category-2', Colors.black),
      const Color(0xFF5BB7D2),
    );
  });
}
