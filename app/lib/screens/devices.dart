import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../controller.dart';
import '../platform/android_link.dart';
import '../platform/os.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'extension_setup.dart';
import 'pair.dart';

IconData get deviceIcon => onMobile ? Symbols.smartphone_rounded : Symbols.desktop_windows_rounded;

String get osName => switch (os) { Os.windows => 'Windows', Os.android => 'Android', Os.macos => 'macOS', Os.linux => 'Linux' };

const browsers = ['Chrome', 'Edge', 'Firefox', 'Brave', 'Opera', 'Vivaldi'];

/// setup order. opera gx reports as opera
const setupBrowsers = ['Chrome', 'Edge', 'Firefox', 'Brave', 'Opera', 'Opera GX', 'Vivaldi', 'Other'];

/// extension status from last contact
(String, bool) browserStatus(NoLook app, String browser) {
  final seen = app.state.browsersSeen[browser == 'Opera GX' ? 'Opera' : browser];
  if (seen == null) return (tr('Not set up', 'Kurulmadı'), false);
  final ago = app.now.difference(seen);
  if (ago.inMinutes < 3) return (tr('Connected', 'Bağlı'), true);
  final days = isTr
      ? const ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar']
      : const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final since = ago.inDays < 1 && seen.day == app.now.day
      ? Describe.time(seen)
      : ago.inDays < 7
          ? days[seen.weekday - 1]
          : Describe.day(seen, app.now);
  return (tr('Not open since $since', 'Son açılış: $since'), false);
}

class DevicesCard extends StatelessWidget {
  const DevicesCard({super.key, required this.app});

  final NoLook app;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final seen = browsers.where((b) => app.state.browsersSeen.containsKey(b)).toList();
    return NlCard(
      color: c.surfaceLow,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardLabel(tr('Your devices', 'Cihazların')),
        NlRow(
          icon: deviceIcon,
          title: app.state.deviceName,
          subtitle: osName,
          end: RowEnd(tr('This device', 'Bu cihaz'), icon: Symbols.check_circle_rounded, ok: true),
        ),
        for (final p in app.state.paired)
          NlRow(
            icon: p.os == 'Android' ? Symbols.smartphone_rounded : Symbols.desktop_windows_rounded,
            title: p.name,
            subtitle: syncLine(p, app.link, app.now),
            end: RowEnd(tr('Paired', 'Eşleşti'), icon: Symbols.sync_rounded, ok: true),
          ),
        if (!onMobile)
        for (final b in seen)
          NlRow(
            icon: Symbols.extension_rounded,
            title: b,
            subtitle: tr('Extension on this PC', 'Bu bilgisayardaki eklenti'),
            end: RowEnd(browserStatus(app, b).$1,
                icon: browserStatus(app, b).$2 ? Symbols.check_circle_rounded : Symbols.error_rounded, ok: browserStatus(app, b).$2),
          ),
        if (seen.isEmpty && !onMobile)
          NlRow(
            icon: Symbols.extension_rounded,
            title: tr('Browser extension', 'Tarayıcı eklentisi'),
            subtitle: tr('Needed to blur keywords and block sites', 'Anahtar kelimeleri bulanıklaştırmak ve siteleri engellemek için gerekli'),
            end: Btn(tr('Set up', 'Kur'), kind: BtnKind.text, onPressed: () => go(context, ExtensionSetupPage(app: app))),
          ),
        const SizedBox(height: 8),
        Btn(tr('Pair a device', 'Cihaz eşleştir'), icon: Symbols.qr_code_2_rounded, kind: BtnKind.outlined, onPressed: () => go(context, PairPage(app: app))),
      ]),
    );
  }
}

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key, required this.app});

  final NoLook app;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final c = context.nl;
    final phone = context.isPhone;
    final n = app.state.blocks.length;
    final blocksLine = tr('$n block${n == 1 ? '' : 's'}', '$n engel');

    Widget device(IconData icon, String name, String sub, List<(IconData, String, bool)> lines, {Widget? action}) => NlCard(
          color: c.surfaceLow,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(16)),
                child: Ms(icon, color: c.onSecondaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: body(18, weight: FontWeight.w600, color: c.onSurface)),
                  Text(sub, style: body(14, color: c.onSurfaceVariant)),
                ]),
              ),
              ?action,
            ]),
            const SizedBox(height: 16),
            for (final (i, t, bad) in lines)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Ms(i, size: 18, color: bad ? c.error : c.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t, style: body(14, color: bad ? c.error : c.onSurfaceVariant))),
                ]),
              ),
          ]),
        );

    final cards = <Widget>[
      device(deviceIcon, app.state.deviceName, tr('This device, $osName', 'Bu cihaz, $osName'), [
        (Symbols.block_rounded, blocksLine, false),
        // pc only, no way to do this on android yet
        if (app.state.settings.guard && !onMobile) (Symbols.shield_rounded, tr("Can't be closed while a block is locked", 'Kilitli bir engel varken kapatılamaz'), false),
      ]),
      for (final p in app.state.paired)
        device(p.os == 'Android' ? Symbols.smartphone_rounded : Symbols.desktop_windows_rounded, p.name, tr('Paired, ${p.os}', 'Eşleşti, ${p.os}'), [
          (Symbols.sync_rounded, syncLine(p, app.link, app.now), false),
        ], action: Btn(tr('Unpair', 'Eşleşmeyi kaldır'), kind: BtnKind.text, onPressed: () => app.link?.unpair(p.id))),
      for (final b in browsers)
        if (!onMobile && app.state.browsersSeen.containsKey(b))
          device(Symbols.extension_rounded, b, tr('Extension on this PC', 'Bu bilgisayardaki eklenti'), [
            browserStatus(app, b).$2
                ? (Symbols.sync_rounded, tr('Synced through this PC', 'Bu bilgisayar üzerinden eşitleniyor'), false)
                : (Symbols.error_rounded, browserStatus(app, b).$1, true),
            (Symbols.visibility_off_rounded, tr('Blurs keywords and blocks sites', 'Anahtar kelimeleri bulanıklaştırır, siteleri engeller'), false),
          ]),
      if (!onMobile && !browsers.any(app.state.browsersSeen.containsKey))
        device(Symbols.extension_rounded, tr('Browser extension', 'Tarayıcı eklentisi'), tr('Not set up yet', 'Henüz kurulmadı'), [
          (Symbols.visibility_off_rounded, tr('Needed to blur keywords and block sites', 'Anahtar kelimeleri bulanıklaştırmak ve siteleri engellemek için gerekli'), false),
        ], action: Btn(tr('Set up', 'Kur'), kind: BtnKind.tonal, onPressed: () => go(context, ExtensionSetupPage(app: app)))),
    ];

    return NlPage(children: [
      PageBar(title: tr('Devices', 'Cihazlar')),
      ClipRRect(
        borderRadius: BorderRadius.circular(phone ? 24 : 28),
        child: Container(
          color: c.primaryContainer,
          padding: EdgeInsets.all(phone ? 20 : 28),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(right: -80, bottom: -140, child: Blob(size: 260, color: c.primary.withValues(alpha: .08))),
            Flex(
              direction: phone ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: phone ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Ms(Symbols.qr_code_2_rounded, size: 40, color: c.onPrimaryContainer),
                SizedBox(width: phone ? 0 : 20, height: phone ? 12 : 0),
                () {
                  final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Pair a device', 'Cihaz eşleştir'), style: body(22, weight: FontWeight.w600, color: c.onPrimaryContainer)),
                    const SizedBox(height: 4),
                    Text(tr('Scan a QR code to keep your blocks the same on both, no account needed.', 'Bir QR kodu okut, engellerin iki cihazda da aynı olsun, hesap gerekmez.'),
                        style: body(15, color: c.onPrimaryContainer.withValues(alpha: .8))),
                  ]);
                  return phone ? text : Expanded(child: text);
                }(),
                SizedBox(width: phone ? 0 : 20, height: phone ? 16 : 0),
                Btn(tr('Pair a device', 'Cihaz eşleştir'), icon: Symbols.qr_code_scanner_rounded, onPressed: () => go(context, PairPage(app: app))),
              ],
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Grid12(items: [for (final card in cards) (cardSpan(context, count: cards.length) <= 3 ? 4 : cardSpan(context, count: cards.length), card)]),
      const SizedBox(height: 12),
      SectionHead(tr('Move your blocks by file', 'Engellerini dosyayla taşı')),
      const SizedBox(height: 12),
      NlCard(
        color: c.surfaceLow,
        child: Column(children: [
          NlRow(
            icon: Symbols.upload_rounded,
            title: tr('Export blocks', 'Engelleri dışa aktar'),
            subtitle: tr('Saves all your blocks to one .nolook file', 'Tüm engellerini tek bir .nolook dosyasına kaydeder'),
            square: true,
            end: Btn(tr('Export', 'Dışa aktar'), kind: BtnKind.outlined, onPressed: app.state.blocks.isEmpty ? null : () => exportBlocks(context, app)),
          ),
          Divider(color: c.outlineVariant.withValues(alpha: .6), height: 16),
          NlRow(
            icon: Symbols.download_rounded,
            title: tr('Import blocks', 'Engelleri içe aktar'),
            subtitle: tr('Adds the blocks from a .nolook file, without removing any of yours', 'Bir .nolook dosyasındaki engelleri ekler, seninkilerin hiçbirini silmez'),
            square: true,
            end: Btn(tr('Import', 'İçe aktar'), kind: BtnKind.outlined, onPressed: () => importBlocks(context, app)),
          ),
        ]),
      ),
    ]);
  }
}

const _nolookType = XTypeGroup(label: 'NoLook blocks', extensions: ['nolook']);

Future<void> exportBlocks(BuildContext context, NoLook app, {List<Block>? only}) async {
  final name = only?.length == 1 ? '${only!.single.name}.nolook' : 'NoLook blocks.nolook';
  final text = only == null ? app.exportBlocks() : NoLookFile.export(only, now: app.now);
  final count = only?.length ?? app.state.blocks.length;
  if (Platform.isAndroid) {
    // no save dialog on android, use Downloads
    final where = await AndroidLink.saveToDownloads(name, text);
    if (context.mounted) {
      toast(context, where == null ? tr("Couldn't save the file", 'Dosya kaydedilemedi') : tr('Saved $count block${count == 1 ? '' : 's'} to $where', '$count engel şuraya kaydedildi: $where'));
    }
    return;
  }
  final loc = await getSaveLocation(suggestedName: name, acceptedTypeGroups: const [_nolookType]);
  if (loc == null) return;
  var path = loc.path;
  if (!path.toLowerCase().endsWith('.nolook')) path = '$path.nolook';
  await File(path).writeAsString(text);
  if (context.mounted) toast(context, tr('Saved ${only?.length ?? app.state.blocks.length} block${(only?.length ?? app.state.blocks.length) == 1 ? '' : 's'}', '${only?.length ?? app.state.blocks.length} engel kaydedildi'));
}

Future<void> importBlocks(BuildContext context, NoLook app) async {
  final file = await openFile(acceptedTypeGroups: const [_nolookType]);
  if (file == null) return;
  try {
    final added = app.importBlocks(await file.readAsString());
    if (context.mounted) {
      toast(context, added == 0 ? tr('You already have all the blocks in that file', 'O dosyadaki tüm engeller zaten sende var') : tr('Added $added block${added == 1 ? '' : 's'}', '$added engel eklendi'));
    }
  } on FormatException catch (e) {
    if (context.mounted) toast(context, e.message);
  }
}
