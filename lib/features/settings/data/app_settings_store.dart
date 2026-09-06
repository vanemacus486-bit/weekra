import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:weekra/features/settings/domain/app_settings.dart';

abstract interface class AppSettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class JsonAppSettingsStore implements AppSettingsStore {
  const JsonAppSettingsStore();

  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/weekra_settings_v1.json');

  @override
  Future<AppSettings> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const AppSettings();
      return AppSettings.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } on Object {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
  }
}
