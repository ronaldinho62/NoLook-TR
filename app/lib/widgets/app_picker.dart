import 'dart:io';

import '../platform/os.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../platform/windows_apps.dart' as win;
import '../screens/unlock.dart';
import '../theme.dart';
import 'android_app_picker.dart';
import 'common.dart';

/// windows app picker (open windows or a typed name)
Future<List<AppRef>?> pickApps(BuildContext context, {required List<AppRef> already}) =>
    showNlDialog<List<AppRef>>(context, (ctx) => onAndroid ? AndroidAppPicker(already: already) : _AppPicker(already: already), width: 520);

class _AppPicker extends StatefulWidget {
  const _AppPicker({required this.already});

  final List<AppRef> already;

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  late final List<win.RunningApp> _running = Platform.isWindows ? win.appsWithWindows() : const [];
  final _picked = <String, AppRef>{};
  final _typed = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool _has(String exe) => widget.already.any((a) => a.matches(exe));

  void _addTyped() {
    var t = _typed.text.trim();
    if (t.isEmpty) return;
    if (!t.toLowerCase().endsWith('.exe')) t = '$t.exe';
    final exe = t.split(RegExp(r'[\\/]')).last.toLowerCase();
    if (win.protectedExes.contains(exe)) {
      setState(() => _error = tr("That's part of Windows, so it can't be blocked.", 'Bu Windows\'un bir parçası, bu yüzden engellenemez.'));
      return;
    }
    final base = exe.substring(0, exe.length - 4);
    setState(() {
      _picked[exe] = AppRef(name: base.isEmpty ? exe : base[0].toUpperCase() + base.substring(1), ids: [exe]);
      _typed.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Add apps', 'Uygulama ekle'), style: body(24, weight: FontWeight.w500, color: c.onSurface)),
      const SizedBox(height: 6),
      Text(tr('Your open apps show up here, if one is missing, open it and come back or type its program name.', 'Açık uygulamaların burada görünür, biri eksikse onu açıp geri gel ya da program adını yaz.'),
          style: body(15, color: c.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ListView(shrinkWrap: true, children: [
          for (final a in _running)
            CheckboxListTile(
              value: _has(a.exe) || _picked.containsKey(a.exe),
              onChanged: _has(a.exe)
                  ? null
                  : (v) => setState(() => v! ? _picked[a.exe] = AppRef(name: a.name, ids: [a.exe]) : _picked.remove(a.exe)),
              title: Text(a.name, style: body(16, color: c.onSurface)),
              subtitle: Text(_has(a.exe) ? tr('Already in this block', 'Zaten bu engelde') : a.exe, style: body(13, color: c.onSurfaceVariant)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          for (final p in _picked.values.where((p) => !_running.any((r) => r.exe == p.ids.first)))
            CheckboxListTile(
              value: true,
              onChanged: (_) => setState(() => _picked.remove(p.ids.first)),
              title: Text(p.name, style: body(16, color: c.onSurface)),
              subtitle: Text(p.ids.first, style: body(13, color: c.onSurfaceVariant)),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: NlField(
            label: tr('Program name', 'Program adı'),
            hint: tr('e.g. discord.exe', 'ör. discord.exe'),
            controller: _typed,
            dense: true,
            onSubmitted: (_) => _addTyped(),
          ),
        ),
        const SizedBox(width: 8),
        Btn(tr('Add', 'Ekle'), kind: BtnKind.tonal, onPressed: _addTyped),
      ]),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: body(14, color: c.error))),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Btn(tr('Cancel', 'İptal'), kind: BtnKind.text, onPressed: () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(_picked.isEmpty ? tr('Add', 'Ekle') : tr('Add ${_picked.length}', '${_picked.length} tane ekle'),
            icon: Symbols.check_rounded,
            onPressed: _picked.isEmpty ? null : () => Navigator.pop(context, _picked.values.toList())),
      ]),
    ]);
  }
}
