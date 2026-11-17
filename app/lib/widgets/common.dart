import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:nolook_core/nolook_core.dart';

import '../theme.dart';

class Ms extends StatelessWidget {
  const Ms(this.icon, {super.key, this.size = 24, this.color, this.fill = false});

  final IconData icon;
  final double size;
  final Color? color;
  final bool fill;

  @override
  Widget build(BuildContext context) => Icon(icon, size: size, color: color, fill: fill ? 1 : 0, weight: 400, opticalSize: 24);
}

/// fixed list so the icon font stays small
const blockIcons = <String, IconData>{
  'forum': Symbols.forum_rounded,
  'bedtime': Symbols.bedtime_rounded,
  'work': Symbols.work_rounded,
  'smart_display': Symbols.smart_display_rounded,
  'sports_esports': Symbols.sports_esports_rounded,
  'movie': Symbols.movie_rounded,
  'newspaper': Symbols.newspaper_rounded,
  'shopping_bag': Symbols.shopping_bag_rounded,
  'sports_soccer': Symbols.sports_soccer_rounded,
  'music_note': Symbols.music_note_rounded,
  'block': Symbols.block_rounded,
  'visibility_off': Symbols.visibility_off_rounded,
};

/// switch, shows a lock when [locked]
class NlSwitch extends StatelessWidget {
  const NlSwitch({super.key, required this.value, this.locked = false, this.onTap, this.scale = 1, this.tooltip});

  final bool value;
  final bool locked;
  final VoidCallback? onTap;
  final double scale;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final on = value;
    const curve = Cubic(.3, 1.4, .5, 1);
    final sw = MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Semantics(
          toggled: on,
          label: locked ? tr('Locked, click to unlock early', 'Kilitli, erken açmak için tıkla') : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52 * scale,
            height: 32 * scale,
            decoration: BoxDecoration(
              color: on ? c.primary : c.surfaceHigh,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: on ? c.primary : c.outline, width: 2 * scale),
            ),
            child: Stack(children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: curve,
                left: (on ? 22 : 6) * scale,
                top: (on ? 2 : 6) * scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: curve,
                  width: (on ? 24 : 16) * scale,
                  height: (on ? 24 : 16) * scale,
                  decoration: BoxDecoration(color: on ? c.onPrimary : c.outline, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: locked && on ? Ms(Symbols.lock_rounded, size: 14 * scale, color: c.primary, fill: true) : null,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    return tooltip == null ? sw : Tooltip(message: tooltip!, child: sw);
  }
}

class NlCard extends StatelessWidget {
  const NlCard({super.key, required this.child, this.color, this.padding, this.radius, this.onTap, this.border});

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double? radius;
  final VoidCallback? onTap;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? (context.isPhone ? 24 : 28);
    final inner = Padding(padding: padding ?? EdgeInsets.all(context.isPhone ? 20 : 24), child: child);
    return Material(
      color: color ?? context.nl.surfaceMid,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(r),
        side: border is Border ? (border as Border).top : BorderSide.none,
      ),
      child: onTap == null ? inner : InkWell(onTap: onTap, child: inner),
    );
  }
}

enum BtnKind { filled, tonal, outlined, text, danger }

class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, this.onPressed, this.icon, this.trailing, this.kind = BtnKind.filled, this.big = false, this.wide = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// trailing icon
  final IconData? trailing;
  final BtnKind kind;
  final bool big;

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final (bg, fg, side) = switch (kind) {
      BtnKind.filled => (c.primary, c.onPrimary, BorderSide.none),
      BtnKind.tonal => (c.secondaryContainer, c.onSecondaryContainer, BorderSide.none),
      BtnKind.outlined => (Colors.transparent, c.primary, BorderSide(color: c.outlineVariant)),
      BtnKind.text => (Colors.transparent, c.primary, BorderSide.none),
      BtnKind.danger => (c.error, c.onPrimary, BorderSide.none),
    };
    final h = big ? 56.0 : 40.0;
    final padL = kind == BtnKind.text ? 12.0 : (icon != null ? 16.0 : (big ? 28.0 : 20.0));
    final padR = kind == BtnKind.text ? 12.0 : (trailing != null ? (big ? 22.0 : 16.0) : (big ? 28.0 : 20.0));
    return Opacity(
      opacity: onPressed == null ? 0.38 : 1,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: side),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          overlayColor: WidgetStatePropertyAll(fg.withValues(alpha: 0.08)),
          child: Container(
            height: h,
            padding: EdgeInsets.only(left: padL, right: padR),
            alignment: wide ? Alignment.center : null,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Ms(icon!, size: 18, color: fg), const SizedBox(width: 8)],
              Text(label, style: body(big ? 16 : 14, weight: FontWeight.w500, color: fg), maxLines: 1),
              if (trailing != null) ...[const SizedBox(width: 10), Ms(trailing!, size: 18, color: fg)],
            ]),
          ),
        ),
      ),
    );
  }
}

class IconBtn extends StatelessWidget {
  const IconBtn(this.icon, {super.key, this.onPressed, this.tooltip, this.color, this.fill = false});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final bool fill;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(fixedSize: const Size(44, 44), foregroundColor: color ?? context.nl.onSurfaceVariant),
        icon: Ms(icon, color: color ?? context.nl.onSurfaceVariant, fill: fill),
      );
}

class NlChip extends StatelessWidget {
  const NlChip(this.label, {super.key, this.selected = false, this.icon, this.onTap});

  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final fg = selected ? c.onSecondaryContainer : c.onSurfaceVariant;
    return Material(
      color: selected ? c.secondaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: selected ? BorderSide.none : BorderSide(color: c.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Ms(icon!, size: 18, color: fg), const SizedBox(width: 6)],
            Text(label, style: body(14, weight: FontWeight.w500, color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// removable chip
class ItemChip extends StatelessWidget {
  const ItemChip(this.label, {super.key, this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final text = Text(label, style: body(14, weight: FontWeight.w500, color: c.onSurface));
    return Container(
      height: 32,
      padding: EdgeInsets.only(left: 12, right: onRemove == null ? 12 : 4),
      decoration: BoxDecoration(
        color: c.surfaceLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        text,
        if (onRemove != null) ...[
          const SizedBox(width: 2),
          InkResponse(
            onTap: onRemove,
            radius: 14,
            child: Padding(padding: const EdgeInsets.all(3), child: Ms(Symbols.close_rounded, size: 18, color: c.onSurfaceVariant)),
          ),
        ],
      ]),
    );
  }
}

/// blurred until hover/tap
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.sigma = 4});

  final Widget child;
  final double sigma;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _shown = true),
        onExit: (_) => setState(() => _shown = false),
        child: GestureDetector(
          onTap: () => setState(() => _shown = !_shown),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _shown ? 0 : widget.sigma),
            duration: const Duration(milliseconds: 200),
            builder: (_, s, child) => ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: s, sigmaY: s, tileMode: TileMode.decal),
              child: child,
            ),
            child: widget.child,
          ),
        ),
      );
}

class Seg<T> extends StatelessWidget {
  const Seg({super.key, required this.options, required this.value, required this.onChanged, this.enabled = true});

  final List<(T, String, IconData?)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: c.outline), borderRadius: BorderRadius.circular(999)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: IntrinsicHeight(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) VerticalDivider(width: 1, thickness: 1, color: c.outline),
                _segButton(context, options[i]),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _segButton(BuildContext context, (T, String, IconData?) o) {
    final c = context.nl;
    final on = o.$1 == value;
    return Material(
      color: on ? c.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => onChanged(o.$1) : null,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (o.$3 != null) ...[Ms(o.$3!, size: 18, color: on ? c.onSecondaryContainer : c.onSurface), const SizedBox(width: 6)],
            Text(o.$2, style: body(14, weight: FontWeight.w500, color: on ? c.onSecondaryContainer : c.onSurface)),
          ]),
        ),
      ),
    );
  }
}

class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.icon, required this.title, required this.text, required this.selected, required this.onTap});

  final IconData icon;
  final String title;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final fg = selected ? c.onPrimaryContainer : c.onSurface;
    final phone = context.isPhone;
    return Material(
      color: selected ? c.primaryContainer : c.surfaceLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? c.primary : Colors.transparent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(phone ? 14 : 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Ms(icon, size: 26, color: fg),
            const SizedBox(height: 8),
            Text(title, style: body(16, weight: FontWeight.w600, color: fg)),
            const SizedBox(height: 4),
            Text(text, style: body(14, color: fg.withValues(alpha: .75))),
          ]),
        ),
      ),
    );
  }
}

/// wrapping grid, min 200 wide, 2 per row on phones
class ChoiceGrid extends StatelessWidget {
  const ChoiceGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final perRow = context.isPhone ? 2 : (box.maxWidth / 210).floor().clamp(1, children.length);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += perRow) {
          final slice = children.sublist(i, (i + perRow).clamp(0, children.length));
          rows.add(IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var j = 0; j < perRow; j++) ...[
                if (j > 0) const SizedBox(width: 10),
                Expanded(child: j < slice.length ? slice[j] : const SizedBox()),
              ],
            ]),
          ));
        }
        return Column(children: [for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 10), rows[i]]]);
      });
}

class NlField extends StatelessWidget {
  const NlField({
    super.key,
    required this.label,
    this.controller,
    this.icon,
    this.hint,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.dense = false,
    this.fill,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController? controller;
  final IconData? icon;
  final String? hint;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool autofocus;
  final bool dense;

  /// label bg, match the card
  final Color? fill;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    OutlineInputBorder border(Color color, double w) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color, width: w));
    return SizedBox(
      height: dense ? 48 : 56,
      child: TextField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
        inputFormatters: inputFormatters,
        style: body(16, color: c.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: body(14, color: c.onSurfaceVariant),
          floatingLabelStyle: body(13, color: c.onSurfaceVariant),
          hintStyle: body(16, color: c.onSurfaceVariant.withValues(alpha: .7)),
          prefixIcon: icon == null ? null : Ms(icon!, color: c.onSurfaceVariant),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: border(c.outline, 1),
          disabledBorder: border(c.outlineVariant, 1),
          focusedBorder: border(c.primary, 2),
          filled: fill != null,
          fillColor: fill,
        ),
      ),
    );
  }
}

/// app icon
class LogoIcon extends StatelessWidget {
  const LogoIcon({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final s = size / 100;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(28 * s)),
      child: Stack(children: [
        // same coords as the svg
        Positioned(left: (17 + 8 * .66) * s, top: (17 + 22 * .66) * s, child: _flap(c.primary, s)),
        Positioned(left: (17 + 72 * .66) * s, top: (17 + 22 * .66) * s, child: _flap(c.primary, s)),
        Positioned(
          left: (17 + 35 * .66) * s,
          top: (17 + 35 * .66) * s,
          child: Container(
            width: 30 * .66 * s,
            height: 30 * .66 * s,
            decoration: BoxDecoration(color: c.onPrimaryContainer, shape: BoxShape.circle),
          ),
        ),
      ]),
    );
  }

  Widget _flap(Color color, double s) => Container(
        width: 20 * .66 * s,
        height: 56 * .66 * s,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10 * .66 * s)),
      );
}

/// wordmark
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.height = 22, this.color});

  final double height;
  final Color? color;

  static const _path =
      'M0 100V40 M0 70A30 30 0 0 1 60 70V100 M81 70A31 31 0 1 0 143 70A31 31 0 1 0 81 70 M164 10V100 '
      'M185 70A31 31 0 1 0 247 70A31 31 0 1 0 185 70 M263 70A31 31 0 1 0 325 70A31 31 0 1 0 263 70 '
      'M346 10V100 M390 40L349 76 M363 64L392 100';

  @override
  Widget build(BuildContext context) {
    final col = color ?? context.nl.onPrimaryContainer;
    final hex = '#${(col.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-7 3 406 106"><path fill="none" stroke="$hex" '
      'stroke-width="14" stroke-linecap="round" stroke-linejoin="round" d="$_path"/></svg>',
      height: height,
      semanticsLabel: 'NoLook',
    );
  }
}

class Brandmark extends StatelessWidget {
  const Brandmark({super.key});

  @override
  Widget build(BuildContext context) =>
      const Row(mainAxisSize: MainAxisSize.min, children: [LogoIcon(), SizedBox(width: 10), Wordmark()]);
}

/// css style border radius blob
class Blob extends StatelessWidget {
  const Blob({super.key, required this.size, required this.color, this.radii = const [.42, .58, .60, .40, .45, .45, .55, .55]});

  final double size;
  final Color color;

  /// tl tr br bl horizontal, then vertical, as fractions
  final List<double> radii;

  @override
  Widget build(BuildContext context) {
    final r = radii.map((v) => v * size).toList();
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.elliptical(r[0], r[4]),
            topRight: Radius.elliptical(r[1], r[5]),
            bottomRight: Radius.elliptical(r[2], r[6]),
            bottomLeft: Radius.elliptical(r[3], r[7]),
          ),
        ),
      ),
    );
  }
}

/// 12 col grid, full width on phones, equal height rows
class Grid12 extends StatelessWidget {
  const Grid12({super.key, required this.items, this.gap = 12});

  final List<(int, Widget)> items;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final g = phone ? 10.0 : gap;
    return LayoutBuilder(builder: (context, box) {
      final col = (box.maxWidth - 11 * g) / 12;
      final rows = <List<(int, Widget)>>[];
      var used = 12;
      for (final it in items) {
        final span = phone ? 12 : it.$1;
        if (used + span > 12) {
          rows.add([]);
          used = 0;
        }
        rows.last.add((span, it.$2));
        used += span;
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: g),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var j = 0; j < rows[i].length; j++) ...[
                if (j > 0) SizedBox(width: g),
                SizedBox(width: col * rows[i][j].$1 + g * (rows[i][j].$1 - 1), child: rows[i][j].$2),
              ],
            ]),
          ),
        ],
      ]);
    });
  }
}

/// card span: 3 per row normally, up to 6 wide, 1 on phones
int cardSpan(BuildContext context, {int? count}) {
  if (context.isPhone) return 12;
  final w = MediaQuery.sizeOf(context).width - 96 - 56;
  var perRow = (w / 380).floor().clamp(2, 6);
  // fill the row, balance rows (6 = 3+3 not 4+2)
  if (count != null && count > 0) {
    final rows = (count / perRow).ceil();
    perRow = (count / rows).ceil();
  }
  return 12 ~/ (perRow == 5 ? 4 : perRow);
}

class NlRow extends StatelessWidget {
  const NlRow({super.key, required this.icon, required this.title, this.subtitle, this.end, this.square = false, this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? end;
  final bool square;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.surfaceHigh,
            borderRadius: BorderRadius.circular(square ? 12 : 20),
          ),
          alignment: Alignment.center,
          child: Ms(icon, size: 20, color: c.onSurfaceVariant),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: body(16, color: c.onSurface)),
            if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, style: body(14, color: c.onSurfaceVariant)),
          ]),
        ),
        if (end != null) ...[const SizedBox(width: 12), end!],
      ]),
    );
    return onTap == null ? row : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: row);
  }
}

class RowEnd extends StatelessWidget {
  const RowEnd(this.text, {super.key, this.icon, this.ok = false});

  final String text;
  final IconData? icon;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final col = ok ? c.primary : c.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Ms(icon!, size: 18, color: col), const SizedBox(width: 4)],
      Text(text, style: body(13, weight: ok ? FontWeight.w500 : FontWeight.w400, color: col)),
    ]);
  }
}

class PageBar extends StatelessWidget {
  const PageBar({super.key, this.title, this.leading, this.actions = const [], this.logo = false});

  final String? title;
  final Widget? leading;
  final List<Widget> actions;
  final bool logo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            if (logo) const Brandmark(),
            if (title != null)
              Expanded(
                child: Text(title!,
                    style: body(context.isPhone ? 22 : 28, weight: FontWeight.w500, color: context.nl.onSurface),
                    overflow: TextOverflow.ellipsis),
              )
            else
              const Spacer(),
            ...actions,
          ]),
        ),
      );
}

class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: Row(children: [
          Expanded(child: Text(title, style: body(context.isPhone ? 20 : 22, weight: FontWeight.w500, color: context.nl.onSurface))),
          ?action,
        ]),
      );
}

class CardLabel extends StatelessWidget {
  const CardLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: body(14, weight: FontWeight.w600, color: context.nl.primary)),
      );
}

void toast(BuildContext context, String text) {
  final c = context.nl;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text, style: body(14, color: c.surface)),
    backgroundColor: c.onSurface,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    width: context.isPhone ? null : 420,
  ));
}
