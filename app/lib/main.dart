import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:nolook_core/nolook_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'controller.dart';
import 'platform/android_link.dart';
import 'platform/browser_link.dart';
import 'platform/startup.dart';
import 'screens/setup.dart';
import 'shell.dart';
import 'theme.dart';

/// single instance port
const _instancePort = 47361;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final desktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  ServerSocket? instance;
  if (desktop) {
    try {
      instance = await ServerSocket.bind(InternetAddress.loopbackIPv4, _instancePort);
    } on SocketException {
      try {
        final s = await Socket.connect(InternetAddress.loopbackIPv4, _instancePort);
        s.write('show');
        await s.flush();
        await s.close();
      } catch (_) {}
      exit(0);
    }
  }

  // app folder on android
  final app = NoLook.open(dir: Platform.isAndroid ? await getApplicationSupportDirectory() : null);

  if (desktop) {
    await windowManager.ensureInitialized();
    final hidden = args.contains('--hidden');
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1360, 900),
        minimumSize: Size(400, 640),
        center: true,
        title: 'NoLook',
        backgroundColor: Color(0xFFF8F9FF),
      ),
      () async {
        await windowManager.setPreventClose(true);
        if (!hidden) {
          await windowManager.show();
          await windowManager.focus();
        }
      },
    );
    await localNotifier.setup(appName: 'NoLook', shortcutPolicy: ShortcutPolicy.requireCreate);
    app.notify = (title, text) => LocalNotification(title: title, body: text).show();
    app.showWindow = () async {
      await windowManager.show();
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.focus();
    };
    // "show" from a 2nd instance or the helper. the helper also connects empty just to ping
    instance?.listen((socket) {
      socket.listen((data) {
        if (String.fromCharCodes(data).contains('show')) app.showWindow?.call();
      }, onDone: socket.destroy, onError: (_) => socket.destroy());
    });
    unawaited(registerBrowserHelper());
    if (app.state.settings.startWithSystem) unawaited(setStartWithWindows(true));
  }

  app.start();
  unawaited(app.startLink(Platform.isAndroid ? 'Android' : Platform.isWindows ? 'Windows' : Platform.isMacOS ? 'macOS' : 'Linux'));
  if (Platform.isAndroid) AndroidLink.attach(app);
  runApp(NoLookApp(app: app));
  if (desktop) await _Tray(app).setUp();
}

class NoLookApp extends StatefulWidget {
  const NoLookApp({super.key, required this.app});

  final NoLook app;

  @override
  State<NoLookApp> createState() => _NoLookAppState();
}

class _NoLookAppState extends State<NoLookApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  /// close = hide to tray
  @override
  void onWindowClose() => windowManager.hide();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.app,
        builder: (context, _) => MaterialApp(
          title: 'NoLook',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: switch (widget.app.state.settings.theme) {
            ThemeChoice.system => ThemeMode.system,
            ThemeChoice.light => ThemeMode.light,
            ThemeChoice.dark => ThemeMode.dark,
          },
          // first run: setup, then the shell
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: widget.app.state.settings.setupDone
                ? Shell(key: const ValueKey('shell'), app: widget.app)
                : SetupFlow(key: const ValueKey('setup'), app: widget.app),
          ),
          // status bar icon contrast
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
              child: child!,
            );
          },
        ),
      );
}

class _Tray with TrayListener {
  _Tray(this.app);

  final NoLook app;

  Future<void> setUp() async {
    final icon = Platform.isWindows
        ? '${File(Platform.resolvedExecutable).parent.path}\\data\\flutter_assets\\assets\\logo\\tray.ico'
        : 'assets/logo/tray.png';
    await trayManager.setIcon(icon);
    await trayManager.setToolTip('NoLook');
    trayManager.addListener(this);
    await _menu();
    app.addListener(_menuIfChanged);
  }

  bool? _guarded;

  bool get _cantQuit => app.state.settings.guard && app.anyLocked;

  Lang? _lang;

  void _menuIfChanged() {
    if (_guarded != _cantQuit || _lang != currentLang) _menu();
  }

  Future<void> _menu() async {
    _guarded = _cantQuit;
    _lang = currentLang;
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'open', label: tr('Open NoLook', 'NoLook\'u aç')),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: _cantQuit ? tr('Quit (not while a block is locked)', 'Çık (kilitli bir engel varken olmaz)') : tr('Quit NoLook', 'NoLook\'tan çık'), disabled: _cantQuit),
    ]));
  }

  @override
  void onTrayIconMouseDown() => app.showWindow?.call();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem item) async {
    if (item.key == 'open') app.showWindow?.call();
    if (item.key == 'quit' && !_cantQuit) {
      await trayManager.destroy();
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
      exit(0);
    }
  }
}
