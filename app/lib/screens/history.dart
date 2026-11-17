import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../controller.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/events.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.app});

  final NoLook app;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  /// null = all, "unlocks", or a block id
  String? _filter;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final c = context.nl;
    final app = widget.app;
    final now = app.now;
    final stats = app.stats;
    final unlocks = stats.unlocksThisWeek;
    final streak = stats.daysWithoutUnlock;

    final events = app.state.events.reversed.where((e) {
      if (_filter == null) return true;
      if (_filter == 'unlocks') return e.isUnlock;
      return e.blockId == _filter;
    }).toList();

    final today = DateTime(now.year, now.month, now.day);
    String dayLabel(DateTime t) {
      final d = DateTime(t.year, t.month, t.day);
      if (d == today) return tr('Today', 'Bugün');
      if (d == today.subtract(const Duration(days: 1))) return tr('Yesterday', 'Dün');
      return Describe.day(d, now);
    }

    final groups = <String, List<HistoryEvent>>{};
    for (final e in events) {
      groups.putIfAbsent(dayLabel(e.time), () => []).add(e);
    }

    Widget stat(String n, String label, {bool big = false}) => NlCard(
          color: big ? c.tertiaryContainer : c.surfaceMid,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: display(36, color: big ? c.onTertiaryContainer : c.onSurface)),
            const SizedBox(height: 6),
            Text(label, style: body(14, color: big ? c.onTertiaryContainer : c.onSurfaceVariant)),
          ]),
        );

    return NlPage(children: [
      PageBar(
        title: tr('History', 'Geçmiş'),
        leading: IconBtn(Symbols.arrow_back_rounded, tooltip: tr('Back', 'Geri'), onPressed: () => Navigator.pop(context)),
      ),
      Grid12(items: [
        (3, stat('${stats.hiddenToday}', tr('hidden today', 'bugün gizlendi'))),
        (3, stat('${stats.hiddenThisWeek}', tr('this week', 'bu hafta'))),
        (3, stat('$unlocks', tr(unlocks == 1 ? 'early unlock this week' : 'early unlocks this week', 'bu hafta erken kilit açma'))),
        (3, stat('$streak', tr(streak == 1 ? 'day with no unlock' : 'days in a row with no unlock', 'gündür kilit açılmadı'), big: true)),
      ]),
      const SizedBox(height: 20),
      Wrap(spacing: 8, runSpacing: 8, children: [
        NlChip(tr('Everything', 'Tümü'), selected: _filter == null, onTap: () => setState(() => _filter = null)),
        for (final b in app.state.blocks)
          NlChip(b.name, selected: _filter == b.id, onTap: () => setState(() => _filter = b.id)),
        NlChip(tr('Unlocks', 'Kilit açmalar'), icon: Symbols.lock_open_rounded, selected: _filter == 'unlocks', onTap: () => setState(() => _filter = 'unlocks')),
      ]),
      const SizedBox(height: 16),
      if (events.isEmpty)
        NlCard(
          color: c.surfaceLow,
          child: Text(_filter == null ? tr('Nothing here yet.', 'Burada henüz bir şey yok.') : tr('Nothing for this one yet.', 'Bunun için henüz bir şey yok.'), style: body(15, color: c.onSurfaceVariant)),
        ),
      for (final g in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(g.key, style: body(14, weight: FontWeight.w600, color: c.primary)),
        ),
        NlCard(
          color: c.surfaceLow,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Column(children: [
            for (final e in g.value)
              EventRow(e, end: Describe.time(e.time), sayKeyword: app.state.settings.sayKeyword, withWhere: true),
          ]),
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}
