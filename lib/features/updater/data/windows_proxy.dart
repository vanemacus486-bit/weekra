import 'dart:io';

/// Reads the per-user Windows proxy used by browsers and desktop proxy apps.
///
/// Dart's [HttpClient] does not automatically inherit the WinINet proxy stored
/// in the registry. The direct fallback keeps stale proxy settings from
/// stranding the updater.
Future<String?> readWindowsProxyDirective({
  Future<ProcessResult> Function(
    String executable,
    List<String> arguments,
  )? runProcess,
}) async {
  if (!Platform.isWindows) return null;
  final run = runProcess ??
      (String executable, List<String> arguments) =>
          Process.run(executable, arguments);
  try {
    final result = await run('reg.exe', const [
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      'ProxyEnable',
    ]);
    if (result.exitCode != 0 ||
        !RegExp(
          r'ProxyEnable\s+REG_DWORD\s+0x1(?:\s|$)',
          caseSensitive: false,
        ).hasMatch(result.stdout.toString())) {
      return null;
    }

    final serverResult = await run('reg.exe', const [
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      'ProxyServer',
    ]);
    if (serverResult.exitCode != 0) return null;
    final match = RegExp(
      r'ProxyServer\s+REG_SZ\s+(.+)$',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(serverResult.stdout.toString());
    return windowsProxyDirective(match?.group(1));
  } on Object {
    return null;
  }
}

String? windowsProxyDirective(String? registryValue) {
  final value = registryValue?.trim();
  if (value == null || value.isEmpty) return null;

  String? endpoint;
  if (value.contains('=')) {
    final entries = <String, String>{};
    for (final item in value.split(';')) {
      final separator = item.indexOf('=');
      if (separator <= 0 || separator == item.length - 1) continue;
      entries[item.substring(0, separator).trim().toLowerCase()] =
          item.substring(separator + 1).trim();
    }
    endpoint = entries['https'] ?? entries['http'];
  } else {
    endpoint = value;
  }
  if (endpoint == null || endpoint.isEmpty) return null;

  endpoint = endpoint
      .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
      .split('/')
      .first
      .trim();
  if (endpoint.isEmpty || endpoint.contains(RegExp(r'[\r\n\s]'))) {
    return null;
  }
  return 'PROXY $endpoint; DIRECT';
}
