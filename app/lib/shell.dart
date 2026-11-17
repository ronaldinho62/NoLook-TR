import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:nolook_core/nolook_core.dart';

import 'controller.dart';
import 'screens/app_blocked.dart';
import 'screens/blocks.dart';
import 'screens/devices.dart';
import 'screens/edit_block.dart';
import 'screens/home.dart';
import 'screens/settings.dart';
import 'screens/unlock.dart';
import 'theme.dart';
import 'widgets/common.dart';

enum NavTab { home, blocks, devices, settings }

/// push inside the shell
/// material shared axis transition
Future<T?> go<T>(BuildContext context, Widget page) => Navigator.of(context).push<T>(SharedAxisRoute(page));

class SharedAxisRoute<T> extends PageRouteBuilder<T> {
  SharedAxisRoute(Widget page)
      : super(
          pageBuilder: (_, _, _) => page,
          transitionDuration: const Duration(milliseconds: 340),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, a, b, child) {
            const curve = Cubic(.2, 0, 0, 1);
            final inT = CurvedAnimation(parent: a, curve: curve, reverseCurve: curve.flipped);
            final outT = CurvedAnimation(parent: b, curve: curve, reverseCurve: curve.flipped);
            final width = MediaQuery.sizeOf(context).width;
            final shift = (width * .04).clamp(20.0, 48.0);
            return AnimatedBuilder(
              animation: Listenable.merge([inT, outT]),
              child: child,
              builder: (context, child) {
                // in
                final inFade = Curves.easeOut.transform(((inT.value - .25) / .75).clamp(0.0, 1.0));
                // out
                final outFade = 1 - Curves.easeIn.transform((outT.value / .35).clamp(0.0, 1.0));
                final dx = shift * (1 - inT.value) - shift * outT.value;
                return Opacity(
                  opacity: inFade * outFade,
                  child: Transform.translate(offset: Offset(dx, 0), child: child),
                );
              },
            );
          },
        );
}

/// material fade through
class FadeThroughRoute<T> extends PageRouteBuilder<T> {
  FadeThroughRoute(Widget page)
      : super(
          pageBuilder: (_, _, _) => page,
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, a, b, child) {
            final fade = CurvedAnimation(parent: a, curve: const Interval(.3, 1, curve: Cubic(.2, 0, 0, 1)));
            final scale = Tween(begin: .96, end: 1.0).animate(fade);
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(scale: scale, child: child),
            );
          },
        );
}

/// full screen pages hide the dock
final hideDock = ValueNotifier<int>(0);

class Shell extends StatefulWidget {
  const Shell({super.key, required this.app});

  final NoLook app;

  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  final _nav = GlobalKey<NavigatorState>();
  NavTab _tab = NavTab.home;

  NoLook get app => widget.app;

  @override
  void initState() {
    super.initState();
    app.unlockRequest.addListener(_onUnlockRequest);
    app.blockedApp.addListener(_onBlockedApp);
    app.newBlockRequest.addListener(_onNewBlockRequest);
    app.tabRequest.addListener(_onTabRequest);
    // set by setup
    if (app.newBlockRequest.value != null) WidgetsBinding.instance.addPostFrameCallback((_) => _onNewBlockRequest());
  }

  @override
  void dispose() {
    app.unlockRequest.removeListener(_onUnlockRequest);
    app.blockedApp.removeListener(_onBlockedApp);
    app.newBlockRequest.removeListener(_onNewBlockRequest);
    app.tabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onUnlockRequest() {
    final id = app.unlockRequest.value;
    if (id == null) return;
    app.unlockRequest.value = null;
    final b = app.state.block(id);
    final ctx = _nav.currentContext;
    if (b == null || ctx == null) return;
    if (!app.toggle(b)) showUnlock(ctx, app, b);
  }

  void _onTabRequest() {
    final name = app.tabRequest.value;
    if (name == null) return;
    app.tabRequest.value = null;
    final tab = NavTab.values.where((t) => t.name == name).firstOrNull;
    if (tab != null) select(tab);
  }

  void _onNewBlockRequest() {
    final site = app.newBlockRequest.value;
    final ctx = _nav.currentContext;
    if (site == null || ctx == null) return;
    app.newBlockRequest.value = null;
    go(ctx, EditBlockPage(app: app, sites: [?SiteRule.normalize(site)]));
  }

  void _onBlockedApp() {
    final notice = app.blockedApp.value;
    final ctx = _nav.currentContext;
    if (notice == null || ctx == null) return;
    app.blockedApp.value = null;
    showAppBlocked(ctx, app, notice);
  }

  Widget _page(NavTab t) => switch (t) {
        NavTab.home => HomePage(app: app),
        NavTab.blocks => BlocksPage(app: app),
        NavTab.devices => DevicesPage(app: app),
        NavTab.settings => SettingsPage(app: app),
      };

  void select(NavTab t) {
    setState(() => _tab = t);
    _nav.currentState!.pushAndRemoveUntil(FadeThroughRoute(_page(t)), (_) => false);
  }

  void newBlock() => go(_nav.currentContext!, EditBlockPage(app: app));

  DateTime? _lastBack;

  /// back: pop, then home, then double press to exit
  void _back() {
    final nav = _nav.currentState;
    if (nav != null && nav.canPop()) {
      nav.maybePop();
      return;
    }
    if (_tab != NavTab.home) {
      select(NavTab.home);
      return;
    }
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(tr('Press back again to close NoLook', 'NoLook\'u kapatmak için tekrar geri tuşuna bas')),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 112),
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final content = Navigator(
      key: _nav,
      onGenerateRoute: (_) => PageRouteBuilder(pageBuilder: (_, _, _) => _page(_tab), transitionDuration: Duration.zero),
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
      body: phone
          ? Stack(fit: StackFit.expand, children: [
              Positioned.fill(child: content),
              ValueListenableBuilder(
                valueListenable: hideDock,
                builder: (_, hidden, _) => hidden > 0 ? const SizedBox() : _Dock(tab: _tab, onTab: select, onAdd: newBlock),
              ),
            ])
          : Row(children: [
              _Rail(tab: _tab, onTab: select, onAdd: newBlock),
              Expanded(child: content),
            ]),
      ),
    );
  }
}

List<(NavTab, IconData, String)> get _dests => [
      (NavTab.home, Symbols.home_rounded, tr('Home', 'Ana sayfa')),
      (NavTab.blocks, Symbols.block_rounded, tr('Blocks', 'Engeller')),
      (NavTab.devices, Symbols.devices_rounded, tr('Devices', 'Cihazlar')),
      (NavTab.settings, Symbols.settings_rounded, tr('Settings', 'Ayarlar')),
    ];

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap, this.size = 56, this.radius = 16});

  final VoidCallback onTap;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Tooltip(
      message: tr('New block', 'Yeni engel'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .12), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Material(
          color: c.primaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(width: size, height: size, child: Ms(Symbols.add_rounded, color: c.onPrimaryContainer)),
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.tab, required this.onTab, required this.onAdd});

  final NavTab tab;
  final ValueChanged<NavTab> onTab;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return SizedBox(
      width: 96,
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(children: [
          _Fab(onTap: onAdd),
          const SizedBox(height: 36),
          for (final (t, icon, label) in _dests)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _RailDest(icon: icon, label: label, on: t == tab, onTap: () => onTab(t), c: c),
            ),
        ]),
      ),
    );
  }
}

class _RailDest extends StatefulWidget {
  const _RailDest({required this.icon, required this.label, required this.on, required this.onTap, required this.c});

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  final NlColors c;

  @override
  State<_RailDest> createState() => _RailDestState();
}

class _RailDestState extends State<_RailDest> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final on = widget.on;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          button: true,
          selected: on,
          label: widget.label,
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: on ? c.secondaryContainer : (_hover ? c.surfaceHigh : Colors.transparent),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Ms(widget.icon, color: on ? c.onSecondaryContainer : c.onSurfaceVariant, fill: on),
            ),
            const SizedBox(height: 4),
            Text(widget.label, style: body(12, weight: FontWeight.w500, color: on ? c.onSurface : c.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.tab, required this.onTab, required this.onAdd});

  final NavTab tab;
  final ValueChanged<NavTab> onTab;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 16 + MediaQuery.paddingOf(context).bottom,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: c.surfaceHigh,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 20, offset: const Offset(0, 6), spreadRadius: -6),
              BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 3, offset: const Offset(0, 1)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final (t, icon, label) in _dests)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Material(
                  color: t == tab ? c.secondaryContainer : Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onTab(t),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Container(
                        height: 48,
                        padding: EdgeInsets.only(left: 14, right: t == tab ? 18 : 14),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Ms(icon, color: t == tab ? c.onSecondaryContainer : c.onSurfaceVariant, fill: t == tab),
                          if (t == tab) ...[
                            const SizedBox(width: 8),
                            Text(label, style: body(14, weight: FontWeight.w500, color: c.onSecondaryContainer)),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 10),
        _Fab(onTap: onAdd, size: 60, radius: 20),
      ]),
    );
  }
}

class NlPage extends StatelessWidget {
  const NlPage({super.key, required this.children, this.header});

  final List<Widget> children;

  /// sticky header
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final phone = context.isPhone;
    final top = MediaQuery.paddingOf(context).top;
    final side = phone ? const EdgeInsets.fromLTRB(16, 0, 16, 0) : const EdgeInsets.fromLTRB(16, 0, 40, 0);
    final scroll = Scrollbar(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(side.left, header != null ? 4 : (phone ? 8 : 28) + top, side.right, phone ? 130 : 60),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
    return Material(
      color: context.nl.surface,
      child: header != null
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(padding: EdgeInsets.fromLTRB(side.left, (phone ? 8 : 28) + top, side.right, 4), child: header),
              Expanded(child: scroll),
            ])
          : Stack(children: [
              scroll,
              // phones: background strip under the status bar
              if (top > 0) Positioned(left: 0, right: 0, top: 0, height: top, child: ColoredBox(color: context.nl.surface)),
            ]),
    );
  }
}

ShellState shellOf(BuildContext context) => context.findAncestorStateOfType<ShellState>()!;
