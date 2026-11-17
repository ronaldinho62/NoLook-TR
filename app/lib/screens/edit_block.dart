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
import 'block.dart';
import 'unlock.dart';

/// new/edit block
class EditBlockPage extends StatefulWidget {
  const EditBlockPage({super.key, required this.app, this.editing, this.startWithPreset = false, this.openAdvanced = false, this.sites = const []});

  final NoLook app;
  final Block? editing;
  final bool startWithPreset;
  final bool openAdvanced;

  /// prefilled sites
  final List<String> sites;

  @override
  State<EditBlockPage> createState() => _EditBlockPageState();
}

class _EditBlockPageState extends State<EditBlockPage> {
  late Block d;
  late final TextEditingController _name;
  late final TextEditingController _sentence;
  late bool _advanced = widget.openAdvanced;
  bool _fromPreset = false;
  Preset? _preset;

  bool get _isNew => widget.editing == null;
  NoLook get app => widget.app;

  @override
  void initState() {
    super.initState();
    d = widget.editing?.copy() ??
        Block(
          id: newId(),
          name: '',
          // no lock by default, "Until a date" defaults to +30 days
          lock: LockKind.none,
        );
    if (widget.editing == null && widget.sites.isNotEmpty) d.sites = [...widget.sites];
    _name = TextEditingController(text: d.name);
    _sentence = TextEditingController(text: d.sentence);
    if (_isNew && widget.startWithPreset) _usePreset(presets.first);
    WidgetsBinding.instance.addPostFrameCallback((_) => hideDock.value++);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) => hideDock.value--);
    _name.dispose();
    _sentence.dispose();
    super.dispose();
  }

  void _usePreset(Preset p) {
    final now = DateTime.now();
    setState(() {
      _fromPreset = true;
      _preset = p;
      d
        ..presetId = p.id
        ..name = p.name
        ..color = p.color
        ..iconText = p.iconText
        ..keywords = [...p.keywords]
        ..spoilerWords = [...p.spoilerWords]
        ..topicWords = [...p.topicWords]
        ..sites = [...p.sites]
        ..sentence = p.sentence;
      // gta 6 is out 19 nov 2026, default to a month after
      if (p.id == 'gta6-spoilers' && d.lock == LockKind.untilDate) {
        final date = DateTime(2026, 12, 19);
        d.lockedUntil = date.isAfter(now) ? date : DateTime(now.year, now.month, now.day + 30);
      }
      _name.text = p.name;
      _sentence.text = p.sentence;
    });
  }

  void _useEmpty() => setState(() {
        _fromPreset = false;
        _preset = null;
        d
          ..presetId = null
          ..iconText = null
          ..keywords = []
          ..spoilerWords = []
          ..topicWords = []
          ..sites = [];
        if (_name.text == presets.first.name) _name.clear();
        d.name = _name.text;
      });

  bool get _ready => _name.text.trim().isNotEmpty && d.thingCount > 0;

  Future<void> _save() async {
    d.name = _name.text.trim();
    d.sentence = _sentence.text.trim();
    if (d.iconText == null && d.iconName == null) {
      final words = d.name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      d.iconText = words.length > 1 ? (words[0][0] + words[1][0]).toUpperCase() : d.name.characters.first.toUpperCase();
    }
    if (_isNew) {
      app.addBlock(d);
      Navigator.pushReplacement(
          context, PageRouteBuilder(pageBuilder: (_, _, _) => BlockPage(app: app, id: d.id), transitionDuration: Duration.zero));
      return;
    }
    final problems = app.updateBlock(d);
    if (problems.isEmpty) {
      Navigator.pop(context);
      return;
    }
    await showNlDialog(context, (ctx) {
      final c = ctx.nl;
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text("It's locked", style: body(24, weight: FontWeight.w500, color: c.onSurface)),
        const SizedBox(height: 12),
        for (final p in problems) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(p, style: body(15, color: c.onSurfaceVariant))),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerRight, child: Btn('OK', onPressed: () => Navigator.pop(ctx))),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final c = context.nl;
    final phone = context.isPhone;
    final locked = widget.editing?.isLocked(app.now) ?? false;
    final title = _isNew ? tr('New block', 'Yeni engel') : tr('Edit block', 'Engeli düzenle');
    final saveLabel = _isNew ? tr('Create block', 'Engel oluştur') : tr('Save', 'Kaydet');
    var n = 0;

    final steps = <Widget>[
      if (_isNew)
        _Step(
          number: ++n,
          title: tr('Start from', 'Başlangıç'),
          text: tr('A preset comes with keywords and sites already in, you can still change everything.', 'Hazır listede anahtar kelimeler ve siteler zaten var, yine de her şeyi değiştirebilirsin.'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ChoiceGrid(children: [
              ChoiceTile(
                  icon: Symbols.add_box_rounded, title: tr('Empty block', 'Boş engel'), text: tr('Add everything yourself', 'Her şeyi kendin ekle'), selected: !_fromPreset, onTap: _useEmpty),
              ChoiceTile(
                  icon: Symbols.auto_awesome_motion_rounded,
                  title: tr('A preset', 'Hazır liste'),
                  text: tr('Pick a ready-made list', 'Hazır bir liste seç'),
                  selected: _fromPreset,
                  onTap: () => _usePreset(_preset ?? presets.first)),
            ]),
            if (_fromPreset)
              for (final p in presets)
                Padding(padding: const EdgeInsets.only(top: 12), child: _PresetTile(preset: p, selected: _preset == p, onTap: () => _usePreset(p))),
          ]),
        ),
      _Step(
        number: ++n,
        title: tr('Name it', 'Ad ver'),
        child: Flex(
          direction: phone ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: phone ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            if (phone)
              NlField(label: tr('Name', 'Ad'), controller: _name, onChanged: (v) => setState(() => d.name = v))
            else
              Expanded(child: NlField(label: tr('Name', 'Ad'), controller: _name, onChanged: (v) => setState(() => d.name = v))),
            SizedBox(width: 12, height: phone ? 12 : 0),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (final col in BlockColor.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: col.name[0].toUpperCase() + col.name.substring(1),
                    child: InkWell(
                      onTap: () => setState(() => d.color = col),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: col == BlockColor.grey ? c.surfaceHigh : c.block(col).$1,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: d.color == col ? c.primary : Colors.transparent, width: 2),
                        ),
                        child: d.color == col ? Ms(Symbols.check_rounded, size: 20, color: c.block(col).$2) : null,
                      ),
                    ),
                  ),
                ),
            ]),
          ],
        ),
      ),
      _Step(
        number: ++n,
        title: tr('What to block', 'Neler engellensin'),
        text: locked
            ? tr("It's locked, so you can add things but not remove them.", 'Kilitli, bu yüzden ekleme yapabilirsin ama kaldıramazsın.')
            : onMobile ? tr('Keywords get covered, sites and apps get blocked.', 'Anahtar kelimeler örtülür, siteler ve uygulamalar engellenir.')
            : !closesApps ? tr('Keywords get blurred and sites get blocked.', 'Anahtar kelimeler bulanıklaştırılır, siteler engellenir.') : tr('Keywords get blurred, sites and apps get blocked.', 'Anahtar kelimeler bulanıklaştırılır, siteler ve uygulamalar engellenir.'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          WordsEditor(
            block: d,
            canRemove: !locked,
            onChanged: (k, s, t) => setState(() => d
              ..keywords = k
              ..spoilerWords = s
              ..topicWords = t),
          ),
          SubHead(Symbols.language_rounded, tr('Sites', 'Siteler'), d.sites.length),
          SiteEditor(sites: d.sites, canRemove: !locked, onChanged: (s) => setState(() => d.sites = s)),
          if (closesApps) ...[
          SubHead(Symbols.apps_rounded, tr('Apps', 'Uygulamalar'), d.apps.length),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in d.apps) ItemChip(a.name, onRemove: locked ? null : () => setState(() => d.apps = [...d.apps]..remove(a))),
            NlChip(tr('Pick apps', 'Uygulama seç'), icon: Symbols.add_rounded, onTap: () async {
              final picked = await pickApps(context, already: d.apps);
              if (picked != null) setState(() => d.apps = [...d.apps, ...picked]);
            }),
          ]),
          ],
        ]),
      ),
      _Step(
        number: ++n,
        title: tr("When it's on", 'Ne zaman açık'),
        text: locked ? tr("The schedule can't change while it's locked.", 'Kilitliyken zamanlama değiştirilemez.') : null,
        child: _ScheduleEditor(
          schedule: d.schedule,
          enabled: !locked,
          onChanged: (s) => setState(() => d.schedule = s),
        ),
      ),
      _Step(
        number: ++n,
        title: tr('Lock', 'Kilit'),
        text: tr('How hard it is to turn off early.', 'Erken kapatmak ne kadar zor olsun.'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IgnorePointer(
            ignoring: locked,
            child: Opacity(
              opacity: locked ? .6 : 1,
              child: ChoiceGrid(children: [
                for (final (kind, icon, t, s) in [
                  (LockKind.none, Symbols.lock_open_rounded, tr('No lock', 'Kilit yok'), tr('Turn it off any time', 'İstediğin zaman kapatabilirsin')),
                  (LockKind.untilDate, Symbols.event_rounded, tr('Until a date', 'Bir tarihe kadar'), tr('Stays on until the date you pick', 'Seçtiğin tarihe kadar açık kalır')),
                  (LockKind.wait, Symbols.hourglass_top_rounded, tr('Wait to unlock', 'Beklemeyle açılır'), tr('Unlocking takes a short wait', 'Kilidi açmak için kısa bir süre beklemek gerekir')),
                  (LockKind.type, Symbols.keyboard_rounded, tr('Type to unlock', 'Yazarak açılır'), tr('Type out a sentence to unlock', 'Kilidi açmak için bir cümle yazmak gerekir')),
                ])
                  ChoiceTile(
                    icon: icon,
                    title: t,
                    text: s,
                    selected: d.lock == kind,
                    onTap: () => setState(() {
                      d.lock = kind;
                      if (kind == LockKind.untilDate && d.lockedUntil == null) {
                        final now = DateTime.now();
                        d.lockedUntil = DateTime(now.year, now.month, now.day + 30);
                      }
                    }),
                  ),
              ]),
            ),
          ),
          if (d.lock == LockKind.untilDate)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: 360,
                child: _PickerField(
                  label: tr('Locked until', 'Kilitli kalacağı tarih'),
                  icon: Symbols.event_rounded,
                  value: d.lockedUntil == null ? '' : Describe.day(d.lockedUntil!, DateTime(0)),
                  onTap: () async {
                    final now = DateTime.now();
                    final first = locked ? widget.editing!.lockedUntil! : DateTime(now.year, now.month, now.day + 1);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: d.lockedUntil != null && d.lockedUntil!.isAfter(first) ? d.lockedUntil! : first,
                      firstDate: first,
                      lastDate: DateTime(now.year + 5),
                    );
                    if (picked != null) setState(() => d.lockedUntil = picked);
                  },
                ),
              ),
            ),
        ]),
      ),
    ];

    final advanced = _Advanced(
      open: _advanced,
      onToggle: () => setState(() => _advanced = !_advanced),
      groups: [
        if (d.lock != LockKind.none)
          _AdvGroup(tr('Unlocking early', 'Erken açma'), [
            if (d.lock == LockKind.untilDate)
              _AdvOpt(tr('What it takes', 'Ne gerekiyor'),
                  control: Seg<EarlyUnlock>(
                    options: [(EarlyUnlock.wait, tr('Wait', 'Bekle'), null), (EarlyUnlock.type, tr('Type', 'Yaz'), null), (EarlyUnlock.both, tr('Both', 'İkisi de'), null)],
                    value: d.earlyUnlock,
                    onChanged: (v) => setState(() => d.earlyUnlock = v),
                  )),
            if (Unlocker.stepsFor(d).wait)
              _AdvOpt(tr('How long the wait is', 'Bekleme süresi'),
                  control: Seg<int>(
                    options: [for (final m in const [5, 15, 30, 60]) (m, Describe.minutes(m), null)],
                    value: d.waitMinutes,
                    onChanged: (v) => setState(() => d.waitMinutes = v),
                  )),
            if (Unlocker.stepsFor(d).type)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: NlField(
                  label: tr('Sentence to type', 'Yazılacak cümle'),
                  icon: Symbols.keyboard_rounded,
                  controller: _sentence,
                  fill: c.surfaceLow,
                  hint: Unlocker.sentenceFor(Block(id: '', name: _name.text.trim().isEmpty ? 'this block' : _name.text.trim())),
                  onChanged: (v) => d.sentence = v,
                ),
              ),
            _AdvOpt(tr('Turns back on after', 'Yeniden açılma süresi'),
                sub: tr("So it doesn't stay off by accident", 'Yanlışlıkla kapalı kalmasın diye'),
                control: Seg<int?>(
                  options: [(15, Describe.minutes(15), null), (60, Describe.minutes(60), null), (null, tr('When I turn it on', 'Ben açınca'), null)],
                  value: d.relockMinutes,
                  onChanged: (v) => setState(() => d.relockMinutes = v),
                )),
          ]),
        if (d.lock != LockKind.none)
          _AdvGroup(tr('Emergency unlocks', 'Acil kilit açma hakları'), [
            _AdvOpt(tr('How many a month', 'Ayda kaç tane'),
                sub: tr('Skips the wait and the typing when you really need it', 'Gerçekten gerektiğinde beklemeyi ve yazmayı atlar'),
                control: Seg<int?>(
                  options: [(0, tr('None', 'Yok'), null), (1, '1', null), (3, '3', null), (null, tr('No limit', 'Sınırsız'), null)],
                  value: d.emergencyPerMonth,
                  onChanged: (v) => setState(() => d.emergencyPerMonth = v),
                )),
          ]),
        _AdvGroup(tr('Matches', 'Eşleşmeler'), [
          _AdvOpt(tr('When a keyword matches', 'Bir anahtar kelime eşleşince'),
              control: Seg<MatchMode>(
                options: [(MatchMode.blur, tr('Blur', 'Bulanık'), null), (MatchMode.hide, tr('Hide', 'Gizle'), null)],
                value: d.matchMode,
                onChanged: (v) => setState(() => d.matchMode = v),
              )),
        ]),
      ],
    );

    final actions = Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        if (!_ready)
          Expanded(
            child: Text(_name.text.trim().isEmpty ? tr('Give it a name first.', 'Önce bir ad ver.') : tr('Add a keyword, site or app first.', 'Önce bir anahtar kelime, site veya uygulama ekle.'),
                style: body(14, color: c.onSurfaceVariant)),
          ),
        Btn(tr('Cancel', 'İptal'), kind: BtnKind.text, onPressed: () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(saveLabel, icon: Symbols.check_rounded, onPressed: _ready ? _save : null),
      ]),
    );

    final form = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < steps.length; i++) _StepFrame(first: i == 0, child: steps[i]),
      advanced,
      if (!phone) actions,
    ]);

    final preview = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(tr('Preview', 'Önizleme'), style: body(13, weight: FontWeight.w600, color: c.onSurfaceVariant)),
      ),
      IntrinsicHeight(child: BlockCard(app: app, block: d.copy()..name = _name.text.trim().isEmpty ? tr('New block', 'Yeni engel') : _name.text.trim(), style: BlockCardStyle.home, preview: true)),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
        child: Text(Describe.summary(d), style: body(13, color: c.onSurfaceVariant)),
      ),
    ]);

    return NlPage(
        header: phone
            ? Row(children: [
                IconBtn(Symbols.close_rounded, tooltip: tr('Close', 'Kapat'), onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: body(22, weight: FontWeight.w500, color: c.onSurface))),
                Btn(_isNew ? tr('Create', 'Oluştur') : tr('Save', 'Kaydet'), onPressed: _ready ? _save : null),
              ])
            : null,
        children: [
      if (!phone)
        PageBar(title: title, leading: IconBtn(Symbols.arrow_back_rounded, tooltip: tr('Back', 'Geri'), onPressed: () => Navigator.pop(context))),
      if (phone)
        form
      else
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: form),
          const SizedBox(width: 24),
          SizedBox(width: 340, child: preview),
        ]),
    ]);
  }
}

class _StepFrame extends StatelessWidget {
  const _StepFrame({required this.first, required this.child});

  final bool first;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.only(top: first ? 4 : 24, bottom: 24),
        decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: context.nl.outlineVariant))),
        child: child,
      );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, this.text, required this.child});

  final int number;
  final String title;
  final String? text;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final phone = context.isPhone;
    final num = Container(
      width: phone ? 30 : 36,
      height: phone ? 30 : 36,
      decoration: BoxDecoration(color: c.secondaryContainer, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text('$number', style: body(phone ? 14 : 16, weight: FontWeight.w600, color: c.onSecondaryContainer)),
    );
    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(title, style: body(18, weight: FontWeight.w600, color: c.onSurface)),
      ),
      if (text != null) Text(text!, style: body(14, color: c.onSurfaceVariant)),
      const SizedBox(height: 16),
      child,
    ]);
    if (phone) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [num, const SizedBox(height: 8), content]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [num, const SizedBox(width: 16), Expanded(child: content)]);
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, required this.selected, required this.onTap});

  final Preset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final fg = selected ? c.onTertiaryContainer : c.onSurface;
    return Material(
      color: selected ? c.tertiaryContainer : c.surfaceLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? c.primary : Colors.transparent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.wash, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: Text(preset.iconText, style: display(15, weight: FontWeight.w800, color: fg)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(preset.name, style: body(16, weight: FontWeight.w600, color: fg)),
                Text(tr('${preset.description}, ${preset.wordCount} keywords and ${preset.sites.length} sites', '${preset.description}, ${preset.wordCount} anahtar kelime ve ${preset.sites.length} site'),
                    style: body(13, color: fg.withValues(alpha: .75))),
              ]),
            ),
            if (selected) ...[const SizedBox(width: 8), Ms(Symbols.check_circle_rounded, color: c.primary, fill: true)],
          ]),
        ),
      ),
    );
  }
}

class _ScheduleEditor extends StatelessWidget {
  const _ScheduleEditor({required this.schedule, required this.onChanged, this.enabled = true});

  final Schedule schedule;
  final ValueChanged<Schedule> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final s = schedule;
    final days = s.always ? {1, 2, 3, 4, 5} : s.days;
    final start = s.always ? 9 * 60 : s.start;
    final end = s.always ? 17 * 60 : s.end;
    Schedule on({Set<int>? days2, int? start2, int? end2}) =>
        Schedule.on(days: days2 ?? days, start: start2 ?? start, end: end2 ?? end);

    Future<int?> pick(int minutes) async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
        builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
      );
      return t == null ? null : t.hour * 60 + t.minute;
    }

    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : .6,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Seg<bool>(
            options: [(true, tr('Always', 'Her zaman'), Symbols.all_inclusive_rounded), (false, tr('On a schedule', 'Zamanlamaya göre'), Symbols.schedule_rounded)],
            value: s.always,
            onChanged: (always) => onChanged(always ? const Schedule.always() : on()),
          ),
          if (!s.always) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (i, l) in [for (var k = 1; k <= 7; k++) (k, Schedule.dayLetters[k - 1])])
                Material(
                  color: days.contains(i) ? c.primary : Colors.transparent,
                  shape: CircleBorder(side: days.contains(i) ? BorderSide.none : BorderSide(color: c.outlineVariant)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onChanged(on(days2: days.contains(i) ? ({...days}..remove(i)) : {...days, i})),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Text(l, style: body(14, weight: FontWeight.w500, color: days.contains(i) ? c.onPrimary : c.onSurface)),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                width: 160,
                child: _PickerField(label: tr('From', 'Başlangıç'), icon: Symbols.schedule_rounded, value: Schedule.clock(start), onTap: () async {
                  final m = await pick(start);
                  if (m != null) onChanged(on(start2: m));
                }),
              ),
              SizedBox(
                width: 160,
                child: _PickerField(label: tr('To', 'Bitiş'), icon: Symbols.schedule_rounded, value: Schedule.clock(end), onTap: () async {
                  final m = await pick(end);
                  if (m != null) onChanged(on(end2: m));
                }),
              ),
            ]),
            if (end <= start)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(tr('Runs overnight, into the next morning.', 'Gece boyunca, ertesi sabaha kadar sürer.'), style: body(13, color: c.onSurfaceVariant)),
              ),
          ],
        ]),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.label, required this.icon, required this.value, required this.onTap});

  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: body(14, color: c.onSurfaceVariant),
          floatingLabelStyle: body(13, color: c.onSurfaceVariant),
          prefixIcon: Ms(icon, color: c.onSurfaceVariant),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.outline)),
        ),
        child: Text(value, style: body(16, color: c.onSurface)),
      ),
    );
  }
}

class _Advanced extends StatelessWidget {
  const _Advanced({required this.open, required this.onToggle, required this.groups});

  final bool open;
  final VoidCallback onToggle;
  final List<Widget> groups;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final phone = context.isPhone;
    return Padding(
      padding: EdgeInsets.only(left: phone ? 0 : 52, top: 8),
      child: Material(
        color: c.surfaceLow,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.all(phone ? 16 : 18).copyWith(left: phone ? 16 : 20, right: phone ? 16 : 20),
              child: Row(children: [
                Ms(Symbols.tune_rounded, color: c.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Advanced options', 'Gelişmiş seçenekler'), style: body(16, weight: FontWeight.w600, color: c.onSurface)),
                    Text(onMobile ? tr('Unlocking early, emergency unlocks and covering', 'Erken açma, acil kilit açma ve örtme') : tr('Unlocking early, emergency unlocks and blur', 'Erken açma, acil kilit açma ve bulanıklık'), style: body(13, color: c.onSurfaceVariant)),
                  ]),
                ),
                AnimatedRotation(
                  turns: open ? .5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Ms(Symbols.expand_more_rounded, color: c.onSurfaceVariant),
                ),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: EdgeInsets.fromLTRB(phone ? 16 : 20, 0, phone ? 16 : 20, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: groups),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }
}

class _AdvGroup extends StatelessWidget {
  const _AdvGroup(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outlineVariant))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(title, style: body(14, weight: FontWeight.w600, color: c.primary)),
        ),
        ...children,
      ]),
    );
  }
}

class _AdvOpt extends StatelessWidget {
  const _AdvOpt(this.title, {this.sub, required this.control});

  final String title;
  final String? sub;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: body(15, color: c.onSurface)),
              if (sub != null) Text(sub!, style: body(13, color: c.onSurfaceVariant)),
            ]),
          ),
          control,
        ],
      ),
    );
  }
}
