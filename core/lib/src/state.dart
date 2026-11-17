import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'block.dart';
import 'sync.dart';
import 'history.dart';
import 'i18n.dart';

enum ThemeChoice { system, light, dark }

enum BlurStrength { light, strong }

enum LangChoice { system, en, tr }

class Settings {
  Settings({
    this.theme = ThemeChoice.system,
    this.language = LangChoice.system,
    this.setupDone = false,
    this.wallpaperColours = false,
    this.blurStrength = BlurStrength.strong,
    this.twoClickReveal = false,
    this.sayKeyword = true,
    this.notifyUnlock = true,
    this.notifyWaitOver = true,
    this.weeklySummary = false,
    this.startWithSystem = true,
    this.guard = true,
  });

  ThemeChoice theme;
  LangChoice language;

  bool setupDone;
  bool wallpaperColours;
  BlurStrength blurStrength;
  bool twoClickReveal;

  bool sayKeyword;
  bool notifyUnlock;
  bool notifyWaitOver;
  bool weeklySummary;
  bool startWithSystem;

  bool guard;

  Map<String, Object?> toJson() => {
        'theme': theme.name,
        'language': language.name,
        'setupDone': setupDone,
        'wallpaperColours': wallpaperColours,
        'blurStrength': blurStrength.name,
        'twoClickReveal': twoClickReveal,
        'sayKeyword': sayKeyword,
        'notifyUnlock': notifyUnlock,
        'notifyWaitOver': notifyWaitOver,
        'weeklySummary': weeklySummary,
        'startWithSystem': startWithSystem,
        'guard': guard,
      };

  factory Settings.fromJson(Map<String, Object?>? j) {
    if (j == null) return Settings();
    return Settings(
      theme: ThemeChoice.values.where((t) => t.name == j['theme']).firstOrNull ?? ThemeChoice.system,
      language: LangChoice.values.where((t) => t.name == j['language']).firstOrNull ?? LangChoice.system,
      // old saves predate setup
      setupDone: j['setupDone'] as bool? ?? true,
      wallpaperColours: j['wallpaperColours'] as bool? ?? false,
      blurStrength: BlurStrength.values.where((t) => t.name == j['blurStrength']).firstOrNull ?? BlurStrength.strong,
      twoClickReveal: j['twoClickReveal'] as bool? ?? false,
      sayKeyword: j['sayKeyword'] as bool? ?? true,
      notifyUnlock: j['notifyUnlock'] as bool? ?? true,
      notifyWaitOver: j['notifyWaitOver'] as bool? ?? true,
      weeklySummary: j['weeklySummary'] as bool? ?? false,
      startWithSystem: j['startWithSystem'] as bool? ?? true,
      guard: j['guard'] as bool? ?? true,
    );
  }
}

class NoLookState {
  NoLookState({
    String? deviceId,
    this.deviceName = 'This PC',
    List<Block>? blocks,
    List<HistoryEvent>? events,
    Map<String, int>? totals,
    Settings? settings,
    DateTime? startedAt,
    Map<String, DateTime>? browsersSeen,
    List<PairedDevice>? paired,
    Map<String, DateTime>? deletedBlocks,
    Map<String, String>? fingerprints,
    this.systemLocale = '',
  })  : browsersSeen = browsersSeen ?? {},
        paired = paired ?? [],
        deletedBlocks = deletedBlocks ?? {},
        fingerprints = fingerprints ?? {},
        deviceId = deviceId ?? newId(),
        blocks = blocks ?? [],
        events = events ?? [],
        totals = totals ?? {},
        settings = settings ?? Settings(),
        startedAt = startedAt ?? DateTime.now();

  final String deviceId;
  String deviceName;
  final List<Block> blocks;

  /// newest last, trimmed to [keepDays]
  final List<HistoryEvent> events;

  /// all time, per block
  final Map<String, int> totals;
  final Settings settings;
  final DateTime startedAt;

  /// last contact per browser
  final Map<String, DateTime> browsersSeen;

  final List<PairedDevice> paired;

  /// tombstones for sync
  final Map<String, DateTime> deletedBlocks;

  /// see [stampChanges]
  final Map<String, String> fingerprints;

  /// display language for the helper (its own locale is the region format)
  String systemLocale;

  static const keepDays = 90;

  Block? block(String id) => blocks.where((b) => b.id == id).firstOrNull;

  void addEvent(HistoryEvent e) {
    events.add(e);
    if (e.isHidden) totals[e.blockId] = (totals[e.blockId] ?? 0) + e.count;
  }

  void trimEvents(DateTime now) {
    final cutoff = now.subtract(const Duration(days: keepDays));
    events.removeWhere((e) => e.time.isBefore(cutoff));
    events.sort((a, b) => a.time.compareTo(b.time));
  }

  HistoryStats stats(DateTime now) => HistoryStats(events, now: now, since: startedAt);

  void applyLanguage(String systemLocale) {
    currentLang = switch (settings.language) {
      LangChoice.en => Lang.en,
      LangChoice.tr => Lang.tr,
      LangChoice.system => langForLocale(systemLocale),
    };
  }

  Map<String, Object?> toJson() => {
        'format': 'nolook-state',
        'version': 1,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'startedAt': startedAt.toIso8601String(),
        'settings': settings.toJson(),
        'blocks': [for (final b in blocks) b.toJson()],
        'totals': totals,
        'browsersSeen': {for (final e in browsersSeen.entries) e.key: e.value.toIso8601String()},
        'events': [for (final e in events) e.toJson()],
        'paired': [for (final p in paired) p.toJson()],
        'deletedBlocks': {for (final e in deletedBlocks.entries) e.key: e.value.toIso8601String()},
        'fingerprints': fingerprints,
        'systemLocale': systemLocale,
      };

  factory NoLookState.fromJson(Map<String, Object?> j) => NoLookState(
        deviceId: j['deviceId'] as String?,
        deviceName: j['deviceName'] as String? ?? 'This PC',
        startedAt: DateTime.tryParse(j['startedAt'] as String? ?? ''),
        settings: Settings.fromJson((j['settings'] as Map?)?.cast()),
        blocks: [for (final b in (j['blocks'] as List? ?? const [])) Block.fromJson((b as Map).cast())],
        browsersSeen: {
          for (final e in ((j['browsersSeen'] as Map?) ?? const {}).entries)
            if (DateTime.tryParse(e.value as String? ?? '') case final d?) e.key as String: d,
        },
        totals: {for (final e in ((j['totals'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt()},
        events: [
          for (final e in (j['events'] as List? ?? const []))
            if (HistoryEvent.fromJson((e as Map).cast()) case final ev?) ev,
        ],
        paired: [for (final p in (j['paired'] as List? ?? const [])) PairedDevice.fromJson((p as Map).cast())],
        deletedBlocks: {
          for (final e in ((j['deletedBlocks'] as Map?) ?? const {}).entries)
            if (DateTime.tryParse(e.value as String? ?? '') case final d?) e.key as String: d,
        },
        fingerprints: {for (final e in ((j['fingerprints'] as Map?) ?? const {}).entries) e.key as String: e.value as String},
        systemLocale: j['systemLocale'] as String? ?? '',
      );
}

String newId() {
  final r = Random.secure();
  return List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join();
}

/// .nolook export file
class NoLookFile {
  const NoLookFile._();

  static String export(List<Block> blocks, {DateTime? now}) {
    final out = [
      for (final b in blocks)
        (b.toJson()
          ..remove('pausedUntil')
          ..remove('unlockStartedAt')
          ..remove('emergencyUses')
          ..remove('devices')),
    ];
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'nolook',
      'version': 1,
      'exportedAt': (now ?? DateTime.now()).toIso8601String(),
      'blocks': out,
    });
  }

  /// throws [FormatException]
  static List<Block> read(String text) {
    final Object? data;
    try {
      data = jsonDecode(text);
    } on FormatException {
      throw FormatException(tr("This isn't a NoLook file.", 'Bu bir NoLook dosyası değil.'));
    }
    if (data is! Map || data['format'] != 'nolook' || data['blocks'] is! List) {
      throw FormatException(tr("This isn't a NoLook file.", 'Bu bir NoLook dosyası değil.'));
    }
    if ((data['version'] as num? ?? 1) > 1) {
      throw FormatException(tr('This file is from a newer NoLook, update NoLook to open it.', 'Bu dosya daha yeni bir NoLook sürümünden, açmak için NoLook\'u güncelle.'));
    }
    return [for (final b in data['blocks'] as List) Block.fromJson((b as Map).cast())];
  }

  /// adds new ones only, returns the count
  static int addTo(NoLookState state, List<Block> imported) {
    var added = 0;
    for (final b in imported) {
      if (state.block(b.id) != null) continue;
      state.blocks.add(b);
      added++;
    }
    return added;
  }
}

/// files shared with the helper:
///
/// - state.json: app writes, helper reads
/// - events.jsonl: helper appends, app consumes
/// - commands.jsonl: same, for requests
class NoLookStore {
  NoLookStore(this.dir);

  final Directory dir;

  File get stateFile => File('${dir.path}${Platform.pathSeparator}state.json');
  File get eventsFile => File('${dir.path}${Platform.pathSeparator}events.jsonl');
  File get commandsFile => File('${dir.path}${Platform.pathSeparator}commands.jsonl');

  /// desktop default, android passes its own
  static Directory defaultDir() {
    final env = Platform.environment;
    if (Platform.isWindows) return Directory('${env['APPDATA']}\\NoLook');
    if (Platform.isMacOS) return Directory('${env['HOME']}/Library/Application Support/NoLook');
    final xdg = env['XDG_CONFIG_HOME'];
    return Directory('${xdg != null && xdg.isNotEmpty ? xdg : '${env['HOME']}/.config'}/nolook');
  }

  NoLookState? load() {
    try {
      if (!stateFile.existsSync()) return null;
      return NoLookState.fromJson((jsonDecode(stateFile.readAsStringSync()) as Map).cast());
    } catch (_) {
      // broken file: keep a copy, use the backup
      final backup = File('${stateFile.path}.bak');
      if (backup.existsSync()) {
        try {
          return NoLookState.fromJson((jsonDecode(backup.readAsStringSync()) as Map).cast());
        } catch (_) {}
      }
      return null;
    }
  }

  /// atomic write
  void save(NoLookState state) {
    dir.createSync(recursive: true);
    final tmp = File('${stateFile.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(state.toJson()), flush: true);
    if (stateFile.existsSync()) {
      try {
        stateFile.copySync('${stateFile.path}.bak');
      } catch (_) {}
    }
    tmp.renameSync(stateFile.path);
  }

  void appendEvent(HistoryEvent e) => _append(eventsFile, jsonEncode(e.toJson()));
  void appendCommand(Map<String, Object?> c) => _append(commandsFile, jsonEncode(c));

  List<HistoryEvent> takeEvents() => [
        for (final m in _take(eventsFile))
          if (HistoryEvent.fromJson(m) case final e?) e,
      ];

  List<Map<String, Object?>> takeCommands() => _take(commandsFile);

  void _append(File f, String line) {
    dir.createSync(recursive: true);
    f.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  }

  /// rename first so nothing gets lost
  List<Map<String, Object?>> _take(File f) {
    if (!f.existsSync()) return const [];
    final taking = File('${f.path}.taking');
    try {
      if (!taking.existsSync()) f.renameSync(taking.path);
    } catch (_) {
      return const []; // helper is mid write, next time
    }
    final out = <Map<String, Object?>>[];
    for (final line in taking.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        out.add((jsonDecode(line) as Map).cast());
      } catch (_) {}
    }
    taking.deleteSync();
    return out;
  }
}
