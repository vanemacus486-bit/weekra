import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:weekra/app/app_version.dart';
import 'package:weekra/features/updater/domain/app_update.dart';
import 'package:weekra/features/updater/domain/update_service.dart';

const _currentVersion = String.fromEnvironment(
  'WEEKRA_VERSION',
  defaultValue: appVersion,
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
    final request = await _httpClient
        .getUrl(manifestUri)
        .timeout(const Duration(seconds: 12));
    request.headers.set(HttpHeaders.userAgentHeader, 'Weekra/$_currentVersion');
    final response = await request.close().timeout(const Duration(seconds: 12));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'Update manifest returned HTTP ${response.statusCode}.',
        uri: manifestUri,
      );
    }
    final body = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 20));
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

    // New clients use the verified installer while 0.5.4 and earlier keep
    // consuming the portable archive fields from the same manifest.
    final url = windows['installerUrl'] ?? windows['url'];
    final expectedHash =
        windows['installerSha256'] ?? windows['sha256'];
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
    final installer = File(
      '${workDirectory.path}\\weekra-setup-x64.exe',
    );

    try {
      await _download(update.downloadUri, installer, onProgress);
      final actualHash = await sha256.bind(installer.openRead()).first;
      if (actualHash.toString() != update.sha256) {
        throw const FormatException(
          'The downloaded update failed verification.',
        );
      }
      onProgress?.call(1);
      await _launchInstallerScript(workDirectory, installer);
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
    final request = await _httpClient
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.headers.set(HttpHeaders.userAgentHeader, 'Weekra/$_currentVersion');
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
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
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
    File installer,
  ) async {
    final executable = File(Platform.resolvedExecutable);
    final installDirectory = executable.parent.path;
    final logPath = '${workDirectory.path}\\update.log';
    final script = File('${workDirectory.path}\\install-update.ps1');
    // PowerShell's case-insensitive $PID variable identifies PowerShell itself.
    // Keep the Weekra process ID separate so the helper can safely outlive it.
    final scriptContents = buildWindowsInstallerScript(
      installerPath: installer.path,
      installDirectory: installDirectory,
      executablePath: executable.path,
      logPath: logPath,
      appProcessId: pid,
    );
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

  void _requireHttps(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Update URLs must use HTTPS.');
    }
  }
}

String buildWindowsInstallerScript({
  required String installerPath,
  required String installDirectory,
  required String executablePath,
  required String logPath,
  required int appProcessId,
}) {
  String literal(String value) => value.replaceAll("'", "''");

  return '''
\$ErrorActionPreference = 'Stop'
\$installer = '${literal(installerPath)}'
\$install = '${literal(installDirectory)}'
\$executable = '${literal(executablePath)}'
\$log = '${literal(logPath)}'
\$appPid = $appProcessId

try {
  Wait-Process -Id \$appPid -ErrorAction SilentlyContinue
  \$arguments = @(
    '/VERYSILENT'
    '/SUPPRESSMSGBOXES'
    '/NORESTART'
    '/SP-'
    ('/DIR="' + \$install + '"')
  )
  \$process = Start-Process -FilePath \$installer -ArgumentList \$arguments -Wait -PassThru
  if (\$process.ExitCode -ne 0) {
    throw "Weekra installer failed with exit code \$(\$process.ExitCode)."
  }
  if (-not (Test-Path -LiteralPath \$executable)) {
    throw 'Weekra executable was not found after installation.'
  }
  Start-Process -FilePath \$executable -WorkingDirectory \$install
} catch {
  \$_ | Out-File -LiteralPath \$log -Encoding UTF8
  if (Test-Path -LiteralPath \$executable) {
    Start-Process -FilePath \$executable -WorkingDirectory \$install
  }
}
''';
}
