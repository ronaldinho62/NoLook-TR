import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../controller.dart';
import '../screens/unlock.dart';
import '../theme.dart';
import 'common.dart';

/// card icon tile
class BlockIcon extends StatelessWidget {
  const BlockIcon(this.block, {super.key, this.size = 48, this.color});

  final Block block;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.nl.block(block.color).$2;
    final icon = blockIcons[block.iconName];
    final text = (block.iconText?.isNotEmpty ?? false)
        ? block.iconText!
        : (block.name.isEmpty ? '?' : block.name.characters.first.toUpperCase());
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: context.nl.wash, borderRadius: BorderRadius.circular(size / 3)),
      alignment: Alignment.center,
      child: icon != null
          ? Ms(icon, color: fg, size: size / 2)
          : Text(text, style: display(size * 15 / 48, weight: FontWeight.w800, color: fg)),
    );
  }
}

IconData lockIcon(Block b, DateTime now) {
  if (b.isPaused(now)) return Symbols.lock_open_rounded;
  if (!b.enabled) return Symbols.toggle_off_rounded;
  if (b.isLocked(now) && b.lock == LockKind.untilDate) return Symbols.lock_rounded;
  if (!b.schedule.always && !b.schedule.contains(now)) return Symbols.schedule_rounded;
  return switch (b.lock) {
    LockKind.none || LockKind.untilDate => Symbols.lock_open_rounded,
    LockKind.wait => Symbols.hourglass_top_rounded,
    LockKind.type => Symbols.keyboard_rounded,
  };
}

/// lock line, date in bold
Widget lockText(Block b, DateTime now, Color color, {double size = 14}) {
  final (before, bold, after) = Describe.lockLineParts(b, now);
  final style = body(size, color: color);
  return Text.rich(TextSpan(style: style, children: [
    TextSpan(text: before),
    if (bold.isNotEmpty) TextSpan(text: bold, style: body(size, weight: FontWeight.w600, color: color)),
    TextSpan(text: after),
  ]));
}

/// toggle, opens unlock if locked
void tapSwitch(BuildContext context, NoLook app, Block b) {
  if (!app.toggle(b)) showUnlock(context, app, b);
}

enum BlockCardStyle { home, list }

class BlockCard extends StatelessWidget {
  const BlockCard({super.key, required this.app, required this.block, required this.style, this.onOpen, this.preview = false});

  final NoLook app;
  final Block block;
  final BlockCardStyle style;
  final VoidCallback? onOpen;

  /// preview, switch disabled
  final bool preview;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final now = app.now;
    final b = block;
    final (bg, fg) = c.block(b.color);
    final locked = b.isLocked(now);
    final hidden = app.stats.hiddenTodayFor(b.id);
    final off = !b.isOn(now);

    final sub = switch (style) {
      BlockCardStyle.home => b.thingCount <= 2 && b.wordCount == 0
          ? [...b.sites, ...b.apps.map((a) => a.name)].join(', ')
          : Describe.contents(b),
      BlockCardStyle.list => off
          ? (b.isPaused(now) ? tr('Unlocked early', 'Erken açıldı') : tr('Off', 'Kapalı'))
          : !b.schedule.contains(now)
              ? tr('Turns on at ${Describe.time(b.schedule.nextStart(now) ?? now)}', 'Saat ${Describe.at(b.schedule.nextStart(now) ?? now)} açılır')
              : !b.schedule.always
                  ? tr('Running now', 'Şu an çalışıyor')
                  : tr('$hidden hidden today', 'Bugün $hidden gizlendi'),
    };

    return Opacity(
      opacity: style == BlockCardStyle.list && off ? .85 : 1,
      child: NlCard(
        color: bg,
        onTap: onOpen,
        child: DefaultTextStyle(
          style: body(14, color: fg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              BlockIcon(b, color: fg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.name, style: body(19, weight: FontWeight.w600, color: fg), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(sub, style: body(14, color: fg.withValues(alpha: .75)), overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 8),
              NlSwitch(
                value: b.isOn(now),
                locked: locked,
                tooltip: locked ? tr('Locked, click to unlock early', 'Kilitli, erken açmak için tıkla') : null,
                onTap: preview ? null : () => tapSwitch(context, app, b),
              ),
            ]),
            const SizedBox(height: 16),
            if (style == BlockCardStyle.home) ...[
              _words(context, fg),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('$hidden', style: display(30, color: fg)),
                const SizedBox(width: 6),
                Text(tr('hidden today', 'bugün gizlendi'), style: body(14, color: fg)),
              ]),
            ] else
              _meta(context, fg),
            const Spacer(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: fg.withValues(alpha: .1)))),
              child: Row(children: [
                Ms(lockIcon(b, now), size: 20, color: fg, fill: lockIcon(b, now) == Symbols.lock_rounded),
                const SizedBox(width: 10),
                Expanded(child: lockText(b, now, fg)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _words(BuildContext context, Color fg) {
    final b = block;
    final items = <String>[
      if (b.keywords.isNotEmpty)
        ...b.keywords
      else ...[
        ...b.sites,
        for (final a in b.apps) a.name,
      ],
    ];
    if (!b.schedule.always && b.keywords.isEmpty) {
      items
        ..clear()
        ..add(Schedule.describeDays(b.schedule.days))
        ..add('${Schedule.clock(b.schedule.start)} - ${Schedule.clock(b.schedule.end)}');
    }
    const shown = 4;
    Widget word(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: context.nl.wash, borderRadius: BorderRadius.circular(8)),
          child: Text(t, style: body(14, color: fg)),
        );

    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final t in items.take(shown)) word(t),
      if (items.length > shown)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(tr('+${items.length - shown} more', '+${items.length - shown} tane daha'), style: body(14, color: fg.withValues(alpha: .7))),
        ),
      if (items.isEmpty) Text(tr('Nothing in it yet', 'Henüz içinde bir şey yok'), style: body(14, color: fg.withValues(alpha: .7))),
    ]);
  }

  Widget _meta(BuildContext context, Color fg) {
    final b = block;
    final pills = <(IconData, String)>[
      if (b.wordCount > 0) (Symbols.text_fields_rounded, tr('${b.wordCount} keyword${b.wordCount == 1 ? '' : 's'}', '${b.wordCount} anahtar kelime')),
      if (b.sites.length == 1) (Symbols.language_rounded, b.sites.single),
      if (b.sites.length > 1) (Symbols.language_rounded, tr('${b.sites.length} sites', '${b.sites.length} site')),
      if (b.apps.length == 1) (Symbols.apps_rounded, b.apps.single.name),
      if (b.apps.length > 1) (Symbols.apps_rounded, tr('${b.apps.length} apps', '${b.apps.length} uygulama')),
      if (!b.schedule.always) (Symbols.schedule_rounded, b.schedule.describe()),
    ];
    final pillBg = b.color == BlockColor.grey ? context.nl.surfaceHigh : context.nl.wash;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final (icon, t) in pills)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: pillBg, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Ms(icon, size: 16, color: fg),
            const SizedBox(width: 4),
            Text(t, style: body(13, color: fg)),
          ]),
        ),
      if (pills.isEmpty) Text(tr('Nothing in it yet', 'Henüz içinde bir şey yok'), style: body(13, color: fg.withValues(alpha: .7))),
    ]);
  }
}
