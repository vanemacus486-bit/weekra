import 'package:flutter/material.dart';

enum WeekraTheme { ember, lagoon, graphite }

extension WeekraThemeStyle on WeekraTheme {
  Color get accent => switch (this) {
        WeekraTheme.ember => const Color(0xFFFF6B5F),
        WeekraTheme.lagoon => const Color(0xFF63C8C2),
        WeekraTheme.graphite => const Color(0xFFC7D0D9),
      };

  List<Color> get background => switch (this) {
        WeekraTheme.ember => const [Color(0xFF33181B), Color(0xFF111318), Color(0xFF090A0D)],
        WeekraTheme.lagoon => const [Color(0xFF123238), Color(0xFF101A1D), Color(0xFF080C0E)],
        WeekraTheme.graphite => const [Color(0xFF30343A), Color(0xFF17191D), Color(0xFF090A0C)],
      };
}
