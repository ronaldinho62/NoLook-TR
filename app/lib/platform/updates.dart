import 'dart:convert';
import 'dart:io';

/// newer release + download url
class Update {
  const Update(this.version, this.url);

  final String version;
  final String url;
}

/// a > b
bool isNewer(String a, String b) {
  List<int> parts(String v) => v.split('.').map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
    if (p != q) return p > q;
  }
  return false;
}

/// release asset per platform. names never change so releases/latest/download/NAME always works
String? releaseFileFor() => Platform.isAndroid
    ? 'NoLook-android.apk'
    : Platform.isWindows
        ? 'NoLook-windows.zip'
        : null;

Future<Update?>? _check;

/// checks once per run, null if none or offline
Future<Update?> checkForUpdate({required String current, required String repo}) => _check ??= _ask(current, repo);

Future<Update?> _ask(String current, String repo) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final api = repo.replaceFirst('https://github.com/', 'https://api.github.com/repos/');
    final req = await client.getUrl(Uri.parse('$api/releases/latest'));
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    req.headers.set(HttpHeaders.userAgentHeader, 'NoLook');
    final res = await req.close().timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, Object?>;
    final tag = (j['tag_name'] as String? ?? '').replaceFirst(RegExp('^v'), '');
    if (tag.isEmpty || !isNewer(tag, current)) return null;
    final file = releaseFileFor();
    return Update(tag, file != null ? '$repo/releases/latest/download/$file' : j['html_url'] as String? ?? '$repo/releases/latest');
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// uninstall key, AppId from tools/installer/nolook.iss
const _uninstallKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\{B447EA2B-B7E9-431E-B534-E3F8CC16DE6F}_is1';

/// windows: download, script waits for exit, copies files, restarts. false if prep failed
Future<bool> installWindowsUpdate(Update u, {void Function(double)? progress, String? installDir, bool restart = true}) async {
  final dir = Directory('${Directory.systemTemp.path}\\nolook-update');
  try {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    final zip = File('${dir.path}\\update.zip');
    final client = HttpClient();
    try {
      final res = await (await client.getUrl(Uri.parse(u.url))).close();
      if (res.statusCode != 200) return false;
      final total = res.contentLength;
      var got = 0;
      final sink = zip.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) progress?.call(got / total);
      }
      await sink.close();
    } finally {
      client.close(force: true);
    }
    final files = '${dir.path}\\files';
    final unzip = await Process.run('powershell', ['-NoProfile', '-Command', "Expand-Archive -LiteralPath '${zip.path}' -DestinationPath '$files' -Force"]);
    if (unzip.exitCode != 0 || !File('$files\\nolook.exe').existsSync()) return false;

    final home = installDir ?? File(Platform.resolvedExecutable).parent.path;
    // helper may still be running, can rename a running exe but not overwrite it
    final script = File('${dir.path}\\update.cmd');
    script.writeAsStringSync([
      '@echo off',
      // marker so the helper doesn't start us mid copy
      'echo.>"$home\\updating"',
      ':wait',
      'tasklist /fi "PID eq $pid" | find "$pid" >nul && (ping -n 2 127.0.0.1 >nul & goto wait)',
      // older helpers don't know the marker, so kill both. the browser restarts the helper
      'taskkill /f /im nolook.exe >nul 2>&1',
      'taskkill /f /im nolook_host.exe >nul 2>&1',
      'del /q "$home\\nolook_host.old*.exe" 2>nul',
      'if exist "$home\\nolook_host.exe" move /y "$home\\nolook_host.exe" "$home\\nolook_host.old%RANDOM%.exe" >nul',
      'robocopy "$files" "$home" /e /r:5 /w:1 /njh /njs /ndl /nfl >nul',
      // bump the version in Apps & features
      'reg query "$_uninstallKey" >nul 2>&1 && reg add "$_uninstallKey" /v DisplayVersion /d "${u.version}" /f >nul',      'del /q "$home\\updating" 2>nul',
      if (restart) 'start "" "$home\\nolook.exe"',
    ].join('\r\n'));
    await Process.start('cmd', ['/c', script.path], mode: ProcessStartMode.detached);
    return true;
  } catch (_) {
    return false;
  }
}
