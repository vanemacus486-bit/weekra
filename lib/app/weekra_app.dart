import 'package:flutter/material.dart';
import 'package:weekra/features/calendar/data/calendar_event_store.dart';
import 'package:weekra/features/calendar/presentation/week_screen.dart';

class WeekraApp extends StatelessWidget {
  const WeekraApp({
    super.key,
    this.eventStore = const JsonCalendarEventStore(),
    this.fontFamily,
  });

  final CalendarEventStore eventStore;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF6B5F);

    return MaterialApp(
      title: 'Weekra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: const Color(0xFF15171C),
        ),
        scaffoldBackgroundColor: Colors.transparent,
        useMaterial3: true,
      ),
      home: WeekScreen(eventStore: eventStore),
    );
  }
}
