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
    // PowerShell, pencere açmadan. Eski "tasklist | find" döngüsü bazen find'da asılı kalıyordu.
    // Eski uygulamanın kapanması en fazla 60 sn beklenir, sonra zorla kapatılır.
    // helper may still be running, can rename a running exe but not overwrite it
    String q(String s) => "'${s.replaceAll("'", "''")}'";
    final dirQ = q(home);
    final script = File('${dir.path}\\update.ps1');
    script.writeAsStringSync('﻿${[
      r"$ErrorActionPreference = 'SilentlyContinue'",
      '\$dir = $dirQ',
      // marker so the helper doesn't start us mid copy
      r"New-Item -ItemType File -Force -Path (Join-Path $dir 'updating') | Out-Null",
      'Wait-Process -Id $pid -Timeout 60',
      // older helpers don't know the marker, so kill both. the browser restarts the helper
      'Stop-Process -Name nolook, nolook_host -Force',
      'Start-Sleep -Milliseconds 800',
      r"Remove-Item -Force -Path (Join-Path $dir 'nolook_host.old*.exe')",
      r"$host_ = Join-Path $dir 'nolook_host.exe'",
      r"if (Test-Path $host_) { Rename-Item -Path $host_ -NewName ('nolook_host.old' + (Get-Random) + '.exe') }",
      'robocopy ${q(files)} \$dir /e /r:5 /w:1 /njh /njs /ndl /nfl | Out-Null',
      // bump the version in Apps & features
      '\$key = ${q(_uninstallKey.replaceFirst(r'HKCU\', r'HKCU:\'))}',
      'if (Test-Path \$key) { Set-ItemProperty -Path \$key -Name DisplayVersion -Value ${q(u.version)} }',
      r"Remove-Item -Force -Path (Join-Path $dir 'updating')",
      if (restart) r"Start-Process -FilePath (Join-Path $dir 'nolook.exe')",
    ].join('\r\n')}\r\n');
    await Process.start(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', script.path],
      mode: ProcessStartMode.detached,
    );
    return true;
  } catch (_) {
    return false;
  }
}

/// yarım kalmış bir güncellemenin "updating" işareti kaldıysa sil, yoksa tarayıcı yardımcısı uygulamayı hiç başlatmaz
void clearStaleUpdateMarker() {
  if (!Platform.isWindows) return;
  try {
    final marker = File('${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}updating');
    if (marker.existsSync() && DateTime.now().difference(marker.lastModifiedSync()) > const Duration(minutes: 5)) {
      marker.deleteSync();
    }
  } catch (_) {}
}
