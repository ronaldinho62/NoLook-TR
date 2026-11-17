import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../controller.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/block_card.dart';
import '../widgets/common.dart';
import 'block.dart';
import 'edit_block.dart';

enum _Filter { all, on, off, locked }

class BlocksPage extends StatefulWidget {
  const BlocksPage({super.key, required this.app});

  final NoLook app;

  @override
  State<BlocksPage> createState() => _BlocksPageState();
}

class _BlocksPageState extends State<BlocksPage> {
  _Filter _filter = _Filter.all;
  bool _searching = false;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final c = context.nl;
    final app = widget.app;
    final now = app.now;
    final all = app.state.blocks;
    final q = _search.text.trim().toLowerCase();

    final shown = all.where((b) {
      final f = switch (_filter) {
        _Filter.all => true,
        _Filter.on => b.isOn(now),
        _Filter.off => !b.isOn(now),
        _Filter.locked => b.isLocked(now),
      };
      if (!f) return false;
      if (q.isEmpty) return true;
      return b.name.toLowerCase().contains(q) ||
          b.sites.any((s) => s.toLowerCase().contains(q)) ||
          b.apps.any((a) => a.name.toLowerCase().contains(q));
    }).toList();

    int n(_Filter f) => all.where((b) => switch (f) {
          _Filter.all => true,
          _Filter.on => b.isOn(now),
          _Filter.off => !b.isOn(now),
          _Filter.locked => b.isLocked(now),
        }).length;

    final newCard = DottedBorder(
      options: RoundedRectDottedBorderOptions(
        radius: Radius.circular(context.isPhone ? 24 : 28),
        color: c.outlineVariant,
        strokeWidth: 2,
        dashPattern: const [6, 5],
        padding: EdgeInsets.zero,
        stackFit: StackFit.expand,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => go(context, EditBlockPage(app: app)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 220),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Ms(Symbols.add_rounded, size: 32, color: c.primary),
                const SizedBox(height: 10),
                Text(tr('New block', 'Yeni engel'), style: body(15, weight: FontWeight.w500, color: c.primary)),
              ]),
            ),
          ),
        ),
      ),
    );

    return NlPage(children: [
      PageBar(title: tr('Blocks', 'Engeller'), actions: [
        IconBtn(_searching ? Symbols.close_rounded : Symbols.search_rounded,
            tooltip: _searching ? tr('Stop searching', 'Aramayı kapat') : tr('Search', 'Ara'),
            onPressed: () => setState(() {
                  _searching = !_searching;
                  _search.clear();
                })),
        if (!context.isPhone) ...[
          const SizedBox(width: 4),
          Btn(tr('New block', 'Yeni engel'), icon: Symbols.add_rounded, onPressed: () => go(context, EditBlockPage(app: app))),
        ],
      ]),
      if (_searching)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: NlField(
            label: tr('Search blocks', 'Engellerde ara'),
            icon: Symbols.search_rounded,
            controller: _search,
            autofocus: true,
            hint: tr('A name, site or app', 'Ad, site veya uygulama'),
            onChanged: (_) => setState(() {}),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          NlChip(tr('All ${n(_Filter.all)}', 'Tümü ${n(_Filter.all)}'), selected: _filter == _Filter.all, onTap: () => setState(() => _filter = _Filter.all)),
          NlChip(tr('On ${n(_Filter.on)}', 'Açık ${n(_Filter.on)}'), selected: _filter == _Filter.on, onTap: () => setState(() => _filter = _Filter.on)),
          NlChip(tr('Off ${n(_Filter.off)}', 'Kapalı ${n(_Filter.off)}'), selected: _filter == _Filter.off, onTap: () => setState(() => _filter = _Filter.off)),
          NlChip(tr('Locked ${n(_Filter.locked)}', 'Kilitli ${n(_Filter.locked)}'),
              icon: Symbols.lock_rounded, selected: _filter == _Filter.locked, onTap: () => setState(() => _filter = _Filter.locked)),
        ]),
      ),
      Grid12(items: [
        for (final b in shown)
          (cardSpan(context, count: shown.length + (q.isEmpty && _filter == _Filter.all ? 1 : 0)), BlockCard(app: app, block: b, style: BlockCardStyle.list, onOpen: () => go(context, BlockPage(app: app, id: b.id)))),
        if (q.isEmpty && _filter == _Filter.all) (cardSpan(context, count: shown.length + 1), newCard),
      ]),
      if (shown.isEmpty && (q.isNotEmpty || _filter != _Filter.all))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(tr('No blocks here.', 'Burada engel yok.'), style: body(15, color: c.onSurfaceVariant)),
        ),
    ]);
  }
}
