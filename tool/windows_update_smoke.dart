import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:weekra/features/updater/data/windows_update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final service = WindowsUpdateService();
    final update = await service.checkForUpdate();
    if (update == null) {
      stderr.writeln('The update smoke build did not find a newer release.');
      exitCode = 2;
      return;
    }
    stdout.writeln('Installing Weekra ${update.version}.');
    await service.downloadAndInstall(update);
  } on Object catch (error, stackTrace) {
    stderr
      ..writeln(error)
      ..writeln(stackTrace);
    exitCode = 1;
  }
}
