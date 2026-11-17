import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../controller.dart';
import '../platform/browser_link.dart';
import '../platform/os.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'devices.dart';

/// extension install steps, goes green once it connects
class ExtensionSetupPage extends StatefulWidget {
  const ExtensionSetupPage({super.key, required this.app, this.browser, this.embedded = false});

  final NoLook app;

  /// default: first installed + unconnected
  final String? browser;

  /// embedded in setup, no header
  final bool embedded;

  @override
  State<ExtensionSetupPage> createState() => _ExtensionSetupPageState();
}

class _ExtensionSetupPageState extends State<ExtensionSetupPage> {
  String? _browser;
  Map<String, String>? _installed;
  final _done = <String>{};

  /// "Other": 'chromium' or 'firefox'
  String? _otherKind;

  /// connected before open, to spot a new one
  late final Set<String> _seenBefore = widget.app.state.browsersSeen.keys.toSet();

  void _storesChanged() => setState(() {});

  @override
  void dispose() {
    storeLinks.removeListener(_storesChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    storeLinks.addListener(_storesChanged);
    loadStoreLinks();
    _browser = widget.browser;
    findBrowsers().then((found) {
      if (!mounted) return;
      setState(() {
        _installed = found;
        _browser ??= setupBrowsers.firstWhere(
          (b) => found.containsKey(b) && !browserStatus(widget.app, b).$2,
          orElse: () => setupBrowsers.firstWhere(found.containsKey, orElse: () => 'Chrome'),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.app, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final c = context.nl;
    final browser = _browser ?? 'Chrome';
    final other = browser == 'Other';
    final exe = _installed?[browser];
    final firefox = other ? _otherKind == 'firefox' : !isChromium(browser);
    final folder = extensionDir(firefox ? 'Firefox' : 'Chrome');
    final hasFolder = folder.existsSync();
    final (status, ok) = other
        ? ('', widget.app.state.browsersSeen.keys.any((b) => !_seenBefore.contains(b)))
        : browserStatus(widget.app, browser);
    final name = other ? tr('your browser', 'tarayıcın') : browser;
    final page = other ? (firefox ? extensionsPage('Firefox') : 'chrome://extensions') : extensionsPage(browser);
    final storePage = other
        ? (_otherKind == 'firefox' ? storeUrl('Firefox') : _otherKind == 'chromium' ? storeUrl('Chrome') : null)
        : storeUrl(browser);
    final store = storePage != null;
    final sep = Platform.pathSeparator;

    void mark(String step) => setState(() => _done.add('$browser/$step'));
    bool isDone(String step) => ok || _done.contains('$browser/$step');

    // chromium won't open chrome:// from outside, copy + open the browser instead
    Future<void> open(String address) async {
      await Clipboard.setData(ClipboardData(text: address));
      final direct = firefox || address.startsWith('http');
      final opened = exe != null && await openInBrowser(exe, direct ? address : null);
      if (context.mounted) {
        toast(
          context,
          opened && direct
              ? tr('Opening it in $browser', '$browser ile açılıyor')
              : tr('Copied $address, paste it into the address bar', '$address kopyalandı, adres çubuğuna yapıştır'),
        );
      }
      mark('open');
    }

    void showFolder() {
      // select it in explorer
      final target = firefox ? '${folder.path}${sep}manifest.json' : folder.path;
      if (Platform.isWindows) {
        Process.run('explorer', ['/select,', target]);
      } else if (Platform.isMacOS) {
        Process.run('open', ['-R', target]);
      } else {
        Process.run('xdg-open', [folder.path]);
      }
      mark('folder');
    }

    void copyPath() {
      Clipboard.setData(ClipboardData(text: folder.path));
      toast(context, tr('Copied, paste it into the folder picker', 'Kopyalandı, klasör seçiciye yapıştır'));
      mark('folder');
    }

    Btn openBtn(String address) => Btn(
          other || exe == null
              ? tr('Copy the address', 'Adresi kopyala')
              : firefox || address.startsWith('http')
              ? tr('Open in $browser', '$browser ile aç')
              : tr('Copy and open $browser', 'Kopyala ve $browser ile aç'),
          icon: other || exe == null ? Symbols.content_copy_rounded : Symbols.open_in_new_rounded,
          kind: BtnKind.tonal,
          onPressed: () => open(address),
        );
    final folderBtns = [
      Btn(tr('Show the folder', 'Klasörü göster'), icon: Symbols.folder_open_rounded, kind: BtnKind.outlined, onPressed: hasFolder ? showFolder : null),
      Btn(tr('Copy the path', 'Yolu kopyala'), icon: Symbols.content_copy_rounded, kind: BtnKind.text, onPressed: hasFolder ? copyPath : null),
    ];
    final pasteHint = tr('Paste it into the address bar, the button copies it for you', 'Adres çubuğuna yapıştır, düğme senin için kopyalar');

    final firefoxSteps = [
      _Step(
        tr('Go to $page', 'Şu sayfaya git: $page'),
        sub: other ? pasteHint : tr("If it doesn't open, paste it into the address bar, it's copied", 'Açılmazsa adres çubuğuna yapıştır, zaten kopyalandı'),
        done: isDone('open'),
        actions: [openBtn(page)],
      ),
      _Step(
        tr(
          'Click "Load Temporary Add-on" and pick manifest.json from the NoLook folder',
          '"Load Temporary Add-on" (Geçici Eklenti Yükle) düğmesine tıkla ve NoLook klasöründeki manifest.json dosyasını seç',
        ),
        sub: tr(
          'Firefox removes it when it closes, the store version that stays is on its way.',
          'Firefox kapanınca bunu kaldırır, kalıcı mağaza sürümü yolda.',
        ),
        done: isDone('folder'),
        actions: folderBtns,
      ),
    ];
    final chromiumSteps = [
      _Step(
        tr('Turn on "Developer mode"', '"Geliştirici modu"nu aç'),
        sub: browser == 'Edge'
            ? tr('In the menu on the left', 'Soldaki menüde')
            : other
            ? tr('Usually at the top right', 'Genelde sağ üstte')
            : tr('At the top right', 'Sağ üstte'),
        done: ok,
      ),
      _Step(
        tr('Drag the NoLook folder onto the page', 'NoLook klasörünü sayfanın üzerine sürükle'),
        sub: tr('Or click "Load unpacked" and pick it', 'Ya da "Paketlenmemiş öğe yükle" düğmesine tıklayıp klasörü seç'),
        done: isDone('folder'),
        actions: folderBtns,
      ),
    ];

    final storeSteps = [
      _Step(
        firefox
            ? tr('Open NoLook on Firefox Add-ons', 'NoLook\'u Firefox Eklentileri\'nde aç')
            : browser == 'Edge' && edgeHasOwnListing
            ? tr('Open NoLook on Edge Add-ons', 'NoLook\'u Edge Eklentileri\'nde aç')
            : tr('Open NoLook on the Chrome Web Store', 'NoLook\'u Chrome Web Mağazası\'nda aç'),
        sub: other ? pasteHint : null,
        done: isDone('open'),
        actions: [if (storePage != null) openBtn(storePage)],
      ),
      _Step(
        firefox
            ? tr('Click "Add to Firefox", then "Add"', '"Firefox\'a ekle" düğmesine, sonra "Ekle" düğmesine tıkla')
            : tr('Click "Get" or "Add to Chrome", then "Add extension"', '"Edinin" veya "Chrome\'a ekle" düğmesine, sonra "Uzantı ekle" düğmesine tıkla'),
      ),
    ];

    Btn choice(String label, String kind) => Btn(
          label,
          icon: _otherKind == kind ? Symbols.check_rounded : null,
          kind: _otherKind == kind ? BtnKind.tonal : BtnKind.outlined,
          onPressed: () => setState(() => _otherKind = kind),
        );

    final steps = <_Step>[
      if (other) ...[
        _Step(
          tr('Paste chrome://extensions into its address bar', 'Adres çubuğuna chrome://extensions yapıştır'),
          sub: tr(
            "This shows what it's built on. Most browsers are built on Chromium like Chrome and open an extensions page, ones built on Firefox don't.",
            'Bu, tarayıcının neye dayandığını gösterir. Çoğu tarayıcı Chrome gibi Chromium tabanlıdır ve bir eklenti sayfası açar, Firefox tabanlı olanlar açmaz.',
          ),
          done: _otherKind != null || ok,
          actions: [
            Btn(tr('Copy the address', 'Adresi kopyala'), icon: Symbols.content_copy_rounded, kind: BtnKind.tonal, onPressed: () => open('chrome://extensions')),
            choice(tr('A page opened', 'Bir sayfa açıldı'), 'chromium'),
            choice(tr('Nothing opened', 'Hiçbir şey açılmadı'), 'firefox'),
          ],
        ),
        if (store) ...storeSteps
        else if (_otherKind == 'chromium') ...chromiumSteps
        else if (_otherKind == 'firefox') ...firefoxSteps,
      ] else if (store)
        ...storeSteps
      else if (firefox)
        ...firefoxSteps
      else ...[
        _Step(tr('Go to $page', 'Şu sayfaya git: $page'), sub: pasteHint, done: isDone('open'), actions: [openBtn(page)]),
        ...chromiumSteps,
      ],
    ];

    final children = <Widget>[
      if (!widget.embedded) ...[
        PageBar(
          title: tr('Browser extension', 'Tarayıcı eklentisi'),
          leading: IconBtn(Symbols.arrow_back_rounded, tooltip: tr('Back', 'Geri'), onPressed: () => Navigator.pop(context)),
        ),
        Text(
          tr(
            'The extension blurs keywords and blocks sites. It gets your blocks from this app, so there is nothing to set up inside it.',
            'Eklenti anahtar kelimeleri bulanıklaştırır ve siteleri engeller. Engellerini bu uygulamadan alır, bu yüzden içinde ayarlanacak bir şey yok.',
          ),
          style: body(15, color: c.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 20),
      ],
      LayoutBuilder(
        builder: (context, box) {
          final cols = box.maxWidth < 520 ? 2 : 4;
          const gap = 10.0;
          final w = (box.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final b in setupBrowsers)
                SizedBox(
                  width: w,
                  child: _BrowserTile(
                    name: b == 'Other' ? tr('Other', 'Diğer') : b,
                    selected: b == browser,
                    status: b == 'Other'
                        ? (tr('Any other browser', 'Başka bir tarayıcı'), null, false)
                        : browserStatus(widget.app, b).$2
                        ? (tr('Connected', 'Bağlı'), Symbols.check_circle_rounded, true)
                        : _installed == null
                        ? ('', null, false)
                        : _installed!.containsKey(b)
                        ? (tr('Not added yet', 'Henüz eklenmedi'), null, false)
                        : (onWindows ? tr('Not on this PC', 'Bu bilgisayarda yok') : tr('Not on this computer', 'Bu bilgisayarda yok'), null, false),
                    onTap: () => setState(() => _browser = b),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: NlCard(
          key: ValueKey(browser),
          color: c.surfaceLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < steps.length; i++) _StepRow(n: i + 1, step: steps[i], last: i == steps.length - 1),
              // not listed yet
              if (!store && (firefox ? false : !other || _otherKind == 'chromium'))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    tr(
                      'NoLook is coming to the Chrome Web Store, until then it loads from the NoLook folder.',
                      'Türkçe eklenti mağazada yok, NoLook klasöründen yüklenir.',
                    ),
                    style: body(14, color: c.onSurfaceVariant, height: 1.45),
                  ),
                ),
              if (!hasFolder && !store)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    tr("This copy of NoLook doesn't have the extension next to it.", 'NoLook\'un bu kopyasının yanında eklenti yok.'),
                    style: body(14, color: c.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(color: ok ? c.tertiaryContainer : c.surfaceMid, borderRadius: BorderRadius.circular(context.isPhone ? 24 : 28)),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                child: child,
              ),
              child: ok
                  ? Ms(Symbols.check_circle_rounded, key: const ValueKey(true), color: c.onTertiaryContainer, fill: true)
                  : SizedBox(
                      key: const ValueKey(false),
                      width: 24,
                      height: 24,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: c.onSurfaceVariant),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                ok
                    ? (other
                        ? tr("Your browser is connected, you're all set.", 'Tarayıcın bağlandı, her şey hazır.')
                        : tr("$browser is connected, you're all set.", '$browser bağlandı, her şey hazır.'))
                    : other || !widget.app.state.browsersSeen.containsKey(browser == 'Opera GX' ? 'Opera' : browser)
                    ? tr('Waiting for $name to connect, this updates by itself.', '$name bağlantısı bekleniyor, bu kendiliğinden güncellenir.')
                    : '$browser: $status.',
                style: body(15, color: ok ? c.onTertiaryContainer : c.onSurface),
              ),
            ),
          ],
        ),
      ),
      if (!hostExe.existsSync())
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            tr(
              "NoLook's browser helper (nolook_host.exe) is missing from this copy, so the extension can't connect.",
              'NoLook\'un tarayıcı yardımcısı (nolook_host.exe) bu kopyada eksik, bu yüzden eklenti bağlanamıyor.',
            ),
            style: body(14, color: c.error),
          ),
        ),
    ];
    if (widget.embedded) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    return NlPage(children: children);
  }
}

class _Step {
  const _Step(this.title, {this.sub, this.done = false, this.actions = const []});

  final String title;
  final String? sub;
  final bool done;
  final List<Widget> actions;
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.n, required this.step, required this.last});

  final int n;
  final _Step step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: step.done ? c.primary : c.secondaryContainer, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: step.done
                  ? Ms(Symbols.check_rounded, key: const ValueKey(true), size: 18, color: c.onPrimary)
                  : Text(
                      '$n',
                      key: const ValueKey(false),
                      style: body(14, weight: FontWeight.w600, color: c.onSecondaryContainer),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: body(16, weight: FontWeight.w500, color: c.onSurface),
                  ),
                  if (step.sub != null) ...[const SizedBox(height: 2), Text(step.sub!, style: body(14, color: c.onSurfaceVariant))],
                  if (step.actions.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: step.actions)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowserTile extends StatelessWidget {
  const _BrowserTile({required this.name, required this.selected, required this.status, required this.onTap});

  final String name;
  final bool selected;
  final (String, IconData?, bool) status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final (text, icon, ok) = status;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(color: selected ? c.secondaryContainer : c.surfaceLow, borderRadius: BorderRadius.circular(20)),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: body(17, weight: FontWeight.w600, color: selected ? c.onSecondaryContainer : c.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text.isEmpty ? ' ' : text,
                        style: body(13, color: ok ? c.primary : (selected ? c.onSecondaryContainer : c.onSurfaceVariant)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (icon != null) Ms(icon, size: 22, color: c.primary, fill: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
