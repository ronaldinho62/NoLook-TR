import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// dialog on desktop, sheet on phones
Future<T?> showNlDialog<T>(BuildContext context, WidgetBuilder builder, {double width = 480}) {
  final c = context.nl;
  if (context.isPhone) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: c.surface,
      barrierColor: Colors.black.withValues(alpha: .32),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        // nav bar + keyboard insets
        padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + MediaQuery.viewPaddingOf(ctx).bottom + MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(child: builder(ctx)),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: .32),
    builder: (ctx) => Dialog(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: builder(ctx)),
      ),
    ),
  );
}

Future<void> showUnlock(BuildContext context, NoLook app, Block block) {
  final steps = Unlocker.stepsFor(block);
  if (steps.wait) app.startWait(block);
  return showNlDialog(context, (ctx) => _UnlockDialog(app: app, block: block), width: 520);
}

class _UnlockDialog extends StatefulWidget {
  const _UnlockDialog({required this.app, required this.block});

  final NoLook app;
  final Block block;

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  final _typed = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final c = context.nl;
    final app = widget.app;
    final b = widget.block;
    final now = app.now;
    final steps = Unlocker.stepsFor(b);
    final waitLeft = Unlocker.waitLeft(b, now);
    final waitDone = !steps.wait || waitLeft == Duration.zero;
    final typedOk = !steps.type || Unlocker.sentenceMatches(_typed.text, steps.sentence);
    final left = Unlocker.emergencyLeft(b, now);
    final phone = context.isPhone;

    final lead = b.lock == LockKind.untilDate && b.lockedUntil != null
        ? tr("It's locked until ${Describe.day(b.lockedUntil!, now)}, here's what it takes to turn it off now:",
            '${Describe.until(b.lockedUntil!, now)} kilitli, şimdi kapatmak için gerekenler:')
        : tr("Here's what it takes to turn it off now:", 'Şimdi kapatmak için gerekenler:');

    var n = 0;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Ms(Symbols.lock_open_rounded, size: 28, color: c.primary)),
      const SizedBox(height: 16),
      Text(tr('Unlock ${b.name} early?', '${b.name} engelinin kilidi erken açılsın mı?'), textAlign: TextAlign.center, style: body(24, weight: FontWeight.w500, color: c.onSurface)),
      const SizedBox(height: 6),
      Text(lead, textAlign: TextAlign.center, style: body(15, color: c.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 6),
      if (steps.wait)
        _StepBox(
          number: ++n,
          state: waitDone ? _StepState.done : _StepState.waiting,
          title: waitDone ? tr('The wait is over', 'Bekleme bitti') : tr('Wait ${Describe.minutes(steps.waitMinutes)}', '${Describe.minutes(steps.waitMinutes)} bekle'),
          child: waitDone
              ? null
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(tr('You can close this, NoLook tells you when the wait is over.', 'Bunu kapatabilirsin, bekleme bitince NoLook haber verir.'),
                      style: body(14, color: c.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: 1 - (waitLeft ?? Duration.zero).inSeconds / (steps.waitMinutes * 60),
                      minHeight: 6,
                      color: c.primary,
                      backgroundColor: c.secondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(tr('Started at ${Describe.time(b.unlockStartedAt ?? now)}', 'Başlangıç: ${Describe.time(b.unlockStartedAt ?? now)}'), style: body(13, color: c.onSurfaceVariant)),
                    const Spacer(),
                    Text(_clock(waitLeft ?? Duration.zero), style: display(20, color: c.onSurface)),
                    Text(tr(' left', ' kaldı'), style: body(13, color: c.onSurfaceVariant)),
                  ]),
                ]),
        ),
      if (steps.type)
        _StepBox(
          number: ++n,
          state: !waitDone ? _StepState.todo : (typedOk ? _StepState.done : _StepState.now),
          title: tr('Type this sentence', 'Bu cümleyi yaz'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.outlineVariant),
              ),
              // not selectable, no copy paste
              child: SelectionContainer.disabled(child: Text(steps.sentence, style: body(14, color: c.onSurface))),
            ),
            NlField(
              label: tr('Type it here', 'Buraya yaz'),
              controller: _typed,
              enabled: waitDone,
              dense: true,
              fill: c.surfaceMid,
              hint: waitDone ? null : tr('Unlocks after the wait', 'Beklemeden sonra açılır'),
              onChanged: (_) => setState(() => _error = null),
            ),
          ]),
        ),
      if (left != 0) _emergency(context, left, phone),
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(children: [
          Ms(Symbols.replay_rounded, size: 20, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              b.relockMinutes == null
                  ? tr('Either way, it stays off until you turn it back on.', 'Her iki durumda da sen yeniden açana kadar kapalı kalır.')
                  : tr('Either way, it turns back on by itself after ${Describe.minutes(b.relockMinutes!)}.',
                      'Her iki durumda da ${Describe.minutes(b.relockMinutes!)} sonra kendiliğinden yeniden açılır.'),
              style: body(14, color: c.onSurfaceVariant),
            ),
          ),
        ]),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: body(14, color: c.error))),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        _flex(phone, Btn(tr('Keep it locked', 'Kilitli kalsın'), kind: BtnKind.text, onPressed: () {
          app.cancelUnlock(b);
          Navigator.pop(context);
        })),
        const SizedBox(width: 8),
        _flex(
          phone,
          Btn(tr('Unlock', 'Kilidi aç'), onPressed: waitDone && typedOk ? () => _unlock(context) : null),
        ),
      ]),
    ]);
  }

  Widget _flex(bool phone, Widget w) => phone ? Expanded(child: Center(child: w)) : w;

  Widget _emergency(BuildContext context, int? left, bool phone) {
    final c = context.nl;
    final text = left == null
        ? tr('An emergency unlock skips the wait and the typing.', 'Acil kilit açma, beklemeyi ve yazmayı atlar.')
        : tr('An emergency unlock skips the wait and the typing, you have $left left this month.',
            'Acil kilit açma, beklemeyi ve yazmayı atlar, bu ay $left hakkın kaldı.');
    final button = Btn(tr('Emergency unlock', 'Acil kilit açma'), kind: BtnKind.outlined, onPressed: () {
      final r = widget.app.emergencyUnlock(widget.block);
      if (r == UnlockResult.unlocked || r == UnlockResult.notLocked) Navigator.pop(context);
    });
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('Need it right now?', 'Hemen mi lazım?'), style: body(15, weight: FontWeight.w600, color: c.onSurface)),
      const SizedBox(height: 2),
      Text(text, style: body(13, color: c.onSurfaceVariant)),
    ]);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: c.outlineVariant)),
      child: phone
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 12), button])
          : Row(children: [Expanded(child: info), const SizedBox(width: 14), button]),
    );
  }

  void _unlock(BuildContext context) {
    final r = widget.app.unlockEarly(widget.block, _typed.text);
    switch (r) {
      case UnlockResult.unlocked || UnlockResult.notLocked:
        Navigator.pop(context);
      case UnlockResult.wrongSentence:
        setState(() => _error = tr("That doesn't match the sentence yet.", 'Bu henüz cümleyle eşleşmiyor.'));
      case UnlockResult.waitNotOver:
        setState(() => _error = tr("The wait isn't over yet.", 'Bekleme henüz bitmedi.'));
      case UnlockResult.noEmergencyLeft:
        break;
    }
  }

  static String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
    return '${h > 0 ? '$h:' : ''}$mm:${s.toString().padLeft(2, '0')}';
  }
}

enum _StepState { waiting, now, todo, done }

class _StepBox extends StatelessWidget {
  const _StepBox({required this.number, required this.state, required this.title, this.child});

  final int number;
  final _StepState state;
  final String title;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final waiting = state == _StepState.waiting;
    final done = state == _StepState.done;
    return Opacity(
      opacity: state == _StepState.todo ? .55 : 1,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.surfaceMid, borderRadius: BorderRadius.circular(20)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: waiting ? c.secondaryContainer : c.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: done
                ? Ms(Symbols.check_rounded, size: 18, color: c.onPrimary)
                : Text('$number',
                    style: body(14, weight: FontWeight.w600, color: waiting ? c.onSecondaryContainer : c.onPrimary)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(title, style: body(15, weight: FontWeight.w600, color: c.onSurface)),
              ),
              if (child != null) ...[const SizedBox(height: 2), child!],
            ]),
          ),
        ]),
      ),
    );
  }
}
