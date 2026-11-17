import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../platform/android_link.dart';
import '../theme.dart';
import 'common.dart';

/// android app picker (launcher apps + search)
class AndroidAppPicker extends StatefulWidget {
  const AndroidAppPicker({super.key, required this.already});

  final List<AppRef> already;

  @override
  State<AndroidAppPicker> createState() => _AndroidAppPickerState();
}

class _AndroidAppPickerState extends State<AndroidAppPicker> {
  final _apps = AndroidLink.apps();
  final _picked = <String, AppRef>{};
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _has(String id) => widget.already.any((a) => a.matches(id));

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Add apps', 'Uygulama ekle'), style: body(24, weight: FontWeight.w500, color: c.onSurface)),
      const SizedBox(height: 6),
      Text(tr('They close as soon as they open while the block is on.', 'Engel açıkken açılır açılmaz kapanırlar.'),
          style: body(15, color: c.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 12),
      NlField(
        label: tr('Search', 'Ara'),
        hint: tr('e.g. TikTok', 'ör. TikTok'),
        controller: _search,
        dense: true,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .45),
        child: FutureBuilder<List<(String, String)>>(
          future: _apps,
          builder: (context, snap) {
            if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            final q = _search.text.trim().toLowerCase();
            final list = snap.data!.where((a) => q.isEmpty || a.$2.toLowerCase().contains(q) || a.$1.contains(q)).toList();
            if (list.isEmpty) {
              return Padding(padding: const EdgeInsets.all(16), child: Text(tr('No app with that name.', 'Bu adda bir uygulama yok.'), style: body(15, color: c.onSurfaceVariant)));
            }
            return ListView(shrinkWrap: true, children: [
              for (final (id, name) in list)
                CheckboxListTile(
                  value: _has(id) || _picked.containsKey(id),
                  onChanged: _has(id) ? null : (v) => setState(() => v! ? _picked[id] = AppRef(name: name, ids: [id]) : _picked.remove(id)),
                  title: Text(name, style: body(16, color: c.onSurface)),
                  subtitle: _has(id) ? Text(tr('Already in this block', 'Zaten bu engelde'), style: body(13, color: c.onSurfaceVariant)) : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
            ]);
          },
        ),
      ),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Btn(tr('Cancel', 'İptal'), kind: BtnKind.text, onPressed: () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(_picked.isEmpty ? tr('Add', 'Ekle') : tr('Add ${_picked.length}', '${_picked.length} tane ekle'),
            icon: Symbols.check_rounded, onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, _picked.values.toList())),
      ]),
    ]);
  }
}
