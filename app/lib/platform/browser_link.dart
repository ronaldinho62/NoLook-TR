import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nolook_core/nolook_core.dart';

/// native messaging host name
const hostName = 'com.itszedk.nolook';

/// fixed by the key in the manifest
const chromeExtensionId = 'phgaojhjiefjekaphjicfldnggmobhhd';

/// store extension ids
const storeExtensionIds = <String>[
  'okjfipdooljmahifocdghkgbelmpnkik', // Chrome Web Store
];

List<String> get _chromeOrigins => [for (final id in [chromeExtensionId, ...storeExtensionIds]) 'chrome-extension://$id/'];
const firefoxExtensionId = 'nolook@itszedk.com';

String get _appDir => File(Platform.resolvedExecutable).parent.path;

/// AppImage path or null. the mount is temporary so stuff gets copied to [_lasting]
String? get _appImage => Platform.isLinux ? Platform.environment['APPIMAGE'] : null;
String get _lasting => '${Platform.environment['HOME']}/.local/share/nolook';
String get _helperDir => _appImage != null ? _lasting : _appDir;

/// helper exe, next to nolook.exe
File get hostExe => File('$_helperDir${Platform.pathSeparator}nolook_host${Platform.isWindows ? '.exe' : ''}');

Directory extensionDir(String browser) =>
    Directory('$_helperDir${Platform.pathSeparator}extension${Platform.pathSeparator}${browser == 'Firefox' ? 'firefox' : 'chrome'}');

/// register the native host, runs every start. false if the helper is missing
Future<bool> registerBrowserHelper() async {
  if (_appImage != null) await _settleAppImage(_appImage!);
  if (!hostExe.existsSync()) return false;
  if (!Platform.isWindows) return _registerUnix();
  final dir = Directory('${NoLookStore.defaultDir().path}\\host')..createSync(recursive: true);

  final chrome = File('${dir.path}\\$hostName.json');
  final firefox = File('${dir.path}\\$hostName.firefox.json');
  const enc = JsonEncoder.withIndent('  ');
  final base = {'name': hostName, 'description': 'NoLook', 'path': hostExe.path, 'type': 'stdio'};
  chrome.writeAsStringSync(enc.convert({...base, 'allowed_origins': _chromeOrigins}));
  firefox.writeAsStringSync(enc.convert({...base, 'allowed_extensions': [firefoxExtensionId]}));

  Future<void> reg(String key, String file) =>
      Process.run('reg', ['add', 'HKCU\\Software\\$key\\NativeMessagingHosts\\$hostName', '/ve', '/t', 'REG_SZ', '/d', file, '/f']);
  await reg('Google\\Chrome', chrome.path);
  await reg('Microsoft\\Edge', chrome.path);
  // opera/vivaldi use chrome's key
  await reg('BraveSoftware\\Brave-Browser', chrome.path);
  await reg('Chromium', chrome.path);
  await reg('Vivaldi', chrome.path);
  await reg('Mozilla', firefox.path);
  return true;
}

/// AppImage: copy the helper + extensions out, write the AppImage path, add a menu entry
Future<void> _settleAppImage(String appImage) async {
  try {
    final dir = Directory(_lasting)..createSync(recursive: true);
    final host = File('$_appDir/nolook_host');
    if (host.existsSync()) {
      host.copySync('${dir.path}/nolook_host');
      await Process.run('chmod', ['+x', '${dir.path}/nolook_host']);
    }
    final ext = Directory('$_appDir/extension');
    if (ext.existsSync()) _copyDir(ext, Directory('${dir.path}/extension'));
    File('${dir.path}/app-path').writeAsStringSync(appImage);

    final icon = File('$_appDir/data/flutter_assets/assets/logo/icon-512.png');
    if (icon.existsSync()) icon.copySync('${dir.path}/nolook.png');
    final apps = Directory('${Platform.environment['HOME']}/.local/share/applications')..createSync(recursive: true);
    File('${apps.path}/nolook.desktop').writeAsStringSync([
      '[Desktop Entry]',
      'Type=Application',
      'Name=NoLook',
      'Comment=Hide spoilers and block sites and apps',
      'Exec="$appImage"',
      'Icon=${dir.path}/nolook.png',
      'Categories=Utility;',
      'Terminal=false',
      '',
    ].join('\n'));
  } catch (_) {}
}

void _copyDir(Directory from, Directory to) {
  if (to.existsSync()) to.deleteSync(recursive: true);
  to.createSync(recursive: true);
  for (final e in from.listSync(recursive: true)) {
    final rel = e.path.substring(from.path.length + 1);
    if (e is Directory) {
      Directory('${to.path}/$rel').createSync(recursive: true);
    } else if (e is File) {
      File('${to.path}/$rel').parent.createSync(recursive: true);
      e.copySync('${to.path}/$rel');
    }
  }
}

/// mac/linux: write the manifest into each browser's folder that exists
Future<bool> _registerUnix() async {
  final home = Platform.environment['HOME'] ?? '';
  final mac = Platform.isMacOS;
  final support = '$home/Library/Application Support';
  final chromium = mac
      ? ['$support/Google/Chrome', '$support/Microsoft Edge', '$support/BraveSoftware/Brave-Browser', '$support/Chromium', '$support/Vivaldi']
      : ['$home/.config/google-chrome', '$home/.config/microsoft-edge', '$home/.config/BraveSoftware/Brave-Browser', '$home/.config/chromium', '$home/.config/vivaldi'];
  final firefox = mac ? '$support/Mozilla' : '$home/.mozilla';

  const enc = JsonEncoder.withIndent('  ');
  final base = {'name': hostName, 'description': 'NoLook', 'path': hostExe.path, 'type': 'stdio'};
  void write(String dir, Map<String, Object> manifest) {
    try {
      Directory(dir).createSync(recursive: true);
      File('$dir/$hostName.json').writeAsStringSync(enc.convert(manifest));
    } catch (_) {}
  }

  for (final b in chromium) {
    if (Directory(b).existsSync()) write('$b/NativeMessagingHosts', {...base, 'allowed_origins': _chromeOrigins});
  }
  if (Directory(firefox).existsSync()) {
    write(mac ? '$firefox/NativeMessagingHosts' : '$firefox/native-messaging-hosts', {...base, 'allowed_extensions': [firefoxExtensionId]});
  }
  return true;
}

/// hardcoded store links, normally null (stores.json is used). wins over the file
const String? firefoxStoreUrl = null;
const String? chromeStoreUrl = null;
const String? edgeStoreUrl = null;

const storesFileUrl = 'https://raw.githubusercontent.com/ronaldinho62/NoLook-TR/main/stores.json';

/// from stores.json, empty until loaded (or offline)
final storeLinks = ValueNotifier<Map<String, String>>(const {});

/// allowed prefixes
const _storeHosts = {
  'chrome': 'https://chromewebstore.google.com/',
  'edge': 'https://microsoftedge.microsoft.com/',
  'firefox': 'https://addons.mozilla.org/',
};

Future<void>? _storesLoad;

/// Türkçe sürüm: mağazalardaki NoLook eklentisi özgün sürümdür ve Türkçe "*" kelimelerini tanımaz,
/// bu yüzden mağaza linkleri hiç yüklenmez, eklenti her zaman uygulamanın klasöründen kurulur.
/// Türkçe eklenti bir mağazaya çıkarsa bunu true yap ve stores.json'u doldur.
const useStoreLinks = false;

Future<void> loadStoreLinks() => _storesLoad ??= useStoreLinks ? _readStores() : Future<void>.value();

Future<void> _readStores() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final res = await (await client.getUrl(Uri.parse(storesFileUrl))).close().timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return;
    final j = jsonDecode(await res.transform(utf8.decoder).join());
    if (j is! Map) return;
    storeLinks.value = {
      for (final e in _storeHosts.entries)
        if (j[e.key] is String && (j[e.key] as String).startsWith(e.value)) e.key: j[e.key] as String,
    };
  } catch (_) {
    // offline, setup falls back to the folder steps
  } finally {
    client.close(force: true);
  }
}

String? _link(String key, String? fixed) => fixed ?? storeLinks.value[key];

/// store link for a browser, null if not listed. chromium ones use the chrome store
String? storeUrl(String browser) => switch (browser) {
      'Firefox' => _link('firefox', firefoxStoreUrl),
      'Edge' => _link('edge', edgeStoreUrl) ?? _link('chrome', chromeStoreUrl),
      'Other' => null,
      _ => _link('chrome', chromeStoreUrl),
    };

bool get edgeHasOwnListing => _link('edge', edgeStoreUrl) != null;

const _exeNames = {'Chrome': 'chrome.exe', 'Edge': 'msedge.exe', 'Firefox': 'firefox.exe', 'Brave': 'brave.exe', 'Vivaldi': 'vivaldi.exe', 'Opera': 'opera.exe', 'Opera GX': ''};

/// installed browsers -> exe path
Future<Map<String, String>> findBrowsers() async {
  final found = <String, String>{};
  if (Platform.isMacOS) {
    const apps = {
      'Chrome': 'Google Chrome', 'Edge': 'Microsoft Edge', 'Firefox': 'Firefox', 'Brave': 'Brave Browser',
      'Opera': 'Opera', 'Opera GX': 'Opera GX', 'Vivaldi': 'Vivaldi',
    };
    final home = Platform.environment['HOME'] ?? '';
    for (final MapEntry(key: browser, value: name) in apps.entries) {
      for (final dir in ['/Applications', '$home/Applications']) {
        if (Directory('$dir/$name.app').existsSync()) {
          found[browser] = '$dir/$name.app';
          break;
        }
      }
    }
    return found;
  }
  if (Platform.isLinux) {
    const commands = {
      'Chrome': ['google-chrome', 'google-chrome-stable'], 'Edge': ['microsoft-edge', 'microsoft-edge-stable'], 'Firefox': ['firefox'],
      'Brave': ['brave-browser', 'brave'], 'Opera': ['opera'], 'Vivaldi': ['vivaldi', 'vivaldi-stable'],
    };
    for (final MapEntry(key: browser, value: names) in commands.entries) {
      for (final name in names) {
        try {
          final r = await Process.run('which', [name]);
          final path = '${r.stdout}'.trim();
          if (r.exitCode == 0 && path.isNotEmpty) {
            found[browser] = path;
            break;
          }
        } catch (_) {}
      }
    }
    return found;
  }
  if (!Platform.isWindows) return found;
  for (final MapEntry(key: browser, value: exe) in _exeNames.entries) {
    for (final root in exe.isEmpty ? const <String>[] : ['HKCU', 'HKLM']) {
      try {
        final r = await Process.run('reg', ['query', '$root\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths\\$exe', '/ve']);
        final m = RegExp(r'REG_(?:EXPAND_)?SZ\s+(.+\.exe)', caseSensitive: false).firstMatch('${r.stdout}');
        final path = m?.group(1)?.trim().replaceAll('"', '');
        // some chromium forks register as chrome.exe
        final real = switch (browser) {
          'Chrome' => path?.toLowerCase().contains('\\google\\chrome\\') ?? false,
          'Edge' => path?.toLowerCase().contains('\\microsoft\\edge\\') ?? false,
          'Opera' => !(path?.toLowerCase().contains('opera gx') ?? true),
          _ => true,
        };
        if (path != null && real && File(path).existsSync()) {
          found[browser] = path;
          break;
        }
      } catch (_) {}
    }
    if (found.containsKey(browser)) continue;
    // fallback paths
    final env = Platform.environment;
    final guesses = switch (browser) {
      'Chrome' => [
          '${env['ProgramFiles']}\\Google\\Chrome\\Application\\chrome.exe',
          '${env['ProgramFiles(x86)']}\\Google\\Chrome\\Application\\chrome.exe',
          '${env['LOCALAPPDATA']}\\Google\\Chrome\\Application\\chrome.exe',
        ],
      'Edge' => ['${env['ProgramFiles(x86)']}\\Microsoft\\Edge\\Application\\msedge.exe', '${env['ProgramFiles']}\\Microsoft\\Edge\\Application\\msedge.exe'],
      'Brave' => [
          '${env['ProgramFiles']}\\BraveSoftware\\Brave-Browser\\Application\\brave.exe',
          '${env['LOCALAPPDATA']}\\BraveSoftware\\Brave-Browser\\Application\\brave.exe',
        ],
      'Opera' => ['${env['LOCALAPPDATA']}\\Programs\\Opera\\launcher.exe', '${env['LOCALAPPDATA']}\\Programs\\Opera\\opera.exe'],
      'Opera GX' => ['${env['LOCALAPPDATA']}\\Programs\\Opera GX\\launcher.exe', '${env['LOCALAPPDATA']}\\Programs\\Opera GX\\opera.exe'],
      'Vivaldi' => ['${env['LOCALAPPDATA']}\\Vivaldi\\Application\\vivaldi.exe', '${env['ProgramFiles']}\\Vivaldi\\Application\\vivaldi.exe'],
      _ => ['${env['ProgramFiles']}\\Mozilla Firefox\\firefox.exe', '${env['ProgramFiles(x86)']}\\Mozilla Firefox\\firefox.exe'],
    };
    for (final g in guesses) {
      if (File(g).existsSync()) {
        found[browser] = g;
        break;
      }
    }
  }
  return found;
}

String extensionsPage(String browser) => switch (browser) {
      'Edge' => 'edge://extensions',
      'Firefox' => 'about:debugging#/runtime/this-firefox',
      'Brave' => 'brave://extensions',
      'Opera' || 'Opera GX' => 'opera://extensions',
      'Vivaldi' => 'vivaldi://extensions',
      _ => 'chrome://extensions',
    };

bool isChromium(String browser) => browser != 'Firefox';

/// chromium won't open chrome:// urls from outside, setup copies those to paste instead
Future<bool> openInBrowser(String exe, [String? url]) async {
  try {
    if (exe.endsWith('.app')) {
      // mac apps are folders
      await Process.start('open', ['-a', exe, ?url], mode: ProcessStartMode.detached);
    } else {
      await Process.start(exe, [?url], mode: ProcessStartMode.detached);
    }
    return true;
  } catch (_) {
    return false;
  }
}
