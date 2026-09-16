import 'package:flutter_test/flutter_test.dart';
import 'package:weekra/features/updater/data/windows_proxy.dart';
import 'package:weekra/features/updater/data/windows_update_service.dart';

void main() {
  test('verified installer closes, replaces, logs, and restarts Weekra', () {
    final arguments = windowsInstallerArguments(
      installDirectory: r'C:\Users\test\AppData\Local\Programs\Weekra',
      installerLogPath:
          r'C:\Users\test\AppData\Local\Weekra\Logs\update.log.installer',
    );

    expect(arguments, contains('/VERYSILENT'));
    expect(arguments, contains('/SUPPRESSMSGBOXES'));
    expect(arguments, contains('/NORESTART'));
    expect(arguments, contains('/CLOSEAPPLICATIONS'));
    expect(arguments, contains('/RESTARTAPPLICATIONS'));
    expect(
      arguments,
      contains(r'/DIR=C:\Users\test\AppData\Local\Programs\Weekra'),
    );
    expect(
      arguments,
      contains(
        r'/LOG=C:\Users\test\AppData\Local\Weekra\Logs\update.log.installer',
      ),
    );
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
