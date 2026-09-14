import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/features/updater/data/windows_update_service.dart';

void main() {
  test('installer waits for the Weekra process instead of PowerShell itself', () {
    final script = buildWindowsInstallerScript(
      archivePath: r'C:\Temp\weekra-update.zip',
      stagingDirectory: r'C:\Temp\payload',
      installDirectory: r'C:\Users\test\AppData\Local\Programs\Weekra',
      executablePath:
          r'C:\Users\test\AppData\Local\Programs\Weekra\weekra.exe',
      logPath: r'C:\Temp\update.log',
      appProcessId: 4242,
    );

    expect(script, contains(r'$appPid = 4242'));
    expect(script, contains(r'Wait-Process -Id $appPid'));
    expect(script, isNot(contains(r'Wait-Process -Id $pid')));
  });

  test('installer safely quotes paths passed to PowerShell', () {
    final script = buildWindowsInstallerScript(
      archivePath: r"C:\Users\O'Brien\weekra-update.zip",
      stagingDirectory: r'C:\Temp\payload',
      installDirectory: r"C:\Users\O'Brien\Weekra",
      executablePath: r"C:\Users\O'Brien\Weekra\weekra.exe",
      logPath: r'C:\Temp\update.log',
      appProcessId: 7,
    );

    expect(script, contains(r"C:\Users\O''Brien\weekra-update.zip"));
    expect(script, contains(r"C:\Users\O''Brien\Weekra\weekra.exe"));
  });
}
