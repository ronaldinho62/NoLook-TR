import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import 'common.dart';

IconData eventIcon(HistoryEvent e) => switch (e.kind) {
      EventKind.blurred => e.target.contains('youtube') ? Symbols.smart_display_rounded : Symbols.visibility_off_rounded,
      EventKind.blocked => Symbols.block_rounded,
      EventKind.closedApp => Symbols.close_rounded,
      EventKind.unlocked => Symbols.lock_open_rounded,
      EventKind.emergency => Symbols.emergency_rounded,
    };

String eventTitle(HistoryEvent e) {
  final elsewhere = e.where.isNotEmpty && e.where != 'this PC' && e.where != 'this phone' && e.kind == EventKind.closedApp;
  final n = e.count;
  final covered = e.where == 'this phone';
  return switch (e.kind) {
    EventKind.blurred when covered => n == 1
        ? tr('Covered a post on ${e.target}', '${e.target} üzerinde bir gönderi örtüldü')
        : tr('Covered $n posts on ${e.target}', '${e.target} üzerinde $n gönderi örtüldü'),
    EventKind.blurred when e.target.contains('youtube') =>
      n == 1 ? tr('Blurred a YouTube video', 'Bir YouTube videosu bulanıklaştırıldı') : tr('Blurred $n YouTube videos', '$n YouTube videosu bulanıklaştırıldı'),
    EventKind.blurred => n == 1
        ? tr('Blurred a post on ${e.target}', '${e.target} üzerinde bir gönderi bulanıklaştırıldı')
        : tr('Blurred $n posts on ${e.target}', '${e.target} üzerinde $n gönderi bulanıklaştırıldı'),
    EventKind.blocked => tr('Blocked ${e.target}', '${e.target} engellendi'),
    EventKind.closedApp => elsewhere
        ? tr('Closed ${e.target} on ${e.where}', '${e.target} kapatıldı (${e.where})')
        : tr('Closed ${e.target}', '${e.target} kapatıldı'),
    EventKind.unlocked => tr('Unlocked ${e.blockName} early', '${e.blockName} engelinin kilidi erken açıldı'),
    EventKind.emergency => tr('Emergency unlock for ${e.blockName}', '${e.blockName} için acil kilit açma'),
  };
}

String _quoted(List<String> m) => m.map((k) => '"$k"').join(', ');

/// event subtitle
String eventSubtitle(HistoryEvent e, {required bool sayKeyword, bool withBlock = true, bool withWhere = false}) {
  final parts = <String>[
    if (withBlock && e.blockName.isNotEmpty && !e.isUnlock) e.blockName,
    if (e.matched.isNotEmpty && sayKeyword) tr('matched ${_quoted(e.matched)}', 'eşleşen: ${_quoted(e.matched)}'),
    if (e.isUnlock && e.note.isNotEmpty) e.note,
    if (withWhere && e.where.isNotEmpty && !e.isUnlock) where(e.where),
  ];
  final s = parts.join(', ');
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

String where(String w) {
  if (!isTr) return const {'Chrome', 'Edge', 'Firefox'}.contains(w) ? 'in $w' : 'on $w';
  return switch (w) {
    'this PC' => 'bu bilgisayarda',
    'this phone' => 'bu telefonda',
    'Chrome' => "Chrome'da",
    'Edge' => "Edge'de",
    'Firefox' => "Firefox'ta",
    _ => '$w cihazında',
  };
}

/// short age string
String ago(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inMinutes < 1) return tr('now', 'şimdi');
  if (d.inMinutes < 60) return tr('${d.inMinutes} min', '${d.inMinutes} dk');
  if (d.inHours < 24) return tr('${d.inHours} h', '${d.inHours} sa');
  return tr('${d.inDays} d', '${d.inDays} gün');
}

class EventRow extends StatelessWidget {
  const EventRow(this.e, {super.key, required this.end, required this.sayKeyword, this.withWhere = false});

  final HistoryEvent e;
  final String end;
  final bool sayKeyword;
  final bool withWhere;

  @override
  Widget build(BuildContext context) => NlRow(
        icon: eventIcon(e),
        title: eventTitle(e),
        subtitle: eventSubtitle(e, sayKeyword: sayKeyword, withWhere: withWhere),
        end: RowEnd(end),
      );
}
