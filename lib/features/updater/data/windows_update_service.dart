import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:weekra/app/app_version.dart';
import 'package:weekra/features/updater/data/windows_proxy.dart';
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
  WindowsUpdateService({HttpClient? httpClient}) : _httpClient = httpClient;

  HttpClient? _httpClient;
  Future<HttpClient>? _configuredClient;

  Future<HttpClient> _client() {
    final injected = _httpClient;
    if (injected != null) return Future.value(injected);
    return _configuredClient ??= _createConfiguredClient();
  }

  Future<HttpClient> _createConfiguredClient() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    final systemProxy = await readWindowsProxyDirective();
    client.findProxy = (uri) {
      final environmentProxy = HttpClient.findProxyFromEnvironment(uri);
      if (environmentProxy != 'DIRECT') {
        return environmentProxy.contains('DIRECT')
            ? environmentProxy
            : '$environmentProxy; DIRECT';
      }
      return systemProxy ?? 'DIRECT';
    };
    _httpClient = client;
    return client;
  }

  @override
  Future<AppUpdate?> checkForUpdate() async {
    final manifestUri = Uri.parse(_manifestUrl);
    _requireHttps(manifestUri);
    try {
      final response = await _openGet(manifestUri, attempts: 3);
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
          .timeout(const Duration(seconds: 45));
      return parseUpdateManifest(body, currentVersion: _currentVersion);
    } on Object catch (error, stackTrace) {
      await _writeDiagnostic('check', error, stackTrace);
      rethrow;
    }
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
      await _download(update.downloadUri, installer, onProgress, attempts: 3);
      final actualHash = await sha256.bind(installer.openRead()).first;
      if (actualHash.toString() != update.sha256) {
        throw const FormatException(
          'The downloaded update failed verification.',
        );
      }
      onProgress?.call(1);
      await _launchInstallerScript(workDirectory, installer);
    } on Object catch (error, stackTrace) {
      await _writeDiagnostic('download', error, stackTrace);
      if (await workDirectory.exists()) {
        await workDirectory.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> _download(
    Uri uri,
    File destination,
    UpdateProgressCallback? onProgress, {
    int attempts = 1,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final response = await _openGet(uri);
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
          await for (final chunk in response.timeout(
            const Duration(seconds: 45),
          )) {
            sink.add(chunk);
            received += chunk.length;
            onProgress?.call(total > 0 ? received / total : null);
          }
        } finally {
          await sink.close();
        }
        return;
      } on Object catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt < attempts) {
          onProgress?.call(null);
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<HttpClientResponse> _openGet(Uri uri, {int attempts = 1}) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final client = await _client();
        final request = await client
            .getUrl(uri)
            .timeout(const Duration(seconds: 30));
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'Weekra/$_currentVersion',
        );
        return await request.close().timeout(const Duration(seconds: 30));
      } on Object catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt < attempts) {
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<void> _launchInstallerScript(
    Directory workDirectory,
    File installer,
  ) async {
    final executable = File(Platform.resolvedExecutable);
    final installDirectory = executable.parent.path;
    final logPath = (await _diagnosticFile()).path;
    final script = File('${workDirectory.path}\\install-update.ps1');
    final ready = File('${workDirectory.path}\\installer-ready');
    final scriptContents = buildWindowsInstallerScript(
      installerPath: installer.path,
      installDirectory: installDirectory,
      executablePath: executable.path,
      logPath: logPath,
      readyPath: ready.path,
      appProcessId: pid,
    );
    await script.writeAsString(scriptContents, flush: true);
    final helper = await Process.start(
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
    for (var attempt = 0; attempt < 100 && !await ready.exists(); attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!await ready.exists()) {
      helper.kill();
      throw ProcessException(
        'powershell.exe',
        <String>[],
        'The update installer did not acknowledge the handoff.',
      );
    }
    exit(0);
  }

  Future<void> _writeDiagnostic(
    String phase,
    Object error,
    StackTrace stackTrace,
  ) async {
    try {
      final file = await _diagnosticFile();
      await file.writeAsString(
        '[${DateTime.now().toUtc().toIso8601String()}] $phase failed\n'
        '$error\n$stackTrace\n',
        mode: FileMode.append,
        flush: true,
      );
    } on Object {
      // Diagnostics must never replace the original update failure.
    }
  }

  Future<File> _diagnosticFile() async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final directory = localAppData != null && localAppData.isNotEmpty
        ? Directory('$localAppData\\Weekra\\Logs')
        : await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}update.log');
  }

  void _requireHttps(Uri uri) {
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Update URLs must use HTTPS.');
    }
  }
}

AppUpdate? parseUpdateManifest(
  String body, {
  required String currentVersion,
}) {
  final manifest = jsonDecode(body);
  if (manifest is! Map<String, dynamic>) {
    throw const FormatException('Update manifest must be an object.');
  }

  final version = manifest['version'];
  final windows = manifest['windows'];
  if (version is! String || windows is! Map<String, dynamic>) {
    throw const FormatException('Update manifest is missing Windows data.');
  }
  if (!isNewerVersion(version, currentVersion)) return null;

  // New clients use the verified installer while 0.5.4 and earlier keep
  // consuming the portable archive fields from the same manifest.
  final url = windows['installerUrl'] ?? windows['url'];
  final expectedHash = windows['installerSha256'] ?? windows['sha256'];
  if (url is! String ||
      expectedHash is! String ||
      !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(expectedHash)) {
    throw const FormatException('Update download metadata is invalid.');
  }
  final downloadUri = Uri.parse(url);
  if (downloadUri.scheme != 'https' || downloadUri.host.isEmpty) {
    throw const FormatException('Update URLs must use HTTPS.');
  }
  return AppUpdate(
    version: version,
    downloadUri: downloadUri,
    sha256: expectedHash.toLowerCase(),
  );
}

String buildWindowsInstallerScript({
  required String installerPath,
  required String installDirectory,
  required String executablePath,
  required String logPath,
  required String readyPath,
  required int appProcessId,
}) {
  String literal(String value) => value.replaceAll("'", "''");

  return '''
\$ErrorActionPreference = 'Stop'
\$installer = '${literal(installerPath)}'
\$install = '${literal(installDirectory)}'
\$executable = '${literal(executablePath)}'
\$log = '${literal(logPath)}'
\$ready = '${literal(readyPath)}'
\$appPid = $appProcessId

try {
  "[\$(Get-Date -Format o)] Waiting for Weekra process \$appPid." | Out-File -LiteralPath \$log -Encoding UTF8
  New-Item -ItemType File -Path \$ready -Force | Out-Null
  Wait-Process -Id \$appPid -ErrorAction SilentlyContinue
  \$arguments = @(
    '/VERYSILENT'
    '/SUPPRESSMSGBOXES'
    '/NORESTART'
    '/SP-'
    ('/DIR="' + \$install + '"')
    ('/LOG="' + \$log + '.installer"')
  )
  \$process = Start-Process -FilePath \$installer -ArgumentList \$arguments -Wait -PassThru
  if (\$process.ExitCode -ne 0) {
    throw "Weekra installer failed with exit code \$(\$process.ExitCode)."
  }
  if (-not (Test-Path -LiteralPath \$executable)) {
    throw 'Weekra executable was not found after installation.'
  }
  "[\$(Get-Date -Format o)] Update installed successfully." | Out-File -LiteralPath \$log -Encoding UTF8 -Append
  Start-Process -FilePath \$executable -WorkingDirectory \$install
} catch {
  "[\$(Get-Date -Format o)] Update installation failed." | Out-File -LiteralPath \$log -Encoding UTF8 -Append
  \$_ | Out-File -LiteralPath \$log -Encoding UTF8 -Append
  if (Test-Path -LiteralPath \$executable) {
    Start-Process -FilePath \$executable -WorkingDirectory \$install
  }
}
''';
}
