import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/features/updater/data/windows_update_service.dart';

void main() {
  test('installer waits for Weekra before running the verified setup', () {
    final script = buildWindowsInstallerScript(
      installerPath: r'C:\Temp\weekra-setup-x64.exe',
      installDirectory: r'C:\Users\test\AppData\Local\Programs\Weekra',
      executablePath:
          r'C:\Users\test\AppData\Local\Programs\Weekra\weekra.exe',
      logPath: r'C:\Temp\update.log',
      appProcessId: 4242,
    );

    expect(script, contains(r'$appPid = 4242'));
    expect(script, contains(r'Wait-Process -Id $appPid'));
    expect(script, isNot(contains(r'Wait-Process -Id $pid')));
    expect(
      script,
      contains(r'Start-Process -FilePath $installer '
          r'-ArgumentList $arguments -Wait -PassThru'),
    );
    expect(script, contains(r'/VERYSILENT'));
    expect(script, contains(r'/SUPPRESSMSGBOXES'));
    expect(script, contains(r'/NORESTART'));
    expect(script, contains(r'$process.ExitCode -ne 0'));
    expect(script, isNot(contains('Expand-Archive')));
    expect(script, isNot(contains('robocopy')));
  });

  test('installer safely quotes paths passed to PowerShell', () {
    final script = buildWindowsInstallerScript(
      installerPath: r"C:\Users\O'Brien\weekra-setup-x64.exe",
      installDirectory: r"C:\Users\O'Brien\Weekra",
      executablePath: r"C:\Users\O'Brien\Weekra\weekra.exe",
      logPath: r'C:\Temp\update.log',
      appProcessId: 7,
    );

    expect(script, contains(r"C:\Users\O''Brien\weekra-setup-x64.exe"));
    expect(script, contains(r"C:\Users\O''Brien\Weekra\weekra.exe"));
    expect(script, contains(r"""('/DIR="' + $install + '"')"""));
  });
}
