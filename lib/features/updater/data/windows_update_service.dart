import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:weekra/features/updater/domain/app_update.dart';
import 'package:weekra/features/updater/domain/update_service.dart';

const _currentVersion = String.fromEnvironment(
  'WEEKRA_VERSION',
  defaultValue: '0.2.0',
);
const _manifestUrl = String.fromEnvironment(
  'WEEKRA_UPDATE_MANIFEST_URL',
  defaultValue:
      'https://github.com/vanemacus486-bit/weekra/releases/latest/download/update.json',
);

class WindowsUpdateService implements UpdateService {
  WindowsUpdateService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Future<AppUpdate?> checkForUpdate() async {
    final manifestUri = Uri.parse(_manifestUrl);
    _requireHttps(manifestUri);
    final request = await _httpClient.getUrl(manifestUri).timeout(
      const Duration(seconds: 12),
    );
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Weekra/$_currentVersion',
    );
    final response = await request.close().timeout(const Duration(seconds: 12));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'Update manifest returned HTTP ${response.statusCode}.',
        uri: manifestUri,
      );
    }
    final body = await utf8.decoder.bind(response).join();
    final manifest = jsonDecode(body);
    if (manifest is! Map<String, dynamic>) {
      throw const FormatException('Update manifest must be an object.');
    }

    final version = manifest['version'];
    final windows = manifest['windows'];
    if (version is! String || windows is! Map<String, dynamic>) {
      throw const FormatException('Update manifest is missing Windows data.');
    }
    if (!isNewerVersion(version, _currentVersion)) {
      return null;
    }

    final url = windows['url'];
    final expectedHash = windows['sha256'];
    if (url is! String ||
        expectedHash is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(expectedHash)) {
      throw const FormatException('Update download metadata is invalid.');
    }
    final downloadUri = Uri.parse(url);
    _requireHttps(downloadUri);
    return AppUpdate(
      version: version,
      downloadUri: downloadUri,
      sha256: expectedHash.toLowerCase(),
    );
  }

  @override
  Future<void> downloadAndInstall(
    AppUpdate update, {
    UpdateProgressCallback? onProgress,
  }) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Automatic installation is available on Windows.');
    }

    _requireHttps(update.downloadUri);
    final temporaryDirectory = await getTemporaryDirectory();
    final workDirectory = await Directory(
      '${temporaryDirectory.path}\\weekra-update-${DateTime.now().millisecondsSinceEpoch}',
    ).create(recursive: true);
    final archive = File('${workDirectory.path}\\weekra-update.zip');

    try {
      await _download(update.downloadUri, archive, onProgress);
      final actualHash = await sha256.bind(archive.openRead()).first;
      if (actualHash.toString() != update.sha256) {
        throw const FormatException(
          'The downloaded update failed verification.',
        );
      }
      onProgress?.call(1);
      await _launchInstallerScript(workDirectory, archive);
    } on Object {
      if (await workDirectory.exists()) {
        await workDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> _download(
    Uri uri,
    File destination,
    UpdateProgressCallback? onProgress,
  ) async {
    final request = await _httpClient.getUrl(uri).timeout(
      const Duration(seconds: 15),
    );
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Weekra/$_currentVersion',
    );
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'Update download returned HTTP ${response.statusCode}.',
        uri: uri,
      );
    }

    final sink = destination.openWrite();
    var received = 0;
    final total = response.contentLength;
    try {
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(total > 0 ? received / total : null);
      }
    } finally {
      await sink.close();
    }
  }

  Future<void> _launchInstallerScript(
    Directory workDirectory,
    File archive,
  ) async {
    final executable = File(Platform.resolvedExecutable);
    final installDirectory = executable.parent.path;
    final stagingDirectory = '${workDirectory.path}\\payload';
    final logPath = '${workDirectory.path}\\update.log';
    final script = File('${workDirectory.path}\\install-update.ps1');
    final scriptContents = '''
\$ErrorActionPreference = 'Stop'
\$archive = '${_powerShellLiteral(archive.path)}'
\$staging = '${_powerShellLiteral(stagingDirectory)}'
\$install = '${_powerShellLiteral(installDirectory)}'
\$executable = '${_powerShellLiteral(executable.path)}'
\$log = '${_powerShellLiteral(logPath)}'

try {
  Wait-Process -Id $pid -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath \$staging) {
    Remove-Item -LiteralPath \$staging -Recurse -Force
  }
  Expand-Archive -LiteralPath \$archive -DestinationPath \$staging -Force
  & robocopy.exe \$staging \$install /E /R:3 /W:1 /NFL /NDL /NJH /NJS
  if (\$LASTEXITCODE -ge 8) {
    throw "Robocopy failed with exit code \$LASTEXITCODE."
  }
  Start-Process -FilePath \$executable -WorkingDirectory \$install
} catch {
  \$_ | Out-File -LiteralPath \$log -Encoding UTF8
  Start-Process -FilePath \$executable -WorkingDirectory \$install
}
''';
    await script.writeAsString(scriptContents, flush: true);
    await Process.start(
      'powershell.exe',
      [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        script.path,
      ],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  String _powerShellLiteral(String value) => value.replaceAll("'", "''");

  void _requireHttps(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Update URLs must use HTTPS.');
    }
  }
}
