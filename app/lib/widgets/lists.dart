import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../theme.dart';
import 'common.dart';

/// word input, enter or commas
class KeywordEditor extends StatefulWidget {
  const KeywordEditor({
    super.key,
    required this.keywords,
    required this.onChanged,
    this.canRemove = true,
    this.fill,
    this.hint,
    this.label,
    this.limit = 12,
  });

  final List<String> keywords;
  final ValueChanged<List<String>> onChanged;
  final bool canRemove;
  final Color? fill;
  final String? hint;
  final String? label;
  final int limit;

  @override
  State<KeywordEditor> createState() => _KeywordEditorState();
}

class _KeywordEditorState extends State<KeywordEditor> {
  final _ctl = TextEditingController();
  bool _all = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _add(String text) {
    final have = {for (final k in widget.keywords) k.toLowerCase()};
    final add = text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty && have.add(s.toLowerCase())).toList();
    _ctl.clear();
    if (add.isNotEmpty) widget.onChanged([...widget.keywords, ...add]);
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.keywords;
    final shown = _all ? list : list.take(widget.limit).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      NlField(
        label: widget.label ?? tr('Add a keyword', 'Anahtar kelime ekle'),
        icon: Symbols.add_rounded,
        hint: widget.hint ?? tr('e.g. trailer', 'ör. fragman'),
        controller: _ctl,
        onSubmitted: _add,
        fill: widget.fill,
      ),
      if (list.isNotEmpty) const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in shown) ItemChip(k, onRemove: widget.canRemove ? () => widget.onChanged([...list]..remove(k)) : null),
        if (list.length > widget.limit)
          NlChip(_all ? tr('Show fewer', 'Daha az göster') : tr('Show all ${list.length}', '${list.length} tanesinin tümünü göster'),
              onTap: () => setState(() => _all = !_all)),
      ]),
    ]);
  }
}

class WordsEditor extends StatefulWidget {
  const WordsEditor({super.key, required this.block, required this.onChanged, this.canRemove = true, this.fill, this.headings = true});

  final Block block;
  final void Function(List<String> keywords, List<String> spoilerWords, List<String> topicWords) onChanged;
  final bool canRemove;
  final Color? fill;

  /// headings (new block page only)
  final bool headings;

  @override
  State<WordsEditor> createState() => _WordsEditorState();
}

class _WordsEditorState extends State<WordsEditor> {
  late bool _open = widget.block.spoilerWords.isNotEmpty || widget.block.topicWords.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final b = widget.block;
    final contextCount = b.spoilerWords.length + b.topicWords.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.headings) SubHead(Symbols.text_fields_rounded, tr('Keywords', 'Anahtar kelimeler'), b.keywords.length),
      KeywordEditor(
        keywords: b.keywords,
        canRemove: widget.canRemove,
        fill: widget.fill,
        onChanged: (k) => widget.onChanged(k, b.spoilerWords, b.topicWords),
      ),
      const SizedBox(height: 12),
      Material(
        color: c.surfaceHigh.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(children: [
                Ms(Symbols.join_inner_rounded, size: 20, color: c.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      contextCount == 0
                          ? tr('Words that need context', 'Bağlam gerektiren kelimeler')
                          : tr('Words that need context, $contextCount', 'Bağlam gerektiren kelimeler, $contextCount'),
                      style: body(15, weight: FontWeight.w500, color: c.onSurface),
                    ),
                    Text(
                      tr('Like "ending", only hidden when the post is about your topic',
                          '"final*" gibi, yalnızca gönderi konunla ilgiliyse gizlenir. Sondaki * ekli halleri de yakalar'),
                      style: body(13, color: c.onSurfaceVariant),
                    ),
                  ]),
                ),
                AnimatedRotation(
                  turns: _open ? .5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Ms(Symbols.expand_more_rounded, color: c.onSurfaceVariant),
                ),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(
                        tr('A spoiler word only hides a post that also has a topic word or a keyword, so "dies" is hidden in "Lucia dies in the prologue" but not in other posts.',
                            'Spoiler kelimesi bir gönderiyi yalnızca içinde bir konu kelimesi veya anahtar kelime de varsa gizler; yani "ölüyor", "Lucia girişte ölüyor" gönderisinde gizlenir ama başka gönderilerde gizlenmez.'),
                        style: body(13, color: c.onSurfaceVariant, height: 1.4),
                      ),
                      SubHead(Symbols.warning_rounded, tr('Spoiler words', 'Spoiler kelimeleri'), b.spoilerWords.length),
                      KeywordEditor(
                        keywords: b.spoilerWords,
                        canRemove: widget.canRemove,
                        fill: c.surfaceHigh,
                        label: tr('Add a spoiler word', 'Spoiler kelimesi ekle'),
                        hint: tr('e.g. ending', 'ör. final*'),
                        onChanged: (s) => widget.onChanged(b.keywords, s, b.topicWords),
                      ),
                      SubHead(Symbols.tag_rounded, tr('Topic words', 'Konu kelimeleri'), b.topicWords.length),
                      KeywordEditor(
                        keywords: b.topicWords,
                        canRemove: widget.canRemove,
                        fill: c.surfaceHigh,
                        label: tr('Add a topic word', 'Konu kelimesi ekle'),
                        hint: tr('e.g. GTA', 'ör. GTA'),
                        onChanged: (t) => widget.onChanged(b.keywords, b.spoilerWords, t),
                      ),
                    ]),
                  ),
          ),
        ]),
      ),
    ]);
  }
}

class SubHead extends StatelessWidget {
  const SubHead(this.icon, this.title, this.count, {super.key});

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 12),
      child: Row(children: [
        Ms(icon, size: 20, color: c.primary),
        const SizedBox(width: 8),
        Text(title, style: body(14, weight: FontWeight.w600, color: c.onSurface)),
        if (count > 0) ...[const SizedBox(width: 8), Text('$count', style: body(14, weight: FontWeight.w500, color: c.onSurfaceVariant))],
      ]),
    );
  }
}

/// site input, normalised on add
class SiteEditor extends StatefulWidget {
  const SiteEditor({
    super.key,
    required this.sites,
    required this.onChanged,
    this.canRemove = true,
    this.rows = false,
    this.fill,
    this.hint,
    this.label,
    this.requirePath = false,
  });

  final List<String> sites;
  final ValueChanged<List<String>> onChanged;
  final bool canRemove;

  /// rows instead of chips
  final bool rows;
  final Color? fill;
  final String? hint;
  final String? label;

  /// istisnalar: alan adının tamamı değil, bir kanal/profil yolu gerekir (ör. x.com/hesap)
  final bool requirePath;

  @override
  State<SiteEditor> createState() => _SiteEditorState();
}

class _SiteEditorState extends State<SiteEditor> {
  final _ctl = TextEditingController();
  String? _error;
  bool _all = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _add(String text) {
    final added = <String>[];
    final have = {for (final s in widget.sites) s.toLowerCase()};
    for (final part in text.split(RegExp(r'[,\s]+')).where((p) => p.isNotEmpty)) {
      final s = SiteRule.normalize(part);
      if (s == null) {
        setState(() => _error = tr("\"$part\" doesn't look like a site. Try something like reddit.com or reddit.com/r/GTA6.",
            '"$part" bir siteye benzemiyor. reddit.com veya reddit.com/r/GTA6 gibi bir şey dene.'));
        return;
      }
      if (widget.requirePath && !s.contains('/')) {
        setState(() => _error = tr('"$part" is a whole site. Add a channel or profile address instead, like youtube.com/@yourchannel.',
            '"$part" bir sitenin tamamı. Bunun yerine bir kanal veya profil adresi ekle, ör. youtube.com/@kanalin ya da x.com/hesabin.'));
        return;
      }
      if (have.add(s.toLowerCase())) added.add(s);
    }
    _ctl.clear();
    setState(() => _error = null);
    if (added.isNotEmpty) widget.onChanged([...widget.sites, ...added]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final limit = widget.rows ? 5 : 10;
    final list = widget.sites;
    final shown = _all ? list : list.take(limit).toList();
    void remove(String s) => widget.onChanged([...list]..remove(s));
    final more = _all ? tr('Show fewer', 'Daha az göster') : tr('Show all ${list.length}', '${list.length} tanesinin tümünü göster');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      NlField(
        label: widget.label ?? tr('Add a site', 'Site ekle'),
        icon: Symbols.add_rounded,
        hint: widget.hint ?? tr('e.g. gtaforums.com', 'ör. gtaforums.com'),
        controller: _ctl,
        onSubmitted: _add,
        fill: widget.fill,
      ),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: body(14, color: c.error))),
      if (list.isNotEmpty) const SizedBox(height: 12),
      if (widget.rows)
        for (final (i, s) in shown.indexed)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: i == 0 ? null : Border(top: BorderSide(color: c.onSurface.withValues(alpha: .07))),
            ),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text(s.characters.first, style: body(13, weight: FontWeight.w600, color: c.onSurfaceVariant)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s, style: body(15, color: c.onSurface)),
                  if (s.contains('/') && !s.contains('?'))
                    Text(tr('and everything under it', 've altındaki her şey'), style: body(13, color: c.onSurfaceVariant)),
                ]),
              ),
              if (widget.canRemove) IconBtn(Symbols.close_rounded, tooltip: tr('Remove', 'Kaldır'), onPressed: () => remove(s)),
            ]),
          )
      else
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in shown) ItemChip(s, onRemove: widget.canRemove ? () => remove(s) : null),
        ]),
      if (list.length > limit)
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(top: widget.rows ? 4 : 8),
            child: widget.rows
                ? Btn(more, kind: BtnKind.text, onPressed: () => setState(() => _all = !_all))
                : NlChip(more, onTap: () => setState(() => _all = !_all)),
          ),
        ),
    ]);
  }
}
