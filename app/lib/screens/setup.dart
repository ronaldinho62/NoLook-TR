import 'dart:async';
import '../platform/os.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../controller.dart';
import '../platform/android_link.dart';
import '../platform/startup.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/drop_in_logo.dart';
import '../widgets/tour_art.dart';
import 'devices.dart';
import 'extension_setup.dart';

enum SetupStep { welcome, tour, block, browser, settings, done }

const _emph = Cubic(.2, 0, 0, 1);

/// first run setup: welcome, tour, first block, extension, settings
class SetupFlow extends StatefulWidget {
  const SetupFlow({super.key, required this.app});

  final NoLook app;

  @override
  State<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends State<SetupFlow> {
  SetupStep _step = SetupStep.welcome;
  int _feature = 0;
  var _forward = true;

  // nothing saved until the end, except language/theme
  var _usePreset = true;

  var _skipBlock = false;
  var _lock = false;
  late DateTime _until = _defaultUntil();
  var _imported = false;
  late bool _startWithSystem = true;
  late bool _guard = app.state.settings.guard;
  late bool _notify = app.state.settings.notifyUnlock;

  NoLook get app => widget.app;
  Preset get _preset => presets.first;

  // android: poll the a11y service state
  var _blockerOn = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _poll = Timer.periodic(const Duration(seconds: 1), (_) async {
        final on = await AndroidLink.blockerOn();
        if (mounted && on != _blockerOn) setState(() => _blockerOn = on);
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  DateTime _defaultUntil() {
    final now = app.now;
    final dec = DateTime(now.year, 12, 19);
    return dec.isAfter(now.add(const Duration(days: 2))) ? dec : DateTime(now.year, now.month, now.day).add(const Duration(days: 30));
  }

  void _go(SetupStep step, {int? feature, bool? forward}) => setState(() {
        _forward = forward ?? step.index >= _step.index;
        _step = step;
        if (feature != null) _feature = feature;
      });

  void _next() {
    switch (_step) {
      case SetupStep.welcome:
        _go(SetupStep.tour, feature: 0);
      case SetupStep.tour:
        _feature < 3 ? _go(SetupStep.tour, feature: _feature + 1, forward: true) : _go(SetupStep.block);
      case SetupStep.block:
        _skipBlock = false;
        _go(SetupStep.browser);
      case SetupStep.browser:
        _go(SetupStep.settings);
      case SetupStep.settings:
        _go(SetupStep.done);
      case SetupStep.done:
        _finish();
    }
  }

  void _back() {
    switch (_step) {
      case SetupStep.welcome:
        break;
      case SetupStep.tour:
        _feature > 0 ? _go(SetupStep.tour, feature: _feature - 1, forward: false) : _go(SetupStep.welcome);
      case SetupStep.block:
        _go(SetupStep.tour, feature: 3);
      case SetupStep.browser:
        _go(_imported ? SetupStep.welcome : SetupStep.block);
      case SetupStep.settings:
        _go(SetupStep.browser);
      case SetupStep.done:
        _go(SetupStep.settings);
    }
  }

  Future<void> _import() async {
    final before = app.state.blocks.length;
    await importBlocks(context, app);
    if (!mounted || app.state.blocks.length == before) return;
    _imported = true;
    _go(SetupStep.browser);
  }

  /// don't add the preset twice on a rerun
  bool get _hasPreset => app.state.blocks.any((b) => b.presetId == _preset.id);

  bool get _makesPreset => !_imported && !_skipBlock && _usePreset;
  bool get _makesOwn => !_imported && !_skipBlock && !_usePreset;

  void _finish() {
    final s = app.state.settings;
    if (_makesPreset && !_hasPreset) app.addBlock(_preset.toBlock(lockedUntil: _lock ? _until : null));
    s
      ..startWithSystem = _startWithSystem
      ..guard = _guard
      ..notifyUnlock = _notify
      ..setupDone = true;
    if (Platform.isWindows) setStartWithWindows(_startWithSystem, hidden: s.startHidden);
    // open the editor once the shell is up
    if (_makesOwn) app.newBlockRequest.value = '';
    app.save();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final c = context.nl;
    final key = ValueKey(_step == SetupStep.tour ? 'tour$_feature' : _step.name);
    final dir = _forward ? 1.0 : -1.0;
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: _emph,
      switchOutCurve: const Cubic(.3, 0, 1, 1),
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
      transitionBuilder: (child, a) {
        final incoming = child.key == key;
        final slide = Tween(begin: Offset((incoming ? .04 : -.04) * dir, 0), end: Offset.zero).animate(a);
        return FadeTransition(opacity: a, child: SlideTransition(position: slide, child: child));
      },
      child: KeyedSubtree(key: key, child: _page(context)),
    );

    return Material(
      color: c.surface,
      child: _step == SetupStep.welcome
          ? content
          : SafeArea(
              child: Column(children: [
                _TopBar(step: _step, onSkip: _step == SetupStep.tour ? () => _go(SetupStep.block) : null),
                Expanded(child: content),
                _BottomBar(
                  onBack: _back,
                  onNext: _next,
                  onSkip: _step == SetupStep.block
                      ? () {
                          _skipBlock = true;
                          _go(SetupStep.browser);
                        }
                      : null,
                  nextLabel: switch (_step) {
                    SetupStep.browser => (onMobile ? _blockerOn : browsers.any((b) => browserStatus(app, b).$2)) ? tr('Next', 'İleri') : tr('Skip for now', 'Şimdilik atla'),
                    SetupStep.done => _makesOwn ? tr('Make my block', 'Engelimi oluştur') : tr('Open NoLook', 'NoLook\'u aç'),
                    _ => tr('Next', 'İleri'),
                  },
                ),
              ]),
            ),
    );
  }

  Widget _page(BuildContext context) => switch (_step) {
        SetupStep.welcome => _Welcome(app: app, onStart: _next, onImport: _import),
        SetupStep.tour => _Tour(feature: _feature, onDot: (i) => _go(SetupStep.tour, feature: i, forward: i > _feature)),
        SetupStep.block => _scroll(context, 780, _blockStep(context)),
        SetupStep.browser => _scroll(context, 980, onMobile ? _blockerStep(context) : _browserStep(context)),
        SetupStep.settings => _scroll(context, 780, _settingsStep(context)),
        SetupStep.done => _scroll(context, 640, _doneStep(context)),
      };

  Widget _scroll(BuildContext context, double width, List<Widget> children) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(context.isPhone ? 20 : 40, context.isPhone ? 8 : 24, context.isPhone ? 20 : 40, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      );

  List<Widget> _heading(BuildContext context, String title, String text) {
    final c = context.nl;
    return [
      Text(title, style: display(context.isPhone ? 32 : 44, color: c.onSurface, height: 1.08)),
      const SizedBox(height: 12),
      Text(text, style: body(context.isPhone ? 16 : 18, color: c.onSurfaceVariant, height: 1.5)),
      SizedBox(height: context.isPhone ? 20 : 28),
    ];
  }

  List<Widget> _blockStep(BuildContext context) {
    final c = context.nl;
    final p = _preset;
    final shown = p.keywords.take(context.isPhone ? 6 : 10).toList();
    Widget chip(String text, {bool more = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: more ? Colors.transparent : c.wash, borderRadius: BorderRadius.circular(10)),
          child: Text(text, style: body(14, color: c.onTertiaryContainer.withValues(alpha: more ? .8 : 1))),
        );

    final presetCard = Column(key: const ValueKey('preset'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      NlCard(
        color: c.tertiaryContainer,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: c.wash, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: Text(p.iconText, style: display(16, weight: FontWeight.w800, color: c.onTertiaryContainer)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: body(18, weight: FontWeight.w600, color: c.onTertiaryContainer)),
                Text(tr('${p.wordCount} keywords and ${p.sites.length} sites', '${p.wordCount} anahtar kelime ve ${p.sites.length} site'),
                    style: body(14, color: c.onTertiaryContainer.withValues(alpha: .8))),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in shown) chip(k),
            chip(tr('+${p.wordCount - shown.length} more', '+${p.wordCount - shown.length} tane daha'), more: true),
          ]),
          const SizedBox(height: 14),
          Text(tr('Words like "ending" or "leak" only count next to GTA 6, and you can change everything later.',
                  '"final" veya "sızıntı" gibi kelimeler yalnızca GTA 6 ile birlikte geçince sayılır, her şeyi daha sonra değiştirebilirsin.'),
              style: body(14, color: c.onTertiaryContainer.withValues(alpha: .85), height: 1.45)),
        ]),
      ),
      // lock only applies to new blocks
      if (!_hasPreset) ...[
        const SizedBox(height: 12),
        NlCard(
        color: c.surfaceLow,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Lock it', 'Kilitle'), style: body(18, weight: FontWeight.w600, color: c.onSurface)),
          const SizedBox(height: 4),
          Text(tr("So you can't just switch it off when you get curious.", 'Merak edince hemen kapatamayasın diye.'),
              style: body(15, color: c.onSurfaceVariant)),
          const SizedBox(height: 16),
          Seg<bool>(
            options: [
              (false, tr('No lock', 'Kilit yok'), Symbols.lock_open_rounded),
              (true, tr('Until a date', 'Bir tarihe kadar'), Symbols.lock_rounded),
            ],
            value: _lock,
            onChanged: (v) => setState(() => _lock = v),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: _emph,
            alignment: Alignment.topCenter,
            child: !_lock
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Ms(Symbols.event_rounded, color: c.primary),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: tr('Locked until ', 'Kilitli: '), style: body(16, color: c.onSurface)),
                            TextSpan(text: Describe.until(_until, app.now), style: body(16, weight: FontWeight.w700, color: c.onSurface)),
                          ])),
                        ),
                        const SizedBox(width: 8),
                        Btn(tr('Change', 'Değiştir'), kind: BtnKind.text, onPressed: () async {
                          final now = app.now;
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _until,
                            firstDate: now.add(const Duration(days: 1)),
                            lastDate: now.add(const Duration(days: 365 * 3)),
                          );
                          if (picked != null) setState(() => _until = picked);
                        }),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                          tr('Turning it off before then takes a 30 min wait and typing a sentence, and you get 3 emergency unlocks a month.',
                              'O tarihten önce kapatmak 30 dakika beklemeyi ve bir cümle yazmayı gerektirir, ayrıca ayda 3 acil kilit açma hakkın olur.'),
                          style: body(14, color: c.onSurfaceVariant, height: 1.45)),
                    ]),
                  ),
          ),
        ]),
        ),
      ],
    ]);

    final ownCard = NlCard(
      key: const ValueKey('own'),
      color: c.surfaceLow,
      child: Row(children: [
        Ms(Symbols.edit_note_rounded, color: c.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Text(tr("You'll make it right after setup, with your own keywords, sites and apps.", 'Kurulumdan hemen sonra kendi anahtar kelimelerin, sitelerin ve uygulamalarınla oluşturacaksın.'),
              style: body(15, color: c.onSurface, height: 1.45)),
        ),
      ]),
    );

    return [
      ..._heading(context, tr('Your first block', 'İlk engelin'),
          tr('A block is a list of keywords, sites and apps to keep away, with its own lock.', 'Engel; uzak durmak istediğin anahtar kelimeler, siteler ve uygulamalardan oluşan, kendi kilidi olan bir listedir.')),
      ChoiceGrid(children: [
        ChoiceTile(
          icon: Symbols.sports_esports_rounded,
          title: tr('Start from GTA 6 spoilers', 'GTA 6 spoilerleriyle başla'),
          text: _hasPreset
              ? tr('Already one of your blocks', 'Zaten engellerinden biri')
              : tr('Ready-made, with the game, its people and places', 'Hazır liste: oyun, karakterleri ve mekânları'),
          selected: _usePreset,
          onTap: () => setState(() => _usePreset = true),
        ),
        ChoiceTile(
          icon: Symbols.add_rounded,
          title: tr('Make my own', 'Kendim oluşturayım'),
          text: tr('Start empty and add what you want', 'Boş başla, istediğini ekle'),
          selected: !_usePreset,
          onTap: () => setState(() => _usePreset = false),
        ),
      ]),
      const SizedBox(height: 16),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: _emph,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SizeTransition(sizeFactor: a, alignment: Alignment.topCenter, child: child),
        ),
        child: _usePreset ? presetCard : ownCard,
      ),
    ];
  }

  List<Widget> _browserStep(BuildContext context) => [
        ..._heading(context, tr('Add the browser extension', 'Tarayıcı eklentisini ekle'),
            tr("It blurs keywords and blocks sites in your browser, you can also set it up later in Settings.",
                'Tarayıcında anahtar kelimeleri bulanıklaştırır ve siteleri engeller, bunu daha sonra Ayarlar\'dan da kurabilirsin.')),
        ExtensionSetupPage(app: app, embedded: true),
      ];

  List<Widget> _blockerStep(BuildContext context) {
    final c = context.nl;
    Widget step(int n, String title, String? sub, Widget? action) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: _blockerOn ? c.primary : c.secondaryContainer, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: _blockerOn
                  ? Ms(Symbols.check_rounded, size: 18, color: c.onPrimary)
                  : Text('$n', style: body(14, weight: FontWeight.w600, color: c.onSecondaryContainer)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: body(16, weight: FontWeight.w500, color: c.onSurface)),
                  if (sub != null) ...[const SizedBox(height: 2), Text(sub, style: body(14, color: c.onSurfaceVariant, height: 1.4))],
                  if (action != null) ...[const SizedBox(height: 12), action],
                ]),
              ),
            ),
          ]),
        );
    return [
      ..._heading(context, tr('Turn on the blocker', 'Engelleyiciyi aç'),
          tr("Android needs your OK for NoLook to close apps, block sites and cover posts. It reads what's on screen for that, and nothing leaves your phone.",
              'NoLook\'un uygulamaları kapatması, siteleri engellemesi ve gönderileri örtmesi için Android\'in onayı gerekiyor. Bunun için ekrandakileri okur ve hiçbir şey telefonundan dışarı çıkmaz.')),
      NlCard(
        color: c.surfaceLow,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          step(1, tr("Open NoLook's Accessibility settings", 'NoLook\'un Erişilebilirlik ayarlarını aç'), null,
              Btn(tr('Open settings', 'Ayarları aç'), icon: Symbols.open_in_new_rounded, kind: BtnKind.tonal, onPressed: AndroidLink.openBlockerSettings)),
          step(2, tr('Turn on "NoLook blocker", then tap Allow', '"NoLook engelleyici" seçeneğini aç, sonra İzin ver\'e dokun'),
              tr('Then come back here, this page updates by itself.', 'Sonra buraya dön, bu sayfa kendiliğinden güncellenir.'), null),
        ]),
      ),
      const SizedBox(height: 12),
      NlCard(
        color: c.surfaceMid,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Switch greyed out?', 'Anahtar gri mi?'), style: body(16, weight: FontWeight.w600, color: c.onSurface)),
          const SizedBox(height: 4),
          Text(
              tr('Android does that for apps from outside the Play Store. Open App info, tap the three dots at the top right, choose "Allow restricted settings", then try again.',
                  'Android bunu Play Store dışından yüklenen uygulamalara yapar. Uygulama bilgisi sayfasını aç, sağ üstteki üç noktaya dokun, "Kısıtlanmış ayarlara izin ver" seçeneğini seç ve tekrar dene.'),
              style: body(14, color: c.onSurfaceVariant, height: 1.45)),
          const SizedBox(height: 12),
          Btn(tr('Open App info', 'Uygulama bilgisini aç'), kind: BtnKind.outlined, onPressed: AndroidLink.openAppInfo),
        ]),
      ),
      const SizedBox(height: 12),
      AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: _emph,
        decoration: BoxDecoration(color: _blockerOn ? c.tertiaryContainer : c.surfaceMid, borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          Ms(_blockerOn ? Symbols.check_circle_rounded : Symbols.shield_rounded, color: _blockerOn ? c.onTertiaryContainer : c.onSurfaceVariant, fill: _blockerOn),
          const SizedBox(width: 14),
          Expanded(
            child: Text(_blockerOn ? tr("The blocker is on, you're protected.", 'Engelleyici açık, korunuyorsun.') : tr('The blocker is off.', 'Engelleyici kapalı.'),
                style: body(15, color: _blockerOn ? c.onTertiaryContainer : c.onSurface)),
          ),
        ]),
      ),
    ];
  }

  List<Widget> _settingsStep(BuildContext context) {
    final c = context.nl;
    final s = app.state.settings;
    Widget row(IconData icon, String title, String? sub, Widget control) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            Ms(icon, color: c.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: body(16, color: c.onSurface)),
                if (sub != null) Text(sub, style: body(14, color: c.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(width: 12),
            control,
          ]),
        );
    final divider = Divider(height: 1, color: c.outlineVariant.withValues(alpha: .5));
    return [
      ..._heading(context, tr('A few more things', 'Birkaç şey daha'), tr('All of these can be changed later in Settings.', 'Bunların hepsi daha sonra Ayarlar\'dan değiştirilebilir.')),
      NlCard(
        color: c.surfaceLow,
        padding: EdgeInsets.fromLTRB(context.isPhone ? 20 : 24, 6, context.isPhone ? 20 : 24, 6),
        child: Column(children: [
          if (onWindows) ...[
            row(Symbols.power_settings_new_rounded, tr('Start with Windows', 'Windows ile başlat'),
                tr('So blocking is on from the moment you sign in', 'Böylece engelleme oturum açtığın andan itibaren çalışır'),
                NlSwitch(value: _startWithSystem, onTap: () => setState(() => _startWithSystem = !_startWithSystem))),
            divider,
          ],
          if (!onMobile) ...[
            row(Symbols.shield_rounded, tr('Stop NoLook being closed', 'NoLook\'un kapatılmasını engelle'), tr('While any block is locked', 'Herhangi bir engel kilitliyken'),
                NlSwitch(value: _guard, onTap: () => setState(() => _guard = !_guard))),
            divider,
          ],
          row(Symbols.notifications_rounded, tr('Tell me when a block unlocks', 'Bir engelin kilidi açılınca bana haber ver'), null,
              NlSwitch(value: _notify, onTap: () => setState(() => _notify = !_notify))),
          divider,
          LayoutBuilder(builder: (context, box) {
            final seg = Seg<ThemeChoice>(
              options: [
                (ThemeChoice.system, tr('System', 'Sistem'), null),
                (ThemeChoice.light, tr('Light', 'Açık'), null),
                (ThemeChoice.dark, tr('Dark', 'Koyu'), null),
              ],
              value: s.theme,
              onChanged: (v) {
                s.theme = v;
                app.save();
              },
            );
            if (box.maxWidth >= 520) return row(Symbols.contrast_rounded, tr('Theme', 'Tema'), null, seg);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Ms(Symbols.contrast_rounded, color: c.onSurfaceVariant), const SizedBox(width: 16), Text(tr('Theme', 'Tema'), style: body(16, color: c.onSurface))]),
                const SizedBox(height: 10),
                Padding(padding: const EdgeInsets.only(left: 40), child: seg),
              ]),
            );
          }),
        ]),
      ),
    ];
  }

  List<Widget> _doneStep(BuildContext context) {
    final c = context.nl;
    final connected = browsers.where((b) => browserStatus(app, b).$2).toList();
    final lines = <(IconData, String)>[
      if (_imported)
        (Symbols.download_rounded, tr('Your blocks from the file are on', 'Dosyadaki engellerin açık'))
      else if (_skipBlock)
        (Symbols.block_rounded, tr('No block yet, use + to make one', 'Henüz engel yok, + ile bir tane oluştur'))
      else if (_usePreset && _hasPreset)
        (Symbols.block_rounded, tr('${_preset.name} is already one of your blocks', '${_preset.name} zaten engellerinden biri'))
      else if (_usePreset)
        (
          Symbols.block_rounded,
          _lock
              ? tr('${_preset.name} is on, locked until ${Describe.day(_until, app.now)}', '${_preset.name} açık, ${Describe.until(_until, app.now)} kilitli')
              : tr('${_preset.name} is on', '${_preset.name} açık'),
        )
      else
        (Symbols.edit_note_rounded, tr('Your first block is next', 'Sırada ilk engelin var')),
      if (onAndroid)
        _blockerOn
            ? (Symbols.shield_rounded, tr('The blocker is on', 'Engelleyici açık'))
            : (Symbols.shield_rounded, tr('The blocker is off, turn it on from Settings', 'Engelleyici kapalı, Ayarlar\'dan açabilirsin'))
      else if (connected.isEmpty)
        (Symbols.extension_rounded, tr('No browser yet, you can add one from Settings', 'Henüz tarayıcı yok, Ayarlar\'dan ekleyebilirsin'))
      else
        (Symbols.extension_rounded, tr('${connected.join(' and ')} connected', '${connected.join(' ve ')} bağlı')),
      if (onWindows && _startWithSystem) (Symbols.power_settings_new_rounded, tr('Starts with Windows', 'Windows ile başlar')),
    ];
    return [
      SizedBox(height: context.isPhone ? 12 : 32),
      Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: const SpringCurve(stiffness: 200, damping: 12, seconds: .9),
          builder: (context, k, child) => Transform.scale(scale: k, child: child),
          child: LogoIcon(size: context.isPhone ? 96 : 120),
        ),
      ),
      const SizedBox(height: 28),
      Text(tr("You're all set", 'Her şey hazır'), textAlign: TextAlign.center, style: display(context.isPhone ? 34 : 48, color: c.onSurface)),
      const SizedBox(height: 12),
      Text(
          onMobile
              ? tr('NoLook keeps running when you close it.', 'NoLook kapatsan da çalışmaya devam eder.')
              : tr('NoLook keeps running in the tray when you close the window.',
                  'Pencereyi kapatsan da NoLook sistem tepsisinde çalışmaya devam eder.'),
          textAlign: TextAlign.center,
          style: body(context.isPhone ? 16 : 18, color: c.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 28),
      NlCard(
        color: c.surfaceLow,
        child: Column(children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
                child: Ms(lines[i].$1, size: 20, color: c.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(lines[i].$2, style: body(16, color: c.onSurface))),
            ]),
          ],
        ]),
      ),
    ];
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.step, this.onSkip});

  final SetupStep step;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final phone = context.isPhone;
    final labels = [tr('Tour', 'Tanıtım'), tr('First block', 'İlk engel'), onMobile ? tr('Blocker', 'Engelleyici') : tr('Browser', 'Tarayıcı'), tr('Settings', 'Ayarlar')];
    final at = step.index - 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(phone ? 20 : 32, phone ? 14 : 22, phone ? 12 : 24, 8),
      child: Row(children: [
        if (!phone) ...[const Brandmark(), const SizedBox(width: 40)],
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Row(children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (!phone) ...[
                      Text(labels[i], style: body(13, weight: i == at ? FontWeight.w600 : FontWeight.w400, color: i <= at ? c.onSurface : c.onSurfaceVariant)),
                      const SizedBox(height: 6),
                    ],
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(children: [
                        Container(height: 6, color: c.surfaceHigh),
                        AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 450),
                          curve: _emph,
                          widthFactor: i < at || step == SetupStep.done ? 1 : (i == at ? .5 : 0),
                          child: Container(height: 6, color: c.primary),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(width: 16),
        // keep the width so the bar doesn't jump
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: phone ? 0 : 180),
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            child: onSkip == null ? const SizedBox(height: 40) : Btn(phone ? tr('Skip', 'Atla') : tr('Skip the tour', 'Tanıtımı atla'), kind: BtnKind.text, onPressed: onSkip),
          ),
        ),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onBack, required this.onNext, required this.nextLabel, this.onSkip});

  final VoidCallback onBack, onNext;
  final String nextLabel;

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final phone = context.isPhone;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outlineVariant.withValues(alpha: .4)))),
      padding: EdgeInsets.fromLTRB(phone ? 16 : 32, 14, phone ? 16 : 32, phone ? 16 : 18),
      child: Row(children: [
        phone ? IconBtn(Symbols.arrow_back_rounded, tooltip: tr('Back', 'Geri'), onPressed: onBack) : Btn(tr('Back', 'Geri'), icon: Symbols.arrow_back_rounded, kind: BtnKind.text, onPressed: onBack),
        const Spacer(),
        if (onSkip != null) ...[
          Btn(tr('Skip for now', 'Şimdilik atla'), kind: BtnKind.text, big: !phone, onPressed: onSkip),
          SizedBox(width: phone ? 4 : 8),
        ],
        Btn(nextLabel, trailing: Symbols.arrow_forward_rounded, big: !phone, onPressed: onNext),
      ]),
    );
  }
}

/// welcome screen
class _Welcome extends StatefulWidget {
  const _Welcome({required this.app, required this.onStart, required this.onImport});

  final NoLook app;
  final VoidCallback onStart, onImport;

  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: dropInMs + 900));

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final c = context.nl;
    final phone = context.isPhone;
    final ms = _c.value * (dropInMs + 900);
    // stagger the text after the logo
    double rise(int delay) => _emph.transform(((ms - dropInTextMs - delay) / 600).clamp(0, 1));
    Widget up(int delay, Widget child) {
      final k = rise(delay);
      return Opacity(opacity: k, child: Transform.translate(offset: Offset(0, 18 * (1 - k)), child: child));
    }

    final size = phone ? 290.0 : 360.0;
    final headSize = phone ? 38.0 : 56.0;
    final markH = headSize * .86;
    final heading = Text.rich(
      TextSpan(children: [
        TextSpan(text: '${tr('Welcome to', 'Hoş geldin:')} '),
        // wordmark on the baseline
        WidgetSpan(
          alignment: PlaceholderAlignment.aboveBaseline,
          baseline: TextBaseline.alphabetic,
          child: Transform.translate(offset: Offset(0, markH * 9 / 106), child: Wordmark(height: markH, color: c.onSurface)),
        ),
      ]),
      textAlign: TextAlign.center,
      style: display(headSize, color: c.onSurface, height: 1.15),
    );

    final lang = Seg<Lang>(
      options: const [(Lang.en, 'English', null), (Lang.tr, 'Türkçe', null)],
      value: currentLang,
      onChanged: (v) {
        widget.app.state.settings.language = v == Lang.tr ? LangChoice.tr : LangChoice.en;
        widget.app.save();
      },
    );

    final actions = Column(crossAxisAlignment: phone ? CrossAxisAlignment.stretch : CrossAxisAlignment.center, children: [
      Btn(tr('Get started', 'Başlayalım'), trailing: Symbols.arrow_forward_rounded, big: true, wide: phone, onPressed: widget.onStart),
      const SizedBox(height: 8),
      Center(child: Btn(tr('I have a .nolook file', 'Bir .nolook dosyam var'), kind: BtnKind.text, onPressed: widget.onImport)),
    ]);

    return SafeArea(
      child: Stack(children: [
        Positioned(top: phone ? 16 : 24, right: phone ? 16 : 28, child: up(450, lang)),
        Padding(
          padding: EdgeInsets.fromLTRB(24, phone ? 72 : 24, 24, phone ? 24 : 24),
          child: Column(mainAxisAlignment: phone ? MainAxisAlignment.start : MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: SizedBox(
                width: size,
                height: size * 300 / 360,
                child: OverflowBox(minHeight: size, maxHeight: size, child: DropInLogo(ms: ms, size: size)),
              ),
            ),
            SizedBox(height: phone ? 4 : 8),
            up(0, heading),
            const SizedBox(height: 12),
            up(130, Text(tr('Hide spoilers and block sites and apps on all your devices.', 'Tüm cihazlarında spoilerleri gizle, siteleri ve uygulamaları engelle.'),
                textAlign: TextAlign.center, style: body(phone ? 16 : 18, color: c.onSurfaceVariant, height: 1.5))),
            if (phone) const Spacer() else const SizedBox(height: 32),
            up(270, actions),
          ]),
        ),
      ]),
    );
  }
}

/// tour page
class _Tour extends StatelessWidget {
  const _Tour({required this.feature, required this.onDot});

  final int feature;
  final ValueChanged<int> onDot;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final phone = context.isPhone;
    final (title, text) = switch (feature) {
      0 when onMobile => (
          tr('Spoilers get covered', 'Spoilerler örtülür'),
          tr('Posts and videos that mention your keywords get covered on YouTube, X, Reddit, TikTok and in your browser, tap Show to see one anyway.',
              'Anahtar kelimelerinden bahseden gönderi ve videolar YouTube, X, Reddit, TikTok ve tarayıcında örtülür, yine de görmek istersen Göster\'e dokun.'),
        ),
      0 => (
          tr('Spoilers get covered', 'Spoilerler örtülür'),
          tr('Posts and videos that mention your keywords get blurred on X, YouTube, Reddit and other sites, click one to see it anyway.',
              'Anahtar kelimelerinden bahseden gönderi ve videolar X, YouTube, Reddit ve diğer sitelerde bulanıklaştırılır, yine de görmek istersen üzerine tıkla.'),
        ),
      1 => (
          tr('Sites and apps get blocked', 'Siteler ve uygulamalar engellenir'),
          tr("Spoiler subreddits and fan sites won't load, and apps you block close as soon as they open.",
              'Spoiler subreddit\'leri ve hayran siteleri yüklenmez, engellediğin uygulamalar da açılır açılmaz kapanır.'),
        ),
      2 => (
          tr('Locks keep you from caving', 'Kilitler pes etmeni önler'),
          tr('Lock a block until a date, turning it off early then takes a wait and typing a sentence, or one of your emergency unlocks.',
              'Bir engeli bir tarihe kadar kilitle; erken kapatmak için beklemen ve bir cümle yazman ya da acil kilit açma haklarından birini kullanman gerekir.'),
        ),
      _ when onMobile => (
          tr('Works in every app', 'Her uygulamada çalışır'),
          tr('NoLook reads the screen, so it works in any app and browser on this phone.', 'NoLook ekranı okur, bu yüzden bu telefondaki her uygulamada ve tarayıcıda çalışır.'),
        ),
      _ => (
          tr('Works in every browser', 'Her tarayıcıda çalışır'),
          tr('Chrome, Edge and Firefox get your blocks from this app.', 'Chrome, Edge ve Firefox engellerini bu uygulamadan alır.'),
        ),
    };
    final (bg, blob) = switch (feature) {
      0 => (c.tertiaryContainer, c.onTertiaryContainer),
      1 => (c.violetContainer, c.onVioletContainer),
      2 => (c.peachContainer, c.onPeachContainer),
      _ => (c.primaryContainer, c.onPrimaryContainer),
    };

    final dots = Row(children: [
      for (var i = 0; i < 4; i++)
        GestureDetector(
          onTap: () => onDot(i),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: _emph,
              margin: const EdgeInsets.only(right: 8),
              width: i == feature ? 28 : 10,
              height: 10,
              decoration: BoxDecoration(color: i == feature ? c.primary : c.outlineVariant, borderRadius: BorderRadius.circular(5)),
            ),
          ),
        ),
    ]);

    final words = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(tr('What NoLook does, ${feature + 1} of 4', 'NoLook ne yapar, ${feature + 1}/4'), style: body(14, weight: FontWeight.w600, color: c.primary)),
      SizedBox(height: phone ? 8 : 14),
      Text(title, style: display(phone ? 30 : 52, color: c.onSurface, height: 1.05)),
      SizedBox(height: phone ? 10 : 18),
      Text(text, style: body(phone ? 16 : 19, color: c.onSurfaceVariant, height: 1.5)),
      SizedBox(height: phone ? 16 : 32),
      dots,
    ]);

    final art = ClipRRect(
      borderRadius: BorderRadius.circular(phone ? 28 : 40),
      child: Container(
        color: bg,
        child: Stack(children: [
          Positioned(right: -120, top: -140, child: Blob(size: 380, color: blob.withValues(alpha: .05))),
          Positioned(left: -100, bottom: -160, child: Blob(size: 320, color: blob.withValues(alpha: .04), radii: const [.58, .42, .40, .60, .55, .45, .55, .45])),
          // fixed size, scaled to fit
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(phone ? 20 : 48),
              child: FittedBox(child: SizedBox(width: 440, child: TourArt(feature: feature))),
            ),
          ),
        ]),
      ),
    );

    if (phone) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 11, child: art),
          const SizedBox(height: 20),
          Expanded(flex: 9, child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 4), child: words)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Row(children: [
            Expanded(flex: 5, child: Padding(padding: const EdgeInsets.only(left: 24), child: words)),
            const SizedBox(width: 64),
            Expanded(flex: 6, child: art),
          ]),
        ),
      ),
    );
  }
}
