import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/features/updater/data/windows_proxy.dart';
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
    expect(script, contains('Update installed successfully.'));
    expect(script, contains('Update installation failed.'));
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

  test('parses single and protocol-specific Windows proxies', () {
    expect(
      windowsProxyDirective('127.0.0.1:7890'),
      'PROXY 127.0.0.1:7890; DIRECT',
    );
    expect(
      windowsProxyDirective(
        'http=127.0.0.1:8080;https=127.0.0.1:8443;socks=127.0.0.1:1080',
      ),
      'PROXY 127.0.0.1:8443; DIRECT',
    );
    expect(
      windowsProxyDirective('https://proxy.example:443'),
      'PROXY proxy.example:443; DIRECT',
    );
    expect(windowsProxyDirective(''), isNull);
  });

  test('prefers the installer metadata in a compatible manifest', () {
    final archiveHash = List.filled(64, 'a').join();
    final installerHash = List.filled(64, 'b').join();
    final update = parseUpdateManifest(
      '''
      {
        "version": "0.6.9",
        "windows": {
          "url": "https://example.com/weekra.zip",
          "sha256": "$archiveHash",
          "installerUrl": "https://example.com/weekra.exe",
          "installerSha256": "$installerHash"
        }
      }
      ''',
      currentVersion: '0.6.8',
    );

    expect(update?.version, '0.6.9');
    expect(update?.downloadUri, Uri.parse('https://example.com/weekra.exe'));
    expect(update?.sha256, installerHash);
  });

  test('ignores a manifest that is not newer', () {
    final installerHash = List.filled(64, 'b').join();
    final update = parseUpdateManifest(
      '''
      {
        "version": "0.6.8",
        "windows": {
          "installerUrl": "https://example.com/weekra.exe",
          "installerSha256": "$installerHash"
        }
      }
      ''',
      currentVersion: '0.6.8',
    );
    expect(update, isNull);
  });
}
