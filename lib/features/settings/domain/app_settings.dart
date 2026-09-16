import 'package:flutter/material.dart';
import 'package:weekra/app/weekra_theme.dart';

enum WeekraLanguage { system, english, chinese }

enum CalendarAnchorMode { today, weekStart }

class CalendarViewSettings {
  const CalendarViewSettings({
    this.anchorMode = CalendarAnchorMode.today,
    this.todayColumn = 3,
    this.weekStartsOn = DateTime.monday,
  });

  final CalendarAnchorMode anchorMode;
  final int todayColumn;
  final int weekStartsOn;

  CalendarViewSettings copyWith({
    CalendarAnchorMode? anchorMode,
    int? todayColumn,
    int? weekStartsOn,
  }) {
    return CalendarViewSettings(
      anchorMode: anchorMode ?? this.anchorMode,
      todayColumn: (todayColumn ?? this.todayColumn).clamp(0, 6).toInt(),
      weekStartsOn: (weekStartsOn ?? this.weekStartsOn)
          .clamp(DateTime.monday, DateTime.sunday)
          .toInt(),
    );
  }

  Map<String, Object> toJson() => {
    'anchorMode': anchorMode.name,
    'todayColumn': todayColumn,
    'weekStartsOn': weekStartsOn,
  };

  factory CalendarViewSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CalendarViewSettings();
    }
    return CalendarViewSettings(
      anchorMode:
          CalendarAnchorMode.values
              .where((value) => value.name == json['anchorMode'])
              .firstOrNull ??
          CalendarAnchorMode.today,
      todayColumn: ((json['todayColumn'] as num?)?.toInt() ?? 3)
          .clamp(0, 6)
          .toInt(),
      weekStartsOn: ((json['weekStartsOn'] as num?)?.toInt() ?? DateTime.monday)
          .clamp(DateTime.monday, DateTime.sunday)
          .toInt(),
    );
  }
}

class CategoryCustomization {
  const CategoryCustomization({this.name, this.colorValue});

  final String? name;
  final int? colorValue;

  Map<String, Object> toJson() => {
    if (name case final name?) 'name': name,
    if (colorValue case final color?) 'color': color,
  };

  factory CategoryCustomization.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'];
    final normalizedName = rawName is String ? rawName.trim() : '';
    return CategoryCustomization(
      name: normalizedName.isEmpty ? null : normalizedName,
      colorValue: (json['color'] as num?)?.toInt(),
    );
  }
}

class CategorySettings {
  const CategorySettings({this.customizations = const {}});

  final Map<String, CategoryCustomization> customizations;

  String nameFor(String categoryId, String fallback) {
    return customizations[categoryId]?.name ?? fallback;
  }

  Color colorFor(String categoryId, Color fallback) {
    final value = customizations[categoryId]?.colorValue;
    return value == null ? fallback : Color(value);
  }

  CategorySettings customize(
    String categoryId, {
    required String name,
    required Color color,
  }) {
    final normalizedName = name.trim();
    return CategorySettings(
      customizations: {
        ...customizations,
        categoryId: CategoryCustomization(
          name: normalizedName.isEmpty ? null : normalizedName,
          colorValue: color.toARGB32(),
        ),
      },
    );
  }

  Map<String, Object> toJson() => {
    for (final entry in customizations.entries) entry.key: entry.value.toJson(),
  };

  factory CategorySettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CategorySettings();
    }
    return CategorySettings(
      customizations: {
        for (final entry in json.entries)
          if (entry.value case final Map<String, dynamic> value)
            entry.key: CategoryCustomization.fromJson(value),
      },
    );
  }
}

class AppSettings {
  const AppSettings({
    this.theme = WeekraTheme.ember,
    this.language = WeekraLanguage.system,
    this.calendar = const CalendarViewSettings(),
    this.categories = const CategorySettings(),
  });

  final WeekraTheme theme;
  final WeekraLanguage language;
  final CalendarViewSettings calendar;
  final CategorySettings categories;

  Locale? get locale => switch (language) {
    WeekraLanguage.system => null,
    WeekraLanguage.english => const Locale('en'),
    WeekraLanguage.chinese => const Locale('zh'),
  };

  AppSettings copyWith({
    WeekraTheme? theme,
    WeekraLanguage? language,
    CalendarViewSettings? calendar,
    CategorySettings? categories,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      calendar: calendar ?? this.calendar,
      categories: categories ?? this.categories,
    );
  }

  Map<String, Object> toJson() => {
    'theme': theme.name,
    'language': language.name,
    'calendar': calendar.toJson(),
    'categories': categories.toJson(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    theme:
        WeekraTheme.values
            .where((value) => value.name == json['theme'])
            .firstOrNull ??
        WeekraTheme.ember,
    language:
        WeekraLanguage.values
            .where((value) => value.name == json['language'])
            .firstOrNull ??
        WeekraLanguage.system,
    calendar: CalendarViewSettings.fromJson(
      json['calendar'] as Map<String, dynamic>?,
    ),
    categories: CategorySettings.fromJson(
      json['categories'] as Map<String, dynamic>?,
    ),
  );
}
