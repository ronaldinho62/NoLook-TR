import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../platform/os.dart';
import '../controller.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/app_picker.dart';
import '../widgets/block_card.dart';
import '../widgets/common.dart';
import '../widgets/lists.dart';
import 'devices.dart';
import 'edit_block.dart';
import 'unlock.dart';

class BlockPage extends StatelessWidget {
  const BlockPage({super.key, required this.app, required this.id});

  final NoLook app;
  final String id;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (context, _) {
        final b = app.state.block(id);
        if (b == null) return const SizedBox();
        return _build(context, b);
      });

  void _change(BuildContext context, Block b, void Function(Block copy) edit) {
    final copy = b.copy();
    edit(copy);
    final problems = app.updateBlock(copy);
    if (problems.isNotEmpty) toast(context, problems.first);
  }

  /// offer new preset words/sites
  Widget? _presetBanner(BuildContext context, Block b, Preset? preset) {
    if (preset == null) return null;
    final m = preset.missingFrom(b);
    final n = m.keywords.length + m.spoilerWords.length + m.topicWords.length + m.sites.length;
    if (n == 0) return null;
    final c = context.nl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NlCard(
        color: c.primaryContainer,
        child: Row(children: [
          Ms(Symbols.new_releases_rounded, color: c.onPrimaryContainer),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('The ${preset.name} preset has $n new ${n == 1 ? 'entry' : 'entries'}', '${preset.name} hazır listesinde $n yeni öğe var'),
                  style: body(16, weight: FontWeight.w600, color: c.onPrimaryContainer)),
              Text(
                [...m.keywords, ...m.topicWords, ...m.spoilerWords, ...m.sites].take(6).join(', ') + (n > 6 ? '...' : ''),
                style: body(13, color: c.onPrimaryContainer.withValues(alpha: .8)),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Btn(tr('Add them', 'Ekle'), onPressed: () => _change(context, b, (x) => x
            ..keywords = [...x.keywords, ...m.keywords]
            ..spoilerWords = [...x.spoilerWords, ...m.spoilerWords]
            ..topicWords = [...x.topicWords, ...m.topicWords]
            ..sites = [...x.sites, ...m.sites])),
        ]),
      ),
    );
  }

  Widget _build(BuildContext context, Block b) {
    final c = context.nl;
    final now = app.now;
    final locked = b.isLocked(now);
    final phone = context.isPhone;
    final (bg, fg) = c.block(b.color);
    final preset = presets.where((p) => p.id == b.presetId).firstOrNull;
    final devices = 1 + app.state.browsersSeen.length;
    final presetBanner = _presetBanner(context, b, preset);

    final hero = ClipRRect(
      borderRadius: BorderRadius.circular(phone ? 24 : 28),
      child: Container(
        color: bg,
        child: Stack(children: [
          Positioned(
            right: -60,
            bottom: -90,
            child: Blob(size: 260, color: fg.withValues(alpha: .06), radii: const [.58, .42, .40, .60, .55, .45, .55, .45]),
          ),
          Padding(
            padding: EdgeInsets.all(phone ? 20 : 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                BlockIcon(b, size: 64, color: fg),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.name, style: display(phone ? 24 : 30, color: fg, height: 1.15)),
                    if (preset != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(tr('From the ${preset.name} preset', '${preset.name} hazır listesinden'), style: body(15, color: fg.withValues(alpha: .75))),
                      ),
                  ]),
                ),
                NlSwitch(
                  value: b.isOn(now),
                  locked: locked,
                  scale: 1.2,
                  tooltip: locked ? tr('Locked, click to unlock early', 'Kilitli, erken açmak için tıkla') : null,
                  onTap: () => tapSwitch(context, app, b),
                ),
              ]),
              const SizedBox(height: 20),
              Wrap(spacing: 28, runSpacing: 12, children: [
                for (final (n, label) in [
                  ('${app.stats.hiddenTodayFor(b.id)}', tr('hidden today', 'bugün gizlendi')),
                  ('${app.state.totals[b.id] ?? 0}', tr('hidden in total', 'toplam gizlendi')),
                  ('$devices', devices == 1 ? tr('device', 'cihaz') : tr('devices', 'cihaz')),
                ])
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n, style: display(30, color: fg)),
                    Text(label, style: body(14, color: fg.withValues(alpha: .75))),
                  ]),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: c.wash.withValues(alpha: .5), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Ms(lockIcon(b, now), size: 20, color: fg, fill: lockIcon(b, now) == Symbols.lock_rounded),
                  const SizedBox(width: 10),
                  Expanded(child: lockText(b, now, fg, size: 15)),
                  if (locked && !phone)
                    Text(tr('Tap the switch to unlock early', 'Erken açmak için anahtara dokun'), style: body(13, color: fg.withValues(alpha: .75))),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );

    Widget sect(String title, {String? count, String? text, required Widget child, bool low = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NlCard(
            color: low ? c.surfaceLow : c.surfaceMid,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text(title, style: body(18, weight: FontWeight.w600, color: c.onSurface)),
                if (count != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(999)),
                    child: Text(count, style: body(13, weight: FontWeight.w500, color: c.onSurfaceVariant)),
                  ),
                ],
              ]),
              if (text != null) ...[const SizedBox(height: 4), Text(text, style: body(14, color: c.onSurfaceVariant))],
              const SizedBox(height: 16),
              child,
            ]),
          ),
        );

    Widget opt(IconData? icon, String t, String s, {Widget? end, bool first = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: first ? null : Border(top: BorderSide(color: c.onSurface.withValues(alpha: .07))),
          ),
          child: Row(children: [
            if (icon != null) ...[Ms(icon, color: c.onSurfaceVariant), const SizedBox(width: 14)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: body(15, color: c.onSurface)),
                Text(s, style: body(13, color: c.onSurfaceVariant)),
              ]),
            ),
            ?end,
          ]),
        );

    final change = Btn(tr('Change', 'Değiştir'), kind: BtnKind.text, onPressed: () => go(context, EditBlockPage(app: app, editing: b, openAdvanced: true)));

    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ?presetBanner,
      sect(tr('Keywords', 'Anahtar kelimeler'),
          count: '${b.wordCount}',
          text: onMobile ? tr('Anything that mentions these gets covered.', 'Bunlardan bahseden her şey örtülür.') : tr('Anything that mentions these gets blurred.', 'Bunlardan bahseden her şey bulanıklaştırılır.'),
          child: WordsEditor(
            block: b,
            canRemove: !locked,
            headings: false,
            fill: c.surfaceMid,
            onChanged: (k, s, t) => _change(context, b, (x) => x
              ..keywords = k
              ..spoilerWords = s
              ..topicWords = t),
          )),
      sect(tr('Sites', 'Siteler'),
          count: '${b.sites.length}',
          text: tr('These sites get blocked.', 'Bu siteler engellenir.'),
          child: SiteEditor(
            sites: b.sites,
            rows: true,
            canRemove: !locked,
            hint: tr('e.g. reddit.com/r/GTA6', 'ör. reddit.com/r/GTA6'),
            fill: c.surfaceMid,
            onChanged: (s) => _change(context, b, (x) => x.sites = s),
          )),
      // mac/linux can still get apps via sync
      if (closesApps || b.apps.isNotEmpty)
      sect(tr('Apps', 'Uygulamalar'),
          count: '${b.apps.length}',
          text: closesApps
              ? tr('These apps get closed as soon as they open.', 'Bu uygulamalar açılır açılmaz kapatılır.')
              : tr('These get closed on your Windows PCs and Android phones, not on this computer.', 'Bunlar bu bilgisayarda değil, Windows bilgisayarlarında ve Android telefonlarında kapatılır.'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final a in b.apps)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(8)),
                    child: Ms(Symbols.apps_rounded, size: 18, color: c.onSurfaceVariant),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.name, style: body(15, color: c.onSurface)),
                      Text(a.ids.join(', '), style: body(13, color: c.onSurfaceVariant)),
                    ]),
                  ),
                  if (!locked)
                    IconBtn(Symbols.close_rounded,
                        tooltip: tr('Remove', 'Kaldır'), onPressed: () => _change(context, b, (x) => x.apps = [...x.apps]..remove(a))),
                ]),
              ),
            const SizedBox(height: 4),
            if (closesApps)
            Btn(tr('Add an app', 'Uygulama ekle'), icon: Symbols.add_rounded, kind: BtnKind.outlined, onPressed: () async {
              final picked = await pickApps(context, already: b.apps);
              if (picked != null && context.mounted) _change(context, b, (x) => x.apps = [...x.apps, ...picked]);
            }),
          ])),
    ]);

    final right = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (locked)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: c.surfaceLow, borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Ms(Symbols.info_rounded, size: 20, color: c.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tr("While it's locked, you can add things but not remove them.", 'Kilitliyken ekleme yapabilirsin ama kaldıramazsın.'),
                  style: body(14, color: c.onSurfaceVariant)),
            ),
          ]),
        ),
      sect(tr("When it's on", 'Ne zaman açık'),
          low: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Seg<bool>(
              options: [(true, tr('Always', 'Her zaman'), Symbols.all_inclusive_rounded), (false, tr('On a schedule', 'Zamanlamaya göre'), Symbols.schedule_rounded)],
              value: b.schedule.always,
              onChanged: (always) {
                if (locked) {
                  toast(context, tr("The schedule can't change while it's locked.", 'Kilitliyken zamanlama değiştirilemez.'));
                } else if (always) {
                  _change(context, b, (x) => x.schedule = const Schedule.always());
                } else {
                  go(context, EditBlockPage(app: app, editing: b));
                }
              },
            ),
            if (!b.schedule.always)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(children: [
                  Expanded(child: Text(b.schedule.describe(), style: body(14, color: c.onSurfaceVariant))),
                  if (!locked) Btn(tr('Change', 'Değiştir'), kind: BtnKind.text, onPressed: () => go(context, EditBlockPage(app: app, editing: b))),
                ]),
              ),
          ])),
      sect(tr('Lock', 'Kilit'),
          low: true,
          child: Column(children: [
            opt(
              switch (b.lock) {
                LockKind.none => Symbols.lock_open_rounded,
                LockKind.untilDate => Symbols.event_rounded,
                LockKind.wait => Symbols.hourglass_top_rounded,
                LockKind.type => Symbols.keyboard_rounded,
              },
              first: true,
              switch (b.lock) {
                LockKind.none => tr('No lock', 'Kilit yok'),
                LockKind.untilDate => tr('Until a date', 'Bir tarihe kadar'),
                LockKind.wait => tr('Wait to unlock', 'Beklemeyle açılır'),
                LockKind.type => tr('Type to unlock', 'Yazarak açılır'),
              },
              switch (b.lock) {
                LockKind.untilDate when b.lockedUntil != null => locked
                    ? tr('${Describe.day(b.lockedUntil!, now)} ${b.lockedUntil!.year}, ${b.lockedUntil!.difference(now).inDays + 1} days left',
                        '${Describe.day(b.lockedUntil!, now)} ${b.lockedUntil!.year}, ${b.lockedUntil!.difference(now).inDays + 1} gün kaldı')
                    : tr('Ended ${Describe.day(b.lockedUntil!, now)}', 'Bitti: ${Describe.day(b.lockedUntil!, now)}'),
                LockKind.none => tr('Turn it off any time', 'İstediğin zaman kapatabilirsin'),
                _ => tr("Always locked while it's on", 'Açıkken her zaman kilitli'),
              },
              end: change,
            ),
            if (b.lock != LockKind.none) ...[
              opt(Symbols.hourglass_top_rounded, tr('To unlock early', 'Erken açmak için'), Describe.unlockSteps(b), end: change),
              opt(Symbols.replay_rounded, tr('After unlocking early', 'Erken açtıktan sonra'), Describe.relock(b), end: change),
              opt(Symbols.emergency_rounded, tr('Emergency unlocks', 'Acil kilit açma hakları'), Describe.emergency(b, now), end: change),
            ],
          ])),
      sect(tr('Matches', 'Eşleşmeler'),
          low: true,
          child: Column(children: [
            opt(first: true, null, b.matchMode == MatchMode.blur
                    ? (onMobile ? tr('Cover, tap Show to see it', 'Ört, görmek için Göster\'e dokun') : tr('Blur, click to reveal', 'Bulanıklaştır, görmek için tıkla'))
                    : tr('Hide completely', 'Tamamen gizle'),
                b.matchMode == MatchMode.blur
                    ? tr('Or hide them completely', 'Ya da tamamen gizle')
                    : (onMobile ? tr('Or cover them, with a Show button', 'Ya da Göster düğmesiyle ört') : tr('Or blur them with click to reveal', 'Ya da bulanıklaştır, tıklayınca görünsün')),
                end: Seg<MatchMode>(
                  options: [(MatchMode.blur, onMobile ? tr('Cover', 'Örtme') : tr('Blur', 'Bulanık'), null), (MatchMode.hide, tr('Hide', 'Gizle'), null)],
                  value: b.matchMode,
                  onChanged: (v) => _change(context, b, (x) => x.matchMode = v),
                )),
          ])),
      sect(tr('Devices', 'Cihazlar'),
          low: true,
          child: opt(first: true, deviceIcon, app.state.deviceName,
              onMobile
                  ? tr('Runs on this phone', 'Bu telefonda çalışıyor')
                  : app.state.browsersSeen.isEmpty ? tr('Runs on this PC', 'Bu bilgisayarda çalışıyor') : tr('Runs on this PC and in ${browsers.where(app.state.browsersSeen.containsKey).join(', ')}', 'Bu bilgisayarda ve şuralarda çalışıyor: ${browsers.where(app.state.browsersSeen.containsKey).join(', ')}'))),
    ]);

    return NlPage(children: [
      PageBar(
        title: phone ? null : tr('Blocks', 'Engeller'),
        leading: IconBtn(Symbols.arrow_back_rounded, tooltip: tr('Back', 'Geri'), onPressed: () => Navigator.pop(context)),
        actions: [
          IconBtn(Symbols.ios_share_rounded, tooltip: tr('Share as file', 'Dosya olarak paylaş'), onPressed: () => exportBlocks(context, app, only: [b])),
          PopupMenuButton<String>(
            tooltip: tr('More', 'Diğer'),
            icon: Ms(Symbols.more_vert_rounded, color: c.onSurfaceVariant),
            color: c.surfaceMid,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (v) async {
              if (v == 'edit') go(context, EditBlockPage(app: app, editing: b));
              if (v == 'delete') {
                final ok = await showNlDialog<bool>(context, (ctx) => _ConfirmDelete(name: b.name));
                if (ok == true && context.mounted) {
                  app.deleteBlock(b.id);
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(tr('Edit block', 'Engeli düzenle'), style: body(15, color: c.onSurface))),
              PopupMenuItem(
                value: 'delete',
                enabled: !locked,
                child: Text(locked ? tr("Delete (not while it's locked)", 'Sil (kilitliyken olmaz)') : tr('Delete block', 'Engeli sil'), style: body(15, color: locked ? c.onSurfaceVariant : c.error)),
              ),
            ],
          ),
        ],
      ),
      hero,
      const SizedBox(height: 12),
      if (phone) ...[right, left] else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 7, child: left),
          const SizedBox(width: 12),
          Expanded(flex: 5, child: right),
        ]),
    ]);
  }
}

class _ConfirmDelete extends StatelessWidget {
  const _ConfirmDelete({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Delete $name?', '$name silinsin mi?'), style: body(24, weight: FontWeight.w500, color: c.onSurface)),
      const SizedBox(height: 12),
      Text(tr('Its keywords, sites and apps stop being blocked straight away.', 'Anahtar kelimeleri, siteleri ve uygulamaları hemen serbest kalır.'), style: body(15, color: c.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Btn(tr('Cancel', 'İptal'), kind: BtnKind.text, onPressed: () => Navigator.pop(context, false)),
        const SizedBox(width: 8),
        Btn(tr('Delete', 'Sil'), kind: BtnKind.danger, onPressed: () => Navigator.pop(context, true)),
      ]),
    ]);
  }
}
