import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:weekra/features/updater/data/windows_update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final trace = File(
    '${Platform.environment['RUNNER_TEMP'] ?? Directory.systemTemp.path}'
    '${Platform.pathSeparator}weekra-update-smoke.log',
  );
  Future<void> record(String message) => trace.writeAsString(
    '[${DateTime.now().toUtc().toIso8601String()}] $message\n',
    mode: FileMode.append,
    flush: true,
  );
  try {
    await record('Checking the production update manifest.');
    final service = WindowsUpdateService();
    final update = await service.checkForUpdate();
    if (update == null) {
      await record('No newer release was returned.');
      exit(2);
    }
    await record('Found Weekra ${update.version}; downloading installer.');
    await service.downloadAndInstall(update);
  } on Object catch (error, stackTrace) {
    await record('Smoke client failed: $error\n$stackTrace');
    exit(1);
  }
}
