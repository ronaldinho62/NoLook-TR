import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../platform/android_link.dart';
import '../platform/os.dart';
import '../controller.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/block_card.dart';
import '../widgets/common.dart';
import '../widgets/events.dart';
import '../widgets/blocker_banner.dart';
import '../widgets/update_banner.dart';
import 'block.dart';
import 'devices.dart';
import 'edit_block.dart';
import 'history.dart';
import 'pair.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.app});

  final NoLook app;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final blocks = app.state.blocks;
    return NlPage(children: [
      PageBar(logo: true, actions: [
        IconBtn(Symbols.qr_code_2_rounded, tooltip: tr('Pair a device', 'Cihaz eşleştir'), onPressed: () => go(context, PairPage(app: app))),
        IconBtn(Symbols.history_rounded, tooltip: tr('History', 'Geçmiş'), onPressed: () => go(context, HistoryPage(app: app))),
      ]),
      const UpdateBanner(),
      const BlockerBanner(),
      // android: service off means nothing runs
      ValueListenableBuilder<bool?>(valueListenable: AndroidLink.blocker, builder: (context, _, _) => _Status(app: app)),
      const SizedBox(height: 12),
      SectionHead(tr('Your blocks', 'Engellerin'),
          action: blocks.isEmpty ? null : Btn(tr('See all', 'Tümünü gör'), kind: BtnKind.outlined, onPressed: () => shellOf(context).select(NavTab.blocks))),
      const SizedBox(height: 12),
      if (blocks.isEmpty) _FirstBlock(app: app),
      Builder(builder: (context) {
        final fit = 12 ~/ cardSpan(context);
        final shown = blocks.take(fit == 1 ? 3 : fit).toList();
        return Grid12(items: [
          for (final b in shown)
            (cardSpan(context, count: shown.length), BlockCard(app: app, block: b, style: BlockCardStyle.home, onOpen: () => go(context, BlockPage(app: app, id: b.id)))),
        ]);
      }),
      const SizedBox(height: 12),
      Grid12(items: [(7, _JustNow(app: app)), (5, DevicesCard(app: app))]),
    ]);
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.app});

  final NoLook app;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final now = app.now;
    final phone = context.isPhone;
    final blocks = app.state.blocks;
    final running = blocks.where((b) => b.isActive(now)).toList();
    final on = blocks.where((b) => b.isOn(now)).toList();
    final hidden = app.stats.hiddenToday;

    final dated = blocks.where((b) => b.isLocked(now) && b.lock == LockKind.untilDate).toList()
      ..sort((a, b) => a.lockedUntil!.compareTo(b.lockedUntil!));
    final next = dated.isEmpty ? null : tr('Next unlock: ${dated.first.name} on ${Describe.day(dated.first.lockedUntil!, now)}', 'Sonraki kilit açılışı: ${dated.first.name}, ${Describe.day(dated.first.lockedUntil!, now)}');

    final blockerOff = onAndroid && AndroidLink.blocker.value == false;
    final title = blockerOff
        ? tr('Blocking is off', 'Engelleme kapalı')
        : running.isNotEmpty ? tr('Blocking is on', 'Engelleme açık') : (on.isNotEmpty ? tr('Waiting to start', 'Başlamayı bekliyor') : tr('Blocking is off', 'Engelleme kapalı'));
    final line = blockerOff && blocks.isNotEmpty
        ? tr('Turn on the blocker to start your blocks', 'Engellerini başlatmak için engelleyiciyi aç')
        : running.isNotEmpty
        ? tr('${running.length} block${running.length == 1 ? '' : 's'} running, $hidden thing${hidden == 1 ? '' : 's'} hidden today',
            '${running.length} engel çalışıyor, bugün $hidden şey gizlendi')
        : blocks.isEmpty
            ? tr('Make a block to start', 'Başlamak için bir engel oluştur')
            : on.isNotEmpty
                ? tr('Your blocks are on a schedule', 'Engellerin zamanlamaya göre çalışıyor')
                : tr('All your blocks are off', 'Tüm engellerin kapalı');

    int count(Iterable<int> n) => n.fold(0, (a, b) => a + b);
    final totals = [
      (Symbols.language_rounded, count(on.map((b) => b.sites.length)), tr('Sites', 'Site')),
      if (closesApps) (Symbols.apps_rounded, count(on.map((b) => b.apps.length)), tr('Apps', 'Uygulama')),
      (Symbols.text_fields_rounded, count(on.map((b) => b.wordCount)), tr('Keywords', 'Anahtar kelime')),
    ];

    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (next != null)
        Row(children: [
          Ms(Symbols.event_rounded, size: 20, color: c.onPrimaryContainer),
          const SizedBox(width: 8),
          Flexible(child: Text(next, style: body(15, weight: FontWeight.w500, color: c.onPrimaryContainer))),
        ]),
      SizedBox(height: next == null ? 0 : 14),
      Text(title, style: display(phone ? 40 : 64, color: c.onPrimaryContainer)),
      const SizedBox(height: 10),
      Text(line, style: body(18, color: c.onPrimaryContainer.withValues(alpha: .8))),
    ]);

    Widget tile((IconData, int, String) t) => Material(
          color: c.wash.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .12 : .55),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => shellOf(context).select(NavTab.blocks),
            child: Container(
              constraints: BoxConstraints(minWidth: phone ? 0 : 104),
              padding: EdgeInsets.symmetric(horizontal: phone ? 14 : 18, vertical: phone ? 12 : 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Ms(t.$1, size: 20, color: c.onPrimaryContainer.withValues(alpha: .8)),
                const SizedBox(height: 10),
                Text('${t.$2}', style: display(phone ? 24 : 28, color: c.onPrimaryContainer)),
                const SizedBox(height: 3),
                Text(t.$3, style: body(13, color: c.onPrimaryContainer.withValues(alpha: .75))),
              ]),
            ),
          ),
        );

    return ClipRRect(
        borderRadius: BorderRadius.circular(phone ? 24 : 28),
        child: Container(
          color: c.primaryContainer,
          child: Stack(children: [
            // blob behind the counts
            Positioned(right: phone ? -90 : 140, top: phone ? null : -110, bottom: phone ? -150 : null, child: Blob(size: 300, color: c.primary.withValues(alpha: .10))),
            Padding(
              padding: EdgeInsets.all(phone ? 24 : 32),
              child: phone
                  ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      text,
                      const SizedBox(height: 20),
                      Row(children: [
                        for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: tile(totals[i]))],
                      ]),
                    ])
                  : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: text),
                      const SizedBox(width: 24),
                      for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(width: 8), tile(totals[i])],
                    ]),
            ),
          ]),
        ),
      );
  }
}

class _FirstBlock extends StatelessWidget {
  const _FirstBlock({required this.app});

  final NoLook app;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return NlCard(
      color: c.surfaceLow,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('No blocks yet', 'Henüz engel yok'), style: body(19, weight: FontWeight.w600, color: c.onSurface)),
        const SizedBox(height: 4),
        Text(tr('A block is a list of keywords, sites and apps you want gone, with its own lock.', 'Engel; görmek istemediğin anahtar kelimeler, siteler ve uygulamalardan oluşan, kendi kilidi olan bir listedir.'),
            style: body(15, color: c.onSurfaceVariant)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Btn(tr('Start from a preset', 'Hazır listeyle başla'), icon: Symbols.auto_awesome_motion_rounded,
              onPressed: () => go(context, EditBlockPage(app: app, startWithPreset: true))),
          Btn(tr('Empty block', 'Boş engel'), kind: BtnKind.outlined, onPressed: () => go(context, EditBlockPage(app: app))),
        ]),
      ]),
    );
  }
}

class _JustNow extends StatelessWidget {
  const _JustNow({required this.app});

  final NoLook app;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final events = app.state.events.reversed.take(4).toList();
    return NlCard(
      color: c.surfaceLow,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardLabel(tr('Just now', 'Az önce')),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(onMobile ? tr('Nothing hidden yet, things NoLook covers or blocks show up here.', 'Henüz gizlenen bir şey yok, NoLook\'un örttüğü veya engellediği şeyler burada görünür.') : tr('Nothing hidden yet, things NoLook blurs or blocks show up here.', 'Henüz gizlenen bir şey yok, NoLook\'un bulanıklaştırdığı veya engellediği şeyler burada görünür.'),
                style: body(15, color: c.onSurfaceVariant)),
          ),
        for (final e in events) EventRow(e, end: ago(e.time, app.now), sayKeyword: app.state.settings.sayKeyword),
        const SizedBox(height: 4),
        Btn(tr('See all', 'Tümünü gör'), kind: BtnKind.text, onPressed: () => go(context, HistoryPage(app: app))),
      ]),
    );
  }
}
