import 'package:flutter/material.dart';
import 'package:weekra/app/weekra_theme.dart';

enum WeekraLanguage { system, english, chinese }

class AppSettings {
  const AppSettings({this.theme = WeekraTheme.ember, this.language = WeekraLanguage.system});

  final WeekraTheme theme;
  final WeekraLanguage language;

  Locale? get locale => switch (language) {
        WeekraLanguage.system => null,
        WeekraLanguage.english => const Locale('en'),
        WeekraLanguage.chinese => const Locale('zh'),
      };

  AppSettings copyWith({WeekraTheme? theme, WeekraLanguage? language}) =>
      AppSettings(theme: theme ?? this.theme, language: language ?? this.language);

  Map<String, Object> toJson() => {'theme': theme.name, 'language': language.name};

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        theme: WeekraTheme.values.where((v) => v.name == json['theme']).firstOrNull ?? WeekraTheme.ember,
        language: WeekraLanguage.values.where((v) => v.name == json['language']).firstOrNull ?? WeekraLanguage.system,
      );
}
