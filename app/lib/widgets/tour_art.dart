import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../platform/os.dart';
import '../theme.dart';
import 'common.dart';

/// tour animations, 0-3: blur, block, locks, browsers
class TourArt extends StatefulWidget {
  const TourArt({super.key, required this.feature});

  final int feature;

  @override
  State<TourArt> createState() => _TourArtState();
}

class _TourArtState extends State<TourArt> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// progress between a and b
  double _p(double a, double b, [Curve curve = const Cubic(.2, 0, 0, 1)]) => curve.transform(((_c.value - a) / (b - a)).clamp(0, 1));

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => switch (widget.feature) {
          0 => _blur(context),
          1 => _block(context),
          2 => _lock(context),
          _ => _browsers(context),
        },
      );

  Widget _in(double k, Widget child, {double dy = 18}) =>
      Opacity(opacity: k.clamp(0, 1), child: Transform.translate(offset: Offset(0, dy * (1 - k)), child: child));

  Widget _pop(double k, Widget child) => Opacity(opacity: k.clamp(0, 1), child: Transform.scale(scale: .7 + .3 * k, child: child));

  // feed post
  Widget _post(BuildContext context, String name, String handle, String text, Color avatar) {
    final c = context.nl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 18, backgroundColor: avatar),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: '$name ', style: body(14, weight: FontWeight.w600, color: c.onSurface)),
              TextSpan(text: handle, style: body(14, color: c.onSurfaceVariant)),
            ])),
            const SizedBox(height: 2),
            Text(text, style: body(15, color: c.onSurface, height: 1.35)),
          ]),
        ),
      ]),
    );
  }

  Widget _blur(BuildContext context) {
    final c = context.nl;
    final blur = _p(.35, .75);
    final pill = _p(.6, .95, const Cubic(.3, 1.4, .5, 1));
    final hidden = Stack(alignment: Alignment.center, children: [
      ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 9 * blur, sigmaY: 9 * blur),
        child: _post(context, 'gamer_lena', '@lena', tr('The GTA 6 ending is wild, Lucia and Jason end up...', 'GTA 6\'nın sonu çılgınca, Lucia ve Jason sonunda...'), const Color(0xFFE08A55)),
      ),
      if (pill > 0)
        _pop(
          pill,
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 12, offset: const Offset(0, 3))]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Ms(Symbols.visibility_off_rounded, size: 18, color: c.primary),
              const SizedBox(width: 8),
              Text(tr('Hidden by NoLook', 'NoLook tarafından gizlendi'), style: body(14, weight: FontWeight.w600, color: c.onSurface)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(999)),
                child: Text(tr('Show', 'Göster'), style: body(13, weight: FontWeight.w600, color: c.onSecondaryContainer)),
              ),
            ]),
          ),
        ),
    ]);
    return _in(
      _p(0, .3),
      _Window(
        title: 'x.com',
        child: Column(children: [
          _post(context, 'sam', '@samplays', tr('Finally finished my backlog, ready for next week', 'Sonunda biriken oyunlarımı bitirdim, gelecek haftaya hazırım'), const Color(0xFF3F8EA3)),
          Divider(height: 1, color: c.outlineVariant.withValues(alpha: .5)),
          hidden,
          Divider(height: 1, color: c.outlineVariant.withValues(alpha: .5)),
          _post(context, 'coffee_maps', '@coffeemaps', tr('New place opened downtown, the oat latte is great', 'Şehir merkezinde yeni bir yer açılmış, yulaf sütlü latte harika'), const Color(0xFF7A62B3)),
        ]),
      ),
    );
  }

  Widget _block(BuildContext context) {
    final c = context.nl;
    final page = _p(.25, .55);
    final app = _p(.55, .8, const Cubic(.3, 1.4, .5, 1));
    final closed = _p(.85, 1);
    return Stack(clipBehavior: Clip.none, children: [
      _in(
        _p(0, .3),
        _Window(
          title: 'reddit.com/r/GTA6',
          child: SizedBox(
            height: 230,
            child: Opacity(
              opacity: page,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: c.tertiaryContainer, borderRadius: BorderRadius.circular(18)),
                  alignment: Alignment.center,
                  child: Text('VI', style: display(18, weight: FontWeight.w800, color: c.onTertiaryContainer)),
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: 'reddit.com/r/GTA6 ', style: display(22, color: c.primary)),
                    TextSpan(text: tr('is blocked', 'engellendi'), style: display(22, color: c.onSurface)),
                  ]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text(tr('Go back', 'Geri dön'), style: body(14, weight: FontWeight.w600, color: c.onPrimary)),
                ),
              ]),
            ),
          ),
        ),
      ),
      Positioned(
        right: -14,
        bottom: -26,
        child: _pop(
          app,
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .14), blurRadius: 18, offset: const Offset(0, 6))]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: const Color(0xFF191C20), borderRadius: BorderRadius.circular(12)),
                  child: const Ms(Symbols.music_note_rounded, color: Colors.white, size: 22, fill: true),
                ),
                if (closed > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: _pop(closed, Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(color: c.error, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                      child: const Ms(Symbols.close_rounded, size: 13, color: Colors.white),
                    )),
                  ),
              ]),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('TikTok', style: body(14, weight: FontWeight.w600, color: c.onSurface)),
                Text(closed > 0 ? tr('Closed by NoLook', 'NoLook tarafından kapatıldı') : tr('Opening...', 'Açılıyor...'), style: body(13, color: closed > 0 ? c.error : c.onSurfaceVariant)),
              ]),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _lock(BuildContext context) {
    final c = context.nl;
    final on = _c.value > .35;
    final locked = _c.value > .55;
    final chip = [_p(.62, .8), _p(.72, .9), _p(.82, 1)];
    Widget rule(double k, IconData icon, String text) => _in(
          k,
          dy: 10,
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Ms(icon, size: 20, color: c.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: body(14, color: c.onSurface))),
            ]),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _in(
        _p(0, .3),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: c.tertiaryContainer, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: c.wash, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text('VI', style: display(15, weight: FontWeight.w800, color: c.onTertiaryContainer)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(tr('GTA 6 spoilers', 'GTA 6 spoilerleri'), style: body(17, weight: FontWeight.w600, color: c.onTertiaryContainer))),
              NlSwitch(value: on, locked: locked),
            ]),
            const SizedBox(height: 16),
            Divider(height: 1, color: c.onTertiaryContainer.withValues(alpha: .15)),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Row(key: ValueKey(locked), children: [
                Ms(locked ? Symbols.lock_rounded : Symbols.lock_open_rounded, size: 18, color: c.onTertiaryContainer, fill: locked),
                const SizedBox(width: 8),
                Text.rich(TextSpan(children: [
                  TextSpan(text: locked ? tr('Locked until ', 'Kilitli: ') : tr('No lock', 'Kilit yok'), style: body(14, color: c.onTertiaryContainer)),
                  if (locked) TextSpan(text: tr('19 December', '19 Aralık\'a kadar'), style: body(14, weight: FontWeight.w700, color: c.onTertiaryContainer)),
                ])),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 4),
      rule(chip[0], Symbols.hourglass_top_rounded, tr('To unlock early, wait 30 min', 'Erken açmak için 30 dk bekle')),
      rule(chip[1], Symbols.keyboard_rounded, tr('Then type a sentence', 'Sonra bir cümle yaz')),
      rule(chip[2], Symbols.emergency_rounded, tr('3 emergency unlocks a month', 'Ayda 3 acil kilit açma')),
    ]);
  }

  Widget _browsers(BuildContext context) {
    final c = context.nl;
    Widget row(int i, String name, String sub) {
      final k = _p(.12 + i * .14, .4 + i * .14);
      final tick = _p(.45 + i * .14, .65 + i * .14, const Cubic(.3, 1.4, .5, 1));
      return _in(
        k,
        dy: 12,
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Ms(Symbols.extension_rounded, size: 22, color: c.onSecondaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: body(16, weight: FontWeight.w600, color: c.onSurface)),
                Text(sub, style: body(13, color: c.onSurfaceVariant)),
              ]),
            ),
            Opacity(
              opacity: tick.clamp(0, 1),
              child: Transform.scale(
                scale: .6 + .4 * tick,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Ms(Symbols.check_circle_rounded, size: 20, color: c.primary, fill: true),
                  const SizedBox(width: 6),
                  Text(tr('Connected', 'Bağlı'), style: body(13, weight: FontWeight.w600, color: c.primary)),
                ]),
              ),
            ),
          ]),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _in(
        _p(0, .25),
        Row(children: [
          const LogoIcon(size: 44),
          const SizedBox(width: 12),
          Expanded(
              child: Text(onMobile ? tr('Your blocks, in every app', 'Engellerin, her uygulamada') : tr('Your blocks, from this app', 'Engellerin, bu uygulamadan'),
                  style: body(15, weight: FontWeight.w600, color: c.onPrimaryContainer))),
        ]),
      ),
      const SizedBox(height: 16),
      if (onMobile) ...[
        row(0, 'YouTube', tr('Covers matching videos', 'Eşleşen videoları örter')),
        row(1, 'TikTok', tr('Skips matching videos', 'Eşleşen videoları atlar')),
        row(2, 'Chrome', tr('Covers and blocks', 'Örter ve engeller')),
      ] else ...[
        row(0, 'Chrome', tr('Blurs and blocks', 'Bulanıklaştırır ve engeller')),
        row(1, 'Edge', tr('Blurs and blocks', 'Bulanıklaştırır ve engeller')),
        row(2, 'Firefox', tr('Blurs and blocks', 'Bulanıklaştırır ve engeller')),
      ],
    ]);
  }
}

class _Window extends StatelessWidget {
  const _Window({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: c.surfaceMid,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(999)),
            child: Row(children: [
              Ms(Symbols.lock_rounded, size: 14, color: c.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(title, style: body(13, color: c.onSurfaceVariant)),
            ]),
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4), child: child),
      ]),
    );
  }
}
