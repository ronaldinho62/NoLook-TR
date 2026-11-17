import 'dart:io';

import '../platform/os.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../controller.dart';
import '../platform/android_link.dart';
import '../platform/startup.dart';
import '../platform/updates.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'devices.dart';
import 'extension_setup.dart';
import 'unlock.dart' show showNlDialog;

const appVersion = '0.1.1';
const repoUrl = 'https://github.com/ronaldinho62/NoLook-TR';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.app});

  final NoLook app;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final s = app.state.settings;
    void set(void Function() change) {
      change();
      app.save();
    }

    final connected = browsers.where((b) => browserStatus(app, b).$2).toList();
    final seenNotConnected = browsers.where((b) => app.state.browsersSeen.containsKey(b) && !browserStatus(app, b).$2);
    final extLine = [
      if (connected.isNotEmpty) tr('${connected.join(' and ')} connected', '${connected.join(' ve ')} bağlı'),
      for (final b in seenNotConnected) '$b: ${browserStatus(app, b).$1}',
    ].join(', ');

    final groups = <Widget>[
      _Group(tr('Looks', 'Görünüm'), [
        _Opt(Symbols.translate_rounded, tr('Language', 'Dil'),
            control: Seg<LangChoice>(
              options: [
                (LangChoice.system, tr('System', 'Sistem'), null),
                (LangChoice.en, 'English', null),
                (LangChoice.tr, 'Türkçe', null),
              ],
              value: s.language,
              onChanged: (v) => set(() => s.language = v),
            )),
        _Opt(Symbols.contrast_rounded, tr('Theme', 'Tema'),
            control: Seg<ThemeChoice>(
              options: [
                (ThemeChoice.system, tr('System', 'Sistem'), null),
                (ThemeChoice.light, tr('Light', 'Açık'), null),
                (ThemeChoice.dark, tr('Dark', 'Koyu'), null),
              ],
              value: s.theme,
              onChanged: (v) => set(() => s.theme = v),
            )),
      ]),
      _Group(onMobile ? tr('Covering', 'Örtme') : tr('Blur', 'Bulanıklık'), [
        // blur strength is pc only, android covers
        if (!onMobile)
          _Opt(Symbols.blur_on_rounded, tr('How strong', 'Ne kadar güçlü'),
            sub: tr('For posts and videos that match a keyword', 'Bir anahtar kelimeyle eşleşen gönderi ve videolar için'),
            control: Seg<BlurStrength>(
              options: [(BlurStrength.light, tr('Light', 'Hafif'), null), (BlurStrength.strong, tr('Strong', 'Güçlü'), null)],
              value: s.blurStrength,
              onChanged: (v) => set(() => s.blurStrength = v),
            )),
        _Opt(Symbols.ads_click_rounded, onMobile ? tr('Show with', 'Gösterme yolu') : tr('Reveal with', 'Gösterme yolu'),
            control: Seg<bool>(
              options: onMobile
                  ? [(false, tr('One tap', 'Tek dokunuş'), null), (true, tr('Two taps', 'İki dokunuş'), null)]
                  : [(false, tr('One click', 'Tek tık'), null), (true, tr('Two clicks', 'İki tık'), null)],
              value: s.twoClickReveal,
              onChanged: (v) => set(() => s.twoClickReveal = v),
            )),
        _Opt(Symbols.label_rounded, tr('Say which keyword matched', 'Hangi anahtar kelimenin eşleştiğini söyle'),
            sub: tr('Turn off if even the keyword is a spoiler', 'Anahtar kelimenin kendisi bile spoiler ise kapat'),
            control: NlSwitch(value: s.sayKeyword, onTap: () => set(() => s.sayKeyword = !s.sayKeyword))),
      ]),
      _Group(tr('Notifications', 'Bildirimler'), [
        _Opt(Symbols.notifications_rounded, tr('When a block unlocks', 'Bir engelin kilidi açılınca'),
            control: NlSwitch(value: s.notifyUnlock, onTap: () {
              set(() => s.notifyUnlock = !s.notifyUnlock);
              if (onAndroid && s.notifyUnlock) AndroidLink.askNotifications(force: true);
            })),
        _Opt(Symbols.hourglass_top_rounded, tr('When an unlock wait is over', 'Kilit açma beklemesi bitince'),
            control: NlSwitch(value: s.notifyWaitOver, onTap: () {
              set(() => s.notifyWaitOver = !s.notifyWaitOver);
              if (onAndroid && s.notifyWaitOver) AndroidLink.askNotifications(force: true);
            })),
      ]),
      if (onWindows)
        _Group(tr('On this PC', 'Bu bilgisayarda'), [
          _Opt(Symbols.power_settings_new_rounded, tr('Start with Windows', 'Windows ile başlat'),
              sub: tr('So blocking is on from the moment you sign in', 'Böylece engelleme oturum açtığın andan itibaren çalışır'),
              control: NlSwitch(
                value: s.startWithSystem,
                onTap: () {
                  set(() => s.startWithSystem = !s.startWithSystem);
                  setStartWithWindows(s.startWithSystem);
                },
              )),
          _Opt(Symbols.shield_rounded, tr('Stop NoLook being closed', 'NoLook\'un kapatılmasını engelle'),
              sub: tr('While any block is locked', 'Herhangi bir engel kilitliyken'),
              control: NlSwitch(
                value: s.guard,
                locked: s.guard && app.anyLocked,
                onTap: () {
                  if (s.guard && app.anyLocked) {
                    toast(context, tr("This can't be turned off while a block is locked.", 'Kilitli bir engel varken bu kapatılamaz.'));
                    return;
                  }
                  set(() => s.guard = !s.guard);
                },
              )),
          _Opt(Symbols.extension_rounded, tr('Browser extensions', 'Tarayıcı eklentileri'),
              sub: extLine.isEmpty ? tr('Not set up yet', 'Henüz kurulmadı') : extLine,
              control: Btn(extLine.isEmpty ? tr('Set up', 'Kur') : tr('Check', 'Kontrol et'),
                  kind: BtnKind.text, onPressed: () => go(context, ExtensionSetupPage(app: app)))),
        ]),
      if (onAndroid)
        _Group(tr('On this phone', 'Bu telefonda'), [
          ValueListenableBuilder<bool?>(
            valueListenable: AndroidLink.blocker,
            builder: (context, value, _) {
              final on = value ?? false;
              return _Opt(Symbols.shield_rounded, tr('Blocker', 'Engelleyici'),
                  sub: on
                      ? tr('On, closing apps, blocking sites and covering posts', 'Açık; uygulamaları kapatıyor, siteleri engelliyor ve gönderileri örtüyor')
                      : tr('Off, nothing gets blocked on this phone', 'Kapalı, bu telefonda hiçbir şey engellenmiyor'),
                  control: Btn(on ? tr('Settings', 'Ayarlar') : tr('Turn on', 'Aç'),
                      kind: on ? BtnKind.text : BtnKind.filled, onPressed: AndroidLink.openBlockerSettings));
            },
          ),
        ]),
      _Group(tr('About', 'Hakkında'), [
        _Opt(Symbols.code_rounded, tr('Open source on GitHub', 'GitHub\'da açık kaynak'), sub: tr('Version $appVersion', 'Sürüm $appVersion'),
            control: Btn(tr('Open', 'Aç'), kind: BtnKind.text, onPressed: () => openUrl(repoUrl))),
        _Opt(Symbols.bug_report_rounded, tr('Report a problem', 'Sorun bildir'),
            control: Btn(tr('Open', 'Aç'), kind: BtnKind.text, onPressed: () => openUrl('$repoUrl/issues'))),
        _Opt(Symbols.replay_rounded, tr('Run the setup again', 'Kurulumu yeniden çalıştır'), sub: tr("Your blocks stay as they are", 'Engellerin olduğu gibi kalır'),
            control: Btn(tr('Start', 'Başlat'), kind: BtnKind.text, onPressed: () => set(() => s.setupDone = false))),
        _Opt(Symbols.restart_alt_rounded, tr('Factory reset', 'Fabrika ayarlarına dön'),
            sub: app.anyLocked
                ? tr('Not while a block is locked', 'Kilitli bir engel varken olmaz')
                : tr('Start over with no blocks, history or settings', 'Engeller, geçmiş ve ayarlar olmadan baştan başla'),
            // disabled while locked
            control: Btn(tr('Reset', 'Sıfırla'), kind: BtnKind.text, onPressed: app.anyLocked ? null : () async {
              final ok = await showNlDialog<bool>(context, (ctx) => const _ConfirmReset());
              if (ok == true && !app.factoryReset() && context.mounted) {
                toast(context, tr("NoLook can't be reset while a block is locked.", 'Kilitli bir engel varken NoLook sıfırlanamaz.'));
              }
            })),
      ]),
      _UpdateRow(),
    ];

    return NlPage(children: [
      PageBar(title: tr('Settings', 'Ayarlar')),
      LayoutBuilder(builder: (context, box) {
        // 2 cols on wide windows
        if (box.maxWidth < 1100) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: groups);
        final left = <Widget>[], right = <Widget>[];
        for (var i = 0; i < groups.length; i++) {
          (i.isEven ? left : right).add(groups[i]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: left)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
        ]);
      }),
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text('NoLook © ${DateTime.now().year} ItsZedK', textAlign: TextAlign.center, style: body(13, color: context.nl.onSurfaceVariant)),
      ),
    ]);
  }
}

void openUrl(String url) {
  if (Platform.isAndroid) {
    AndroidLink.openUrl(url);
  } else if (Platform.isWindows) {
    Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
  } else if (Platform.isMacOS) {
    Process.run('open', [url]);
  } else {
    Process.run('xdg-open', [url]);
  }
}

class _ConfirmReset extends StatelessWidget {
  const _ConfirmReset();

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Reset NoLook?', 'NoLook sıfırlansın mı?'), style: body(24, weight: FontWeight.w500, color: c.onSurface)),
      const SizedBox(height: 12),
      Text(
          tr("Your blocks, history and settings on this device get deleted and it gets unpaired from your other devices, then the setup starts again. This can't be undone.",
              'Bu cihazdaki engellerin, geçmişin ve ayarların silinir, diğer cihazlarınla eşleşmesi kaldırılır ve kurulum yeniden başlar. Bu geri alınamaz.'),
          style: body(15, color: c.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Btn(tr('Cancel', 'İptal'), kind: BtnKind.text, onPressed: () => Navigator.pop(context, false)),
        const SizedBox(width: 8),
        Btn(tr('Reset', 'Sıfırla'), kind: BtnKind.danger, onPressed: () => Navigator.pop(context, true)),
      ]),
    ]);
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NlCard(
        color: c.surfaceLow,
        padding: EdgeInsets.fromLTRB(context.isPhone ? 20 : 24, 20, context.isPhone ? 20 : 24, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardLabel(title),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.outlineVariant.withValues(alpha: .5)),
            children[i],
          ],
        ]),
      ),
    );
  }
}

class _Opt extends StatelessWidget {
  const _Opt(this.icon, this.title, {this.sub, required this.control});

  final IconData icon;
  final String title;
  final String? sub;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final text = Row(children: [
      Ms(icon, color: c.onSurfaceVariant),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: body(16, color: c.onSurface)),
          if (sub != null) Text(sub!, style: body(14, color: c.onSurfaceVariant)),
        ]),
      ),
    ]);
    final wide = control is Seg;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(builder: (context, box) {
        // buttons wrap below when narrow
        if (wide && box.maxWidth < 560) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            text,
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.only(left: 40), child: control),
          ]);
        }
        return Row(children: [Expanded(child: text), const SizedBox(width: 12), control]);
      }),
    );
  }
}

class _UpdateRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => FutureBuilder<Update?>(
        future: checkForUpdate(current: appVersion, repo: repoUrl),
        builder: (context, snap) {
          final u = snap.data;
          if (u == null) return const SizedBox.shrink();
          return _Group(tr('Update', 'Güncelle'), [
            _Opt(Symbols.download_rounded, tr('NoLook ${u.version} is out', 'NoLook ${u.version} çıktı'),
                sub: tr("You have $appVersion, your blocks stay as they are", 'Şu an $appVersion sürümü var, engellerin olduğu gibi kalır'),
                control: Btn(tr('Download', 'İndir'), kind: BtnKind.text, onPressed: () => openUrl(u.url))),
          ]);
        },
      );
}
