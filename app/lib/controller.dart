import 'dart:async';
import 'platform/os.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nolook_core/nolook_core.dart';

import 'platform/windows_apps.dart' as win;

/// closed app info
class BlockedAppNotice {
  const BlockedAppNotice(this.appName, this.block, this.timesToday, {this.site = false});

  final String appName;
  final Block block;
  final int timesToday;

  /// site, not an app
  final bool site;
}

/// app state, saving, in-app blocking
class NoLook extends ChangeNotifier {
  NoLook(this.store, this.state);

  final NoLookStore store;

  /// replaced by [factoryReset], don't hold on to it
  NoLookState state;

  DateTime now = DateTime.now();

  /// unlock request from the browser
  final unlockRequest = ValueNotifier<String?>(null);

  /// new block request from the browser
  final newBlockRequest = ValueNotifier<String?>(null);

  /// tab request from the browser
  final tabRequest = ValueNotifier<String?>(null);

  /// last closed app
  final blockedApp = ValueNotifier<BlockedAppNotice?>(null);

  /// set by main
  VoidCallback? showWindow;

  /// set by main
  void Function(String title, String body)? notify;

  Timer? _tick;
  int _ticks = 0;

  /// wifi sync, null until started
  NoLookLink? link;
  final _waitsNotified = <String>{};
  final _lockedBefore = <String>{};

  static NoLook open({Directory? dir}) {
    final store = NoLookStore(dir ?? NoLookStore.defaultDir());
    final state = store.load() ?? NoLookState(deviceName: Platform.isAndroid ? 'Android phone' : Platform.localHostname);
    // old installs named every pc "This PC"
    if (state.deviceName == 'This PC' && !Platform.isAndroid) state.deviceName = Platform.localHostname;
    final app = NoLook(store, state)..applyLanguage();
    app.state.trimEvents(DateTime.now());
    app._lockedBefore.addAll(state.blocks.where((b) => b.isLocked(app.now)).map((b) => b.id));
    return app;
  }

  void start() {
    store.save(state);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _watchHelper();
  }

  StreamSubscription<FileSystemEvent>? _helperWatch;
  Timer? _helperSoon;

  /// watch the helper's files, the tick still polls in case watching fails
  void _watchHelper() {
    try {
      store.dir.createSync(recursive: true);
      _helperWatch = store.dir.watch().listen((e) {
        final name = e.path.split(Platform.pathSeparator).last;
        if (name != 'commands.jsonl' && name != 'events.jsonl') return;
        _helperSoon?.cancel();
        _helperSoon = Timer(const Duration(milliseconds: 40), () {
          if (_takeFromHelper()) store.save(state);
          notifyListeners();
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> startLink(String os) async {
    link = NoLookLink(
      state: () => state,
      os: os,
      // synced in, save without echoing back
      onChanged: () {
        state.stampChanges(DateTime.now());
        store.save(state);
        notifyListeners();
      },
    );
    await link!.start();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _helperSoon?.cancel();
    _helperWatch?.cancel();
    link?.stop();
    super.dispose();
  }

  void save() {
    applyLanguage();
    // stamp changes for sync
    if (state.stampChanges(DateTime.now())) link?.changedHere();
    store.save(state);
    notifyListeners();
  }

  /// settings language or the system display language. not [Platform.localeName], that's the region format
  void applyLanguage() {
    state.systemLocale = PlatformDispatcher.instance.locale.toLanguageTag();
    state.applyLanguage(state.systemLocale);
  }

  HistoryStats get stats => state.stats(now);

  bool get anyLocked => state.blocks.any((b) => b.isLocked(now));

  /// wipe everything, refused while anything is locked
  bool factoryReset() {
    if (anyLocked) return false;
    for (final p in List.of(state.paired)) {
      link?.unpair(p.id);
    }
    state = NoLookState(deviceName: state.deviceName, systemLocale: state.systemLocale);
    _lockedBefore.clear();
    _waitsNotified.clear();
    // clear helper files too
    store.takeEvents();
    store.takeCommands();
    unlockRequest.value = null;
    newBlockRequest.value = null;
    blockedApp.value = null;
    save();
    return true;
  }

  // ---------- blocks ----------

  void addBlock(Block b) {
    state.blocks.add(b);
    save();
  }

  /// returns what the lock blocks, empty if saved
  List<String> updateBlock(Block edited) {
    final i = state.blocks.indexWhere((b) => b.id == edited.id);
    if (i == -1) return [tr('That block is gone.', 'Bu engel artık yok.')];
    final problems = Unlocker.problemsWithEdit(state.blocks[i], edited, now);
    if (problems.isNotEmpty) return problems;
    state.blocks[i] = edited;
    save();
    return const [];
  }

  bool deleteBlock(String id) {
    final b = state.block(id);
    if (b == null || b.isLocked(now)) return false;
    state.blocks.remove(b);
    save();
    return true;
  }

  /// false if locked
  bool toggle(Block b) {
    if (b.isOn(now)) {
      if (!Unlocker.turnOff(b, now)) return false;
    } else {
      Unlocker.turnOn(b);
      _lockedBefore.add(b.id);
    }
    save();
    return true;
  }

  void startWait(Block b) {
    Unlocker.startWait(b, now);
    _waitsNotified.remove(b.id);
    save();
  }

  void cancelUnlock(Block b) {
    Unlocker.cancelUnlock(b);
    save();
  }

  UnlockResult unlockEarly(Block b, String typed) {
    final steps = Unlocker.stepsFor(b);
    final waited = b.unlockStartedAt;
    final result = Unlocker.unlockEarly(b, now, typed: typed);
    if (result == UnlockResult.unlocked) {
      final parts = [
        if (steps.wait && waited != null) tr('Waited ${Describe.minutes(steps.waitMinutes)}', '${Describe.minutes(steps.waitMinutes)} beklendi'),
        if (steps.type) tr('typed the sentence', 'cümleyi yazdı'),
      ];
      _logUnlock(b, EventKind.unlocked, parts.join(', '));
    }
    save();
    return result;
  }

  UnlockResult emergencyUnlock(Block b) {
    final result = Unlocker.emergencyUnlock(b, now);
    if (result == UnlockResult.unlocked) _logUnlock(b, EventKind.emergency, tr('Emergency unlock', 'Acil kilit açma'));
    save();
    return result;
  }

  void _logUnlock(Block b, EventKind kind, String how) {
    final back = b.pausedUntil != null
        ? tr(', turns back on at ${Describe.time(b.pausedUntil!)}', ', saat ${Describe.at(b.pausedUntil!)} yeniden açılır')
        : '';
    state.addEvent(HistoryEvent(time: now, kind: kind, blockId: b.id, blockName: b.name, where: here, note: '$how$back'));
    _lockedBefore.remove(b.id);
  }

  // ---------- files ----------

  String get here => onMobile ? 'this phone' : 'this PC';

  /// android blocker closed an app / left a site
  void stopped(Block b, String name, {required bool site}) {
    final kind = site ? EventKind.blocked : EventKind.closedApp;
    state.addEvent(HistoryEvent(time: now, kind: kind, blockId: b.id, blockName: b.name, target: name, where: here));
    final today = DateTime(now.year, now.month, now.day);
    final times = state.events.where((e) => e.kind == kind && e.target == name && !e.time.isBefore(today)).length;
    blockedApp.value = BlockedAppNotice(name, b, times, site: site);
    save();
  }

  /// android blocker covered posts
  void covered(Block b, String app, List<String> matched, int count) {
    state.addEvent(HistoryEvent(time: now, kind: EventKind.blurred, blockId: b.id, blockName: b.name, target: app, matched: matched, where: here, count: count));
    save();
  }

  String exportBlocks() => NoLookFile.export(state.blocks, now: now);

  /// import .nolook, throws [FormatException]
  int importBlocks(String text) {
    final added = NoLookFile.addTo(state, NoLookFile.read(text));
    save();
    return added;
  }

  // ---------- the clock ----------

  void _onTick() {
    now = DateTime.now();
    _ticks++;
    var changed = false;

    for (final b in state.blocks) {
      // wait over
      if (b.unlockStartedAt != null && Unlocker.waitOver(b, now) && _waitsNotified.add(b.id)) {
        if (state.settings.notifyWaitOver) notify?.call(tr('The wait is over', 'Bekleme bitti'), tr('You can unlock ${b.name} now.', '${b.name} engelinin kilidini artık açabilirsin.'));
      }
      // date lock ended
      final locked = b.isLocked(now);
      if (_lockedBefore.contains(b.id) && !locked && b.lock == LockKind.untilDate && b.enabled) {
        _lockedBefore.remove(b.id);
        if (state.settings.notifyUnlock) notify?.call(tr('${b.name} is unlocked', '${b.name} engelinin kilidi açıldı'), tr('The lock date has passed.', 'Kilit tarihi geçti.'));
      } else if (locked) {
        _lockedBefore.add(b.id);
      }
    }

    if (_ticks % 2 == 0) changed |= _takeFromHelper();
    if (Platform.isWindows) changed |= _closeBlockedApps();

    if (changed) store.save(state);
    notifyListeners();
  }

  /// read helper events + commands
  bool _takeFromHelper() {
    var changed = false;
    for (final e in store.takeEvents()) {
      state.addEvent(e);
      changed = true;
    }
    for (final c in store.takeCommands()) {
      final browser = c['browser'] as String?;
      if (browser != null && browser.isNotEmpty) {
        state.browsersSeen[browser] = now;
        changed = true;
      }
      switch (c['type']) {
        case 'unlock':
          showWindow?.call();
          unlockRequest.value = c['blockId'] as String?;
        case 'setting':
          // popup can only change these
          final s = state.settings, v = c['value'];
          switch (c['key']) {
            case 'language':
              s.language = LangChoice.values.where((l) => l.name == v).firstOrNull ?? s.language;
            case 'blurStrength':
              s.blurStrength = BlurStrength.values.where((b) => b.name == v).firstOrNull ?? s.blurStrength;
            case 'twoClickReveal' when v is bool:
              s.twoClickReveal = v;
            case 'sayKeyword' when v is bool:
              s.sayKeyword = v;
          }
          save();
        case 'open':
          showWindow?.call();
          if (c['tab'] is String) tabRequest.value = c['tab'] as String;
        case 'toggle':
          final b = state.block(c['blockId'] as String? ?? '');
          if (b != null && !toggle(b)) {
            showWindow?.call();
            unlockRequest.value = b.id;
          }
        case 'newBlock':
          showWindow?.call();
          newBlockRequest.value = c['site'] as String? ?? '';
      }
    }
    return changed;
  }

  /// close blocked apps
  bool _closeBlockedApps() {
    final byExe = <String, (Block, AppRef)>{};
    for (final b in state.blocks) {
      if (!b.isActive(now) || !b.runsOn(state.deviceId)) continue;
      for (final a in b.apps) {
        for (final id in a.ids) {
          byExe.putIfAbsent(id.toLowerCase(), () => (b, a));
        }
      }
    }
    if (byExe.isEmpty) return false;
    final closed = win.closeApps(byExe.keys.toSet());
    if (closed.isEmpty) return false;
    final seen = <String>{};
    for (final exe in closed) {
      final (b, a) = byExe[exe]!;
      if (!seen.add(a.name)) continue;
      state.addEvent(HistoryEvent(
        time: now, kind: EventKind.closedApp, blockId: b.id, blockName: b.name, target: a.name, where: here));
      final today = DateTime(now.year, now.month, now.day);
      final times = state.events
          .where((e) => e.kind == EventKind.closedApp && e.target == a.name && !e.time.isBefore(today))
          .length;
      blockedApp.value = BlockedAppNotice(a.name, b, times);
      showWindow?.call();
    }
    return true;
  }
}
