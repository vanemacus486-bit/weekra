import 'package:flutter/material.dart';

void main() {
  runApp(const WeekraApp());
}

class WeekraApp extends StatelessWidget {
  const WeekraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weekra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEF6A5B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const WeekPlaceholderScreen(),
    );
  }
}

class WeekPlaceholderScreen extends StatelessWidget {
  const WeekPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekra')),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_view_week_outlined, size: 64),
            SizedBox(height: 16),
            Text('Your week, clearly.'),
          ],
        ),
      ),
    );
  }
}

