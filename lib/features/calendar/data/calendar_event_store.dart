import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:weekra/features/calendar/domain/calendar_event.dart';

abstract interface class CalendarEventStore {
  Future<List<CalendarEvent>?> load();

  Future<void> save(List<CalendarEvent> events);
}

typedef DirectoryProvider = Future<Directory> Function();

class JsonCalendarEventStore implements CalendarEventStore {
  const JsonCalendarEventStore({this.directoryProvider});

  static const _fileName = 'weekra_events_v1.json';

  final DirectoryProvider? directoryProvider;

  @override
  Future<List<CalendarEvent>?> load() async {
    final file = await _eventsFile();
    if (!await file.exists()) {
      return null;
    }

    final contents = await file.readAsString();
    final decoded = jsonDecode(contents) as List<dynamic>;
    return decoded
        .map(
          (item) => CalendarEvent.fromJson(
            Map<String, Object?>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<void> save(List<CalendarEvent> events) async {
    final file = await _eventsFile();
    final contents = jsonEncode(events.map((event) => event.toJson()).toList());
    await file.writeAsString(contents, flush: true);
  }

  Future<File> _eventsFile() async {
    final provider = directoryProvider ?? getApplicationDocumentsDirectory;
    final directory = await provider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }
}
