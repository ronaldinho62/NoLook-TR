// native messaging host. framing: 4 byte LE length + utf8 json.
// sends rules from state.json, passes extension events/commands to the app via files.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nolook_core/nolook_core.dart';

/// the app's single instance port
const appPort = 47361;

Future<void> main(List<String> args) async {
  final store = NoLookStore(Directory(Platform.environment['NOLOOK_DIR'] ?? NoLookStore.defaultDir().path));
  final host = Host(store, stdout);
  await host.run(stdin);
}

class Host {
  Host(this.store, this.out);

  final NoLookStore store;
  final IOSink out;
  String browser = '';
  String _lastSent = '';
  DateTime? _lastModified;
  NoLookState? _state;
  Timer? _timer;
  Timer? _fast;
  int _ticks = 0;

  Future<void> run(Stream<List<int>> input) async {
    _sendRules(force: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // fast poll for edits, the 1s tick covers schedules
    _fast = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_changedOnDisk()) _sendRules();
    });
    final buffer = BytesBuilder();
    await for (final chunk in input) {
      buffer.add(chunk);
      var bytes = buffer.takeBytes();
      while (bytes.length >= 4) {
        final len = ByteData.sublistView(bytes, 0, 4).getUint32(0, Endian.little);
        if (bytes.length < 4 + len) break;
        final msg = utf8.decode(bytes.sublist(4, 4 + len));
        bytes = bytes.sublist(4 + len);
        try {
          handle((jsonDecode(msg) as Map).cast());
        } catch (_) {}
      }
      buffer.add(bytes);
    }
    _timer?.cancel();
    _fast?.cancel();
    exit(0);
  }

  void _tick() {
    _ticks++;
    _sendRules();
    // heartbeat
    if (_ticks % 60 == 0 && browser.isNotEmpty) store.appendCommand({'type': 'hello', 'browser': browser});
  }

  /// mtime check
  bool _changedOnDisk() {
    try {
      return store.stateFile.lastModifiedSync() != _lastModified;
    } catch (_) {
      return false;
    }
  }

  NoLookState? _load() {
    try {
      final m = store.stateFile.lastModifiedSync();
      if (_state == null || m != _lastModified) {
        // match the app's language
        final s = store.load();
        s?.applyLanguage(s.systemLocale.isNotEmpty ? s.systemLocale : Platform.localeName);
        _state = s;
        _lastModified = m;
      }
    } catch (_) {}
    return _state;
  }

  /// send rules if changed
  void _sendRules({bool force = false}) {
    final state = _load();
    final Map<String, Object?> rules = state == null
        ? {'type': 'rules', 'blocks': const [], 'noApp': true}
        : BrowserRules.build(state, DateTime.now(), deviceId: state.deviceId);
    final key = jsonEncode({...rules, 'at': null});
    if (!force && key == _lastSent) return;
    _lastSent = key;
    send(rules);
  }

  void send(Map<String, Object?> message) {
    final body = utf8.encode(jsonEncode(message));
    final len = ByteData(4)..setUint32(0, body.length, Endian.little);
    out.add(len.buffer.asUint8List());
    out.add(body);
    out.flush();
  }

  void handle(Map<String, Object?> m) {
    switch (m['type']) {
      case 'hello':
        browser = (m['browser'] as String? ?? '').trim();
        store.appendCommand({'type': 'hello', 'browser': browser});
        _sendRules(force: true);
      case 'event':
        final kind = EventKind.values.where((k) => k.name == m['kind']).firstOrNull;
        if (kind == null || !(kind == EventKind.blurred || kind == EventKind.blocked)) return;
        final blockId = m['blockId'] as String? ?? '';
        store.appendEvent(HistoryEvent(
          time: DateTime.now(),
          kind: kind,
          blockId: blockId,
          blockName: _state?.block(blockId)?.name ?? '',
          target: (m['target'] as String? ?? '').trim(),
          matched: [for (final k in (m['matched'] as List? ?? const [])) k as String],
          where: browser,
          count: ((m['count'] as num?) ?? 1).toInt().clamp(1, 999),
        ));
      case 'unlock':
        store.appendCommand({'type': 'unlock', 'blockId': m['blockId'], 'browser': browser});
        _wakeApp();
      case 'open':
        store.appendCommand({'type': 'open', 'tab': m['tab'], 'browser': browser});
        _wakeApp();
      case 'setting':
        store.appendCommand({'type': 'setting', 'key': m['key'], 'value': m['value'], 'browser': browser});
        _wakeApp(show: false);
      case 'toggle':
        store.appendCommand({'type': 'toggle', 'blockId': m['blockId'], 'browser': browser});
        _wakeApp(show: false);
      case 'newBlock':
        store.appendCommand({'type': 'newBlock', 'site': m['site'], 'browser': browser});
        _wakeApp();
      case 'exception':
        store.appendCommand({'type': 'exception', 'site': m['site'], 'remove': m['remove'] == true, 'browser': browser});
        _wakeApp(show: false);
      case 'ping':
        send({'type': 'pong'});
    }
  }

  /// show/start the app
  Future<void> _wakeApp({bool show = true}) async {
    try {
      final s = await Socket.connect(InternetAddress.loopbackIPv4, appPort, timeout: const Duration(milliseconds: 500));
      if (show) s.write('show');
      await s.flush();
      await s.close();
    } catch (_) {
      final home = File(Platform.resolvedExecutable).parent.path;
      // AppImage path file next to us
      final appPath = File('$home${Platform.pathSeparator}app-path');
      final exe = appPath.existsSync()
          ? File(appPath.readAsStringSync().trim())
          : File('$home${Platform.pathSeparator}nolook${Platform.isWindows ? '.exe' : ''}');
      // update in progress, don't start (it restarts itself)
      if (File('$home${Platform.pathSeparator}updating').existsSync()) return;
      if (exe.existsSync()) await Process.start(exe.path, show ? const [] : const ['--hidden'], mode: ProcessStartMode.detached);
    }
  }
}
