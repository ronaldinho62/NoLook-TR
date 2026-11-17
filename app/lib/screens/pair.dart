import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nolook_core/nolook_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../controller.dart';
import '../platform/os.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/events.dart';
import 'devices.dart';
import 'unlock.dart';

/// wifi pairing: QR or 6 digit code
class PairPage extends StatefulWidget {
  const PairPage({super.key, required this.app});

  final NoLook app;

  @override
  State<PairPage> createState() => _PairPageState();
}

class _PairPageState extends State<PairPage> {
  StreamSubscription<void>? _sub;
  Timer? _clock;
  Future<String>? _qr;
  String? _justPaired;

  NoLook get app => widget.app;
  NoLookLink? get link => app.link;

  @override
  void initState() {
    super.initState();
    final l = link;
    if (l != null) {
      // pc shows the code right away, phones on demand
      if (!onMobile) _newCode();
      final before = app.state.paired.length;
      _sub = l.updates.stream.listen((_) {
        if (!mounted) return;
        if (app.state.paired.length > before && _justPaired == null) _justPaired = app.state.paired.last.name;
        setState(() {});
      });
    }
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _clock?.cancel();
    link?.closePairing();
    super.dispose();
  }

  void _newCode() {
    link!.openPairing();
    _qr = link!.qrText();
    setState(() {});
  }

  Future<void> _pair(List<String> hosts, int port, String code) async {
    try {
      final d = await link!.pairWith(hosts, port, code);
      if (!mounted) return;
      setState(() => _justPaired = d.name);
    } on PairingFailed catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(e.reason == 'code'
            ? tr("That code didn't work, check it or make a new one on the other device.", 'Bu kod çalışmadı, kontrol et ya da diğer cihazda yeni bir kod oluştur.')
            : tr("Couldn't reach it, check both devices are on the same Wi-Fi and NoLook is open on the other one.",
                'Ulaşılamadı, iki cihazın da aynı Wi-Fi ağında olduğunu ve diğerinde NoLook\'un açık olduğunu kontrol et.')),
      ));
    }
  }

  Future<void> _scan() async {
    final text = await Navigator.of(context, rootNavigator: true).push<String>(MaterialPageRoute(builder: (_) => const _Scanner()));
    if (text == null || !mounted) return;
    final qr = NoLookLink.parseQr(text);
    if (qr == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(tr("That isn't a NoLook pairing code.", 'Bu bir NoLook eşleştirme kodu değil.')),
      ));
      return;
    }
    await _pair(qr.hosts, qr.port, qr.code);
  }

  Future<void> _typeCode(NearbyDevice d) async {
    final code = await showNlDialog<String>(context, (ctx) => _CodeDialog(name: d.name));
    if (code != null) await _pair([d.host], d.port, code);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final l = link;
    final paired = app.state.paired;
    final nearby = l == null ? <NearbyDevice>[] : l.nearby.values.where((n) => !paired.any((p) => p.id == n.id)).toList();

    return NlPage(children: [
      PageBar(
        title: tr('Pair a device', 'Cihaz eşleştir'),
        leading: IconBtn(Symbols.arrow_back_rounded, tooltip: tr('Back', 'Geri'), onPressed: () => Navigator.pop(context)),
      ),
      if (_justPaired != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NlCard(
            color: c.tertiaryContainer,
            child: Row(children: [
              Ms(Symbols.check_circle_rounded, color: c.onTertiaryContainer, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(tr('Paired with $_justPaired, your blocks are the same on both now', '$_justPaired ile eşleşti, engellerin artık iki cihazda da aynı'),
                    style: body(16, weight: FontWeight.w600, color: c.onTertiaryContainer)),
              ),
            ]),
          ),
        ),
      if (l == null)
        NlCard(color: c.surfaceLow, child: Text(tr('Pairing starts with the app.', 'Eşleştirme uygulamayla başlar.'), style: body(15, color: c.onSurfaceVariant)))
      else ...[
        if (onMobile) ...[
          _ScanCard(onScan: _scan),
          const SizedBox(height: 12),
          if (nearby.isNotEmpty) ...[
            NlCard(
              color: c.surfaceLow,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CardLabel(tr('Nearby', 'Yakındakiler')),
                for (final d in nearby)
                  NlRow(
                    icon: d.os == 'Android' ? Symbols.smartphone_rounded : Symbols.desktop_windows_rounded,
                    title: d.name,
                    subtitle: d.pairing ? tr('Showing a code', 'Kod gösteriyor') : tr('Open Pair a device on it to get a code', 'Kod almak için o cihazda Cihaz eşleştir sayfasını aç'),
                    end: Btn(tr('Type code', 'Kodu yaz'), kind: BtnKind.text, onPressed: () => _typeCode(d)),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
          ],
        ],
        _ShowCode(
          offer: l.offer,
          qr: _qr,
          collapsed: onMobile && l.offer == null,
          onNew: _newCode,
        ),
      ],
      if (paired.isNotEmpty) ...[
        const SizedBox(height: 12),
        NlCard(
          color: c.surfaceLow,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CardLabel(tr('Paired devices', 'Eşleşen cihazlar')),
            for (final p in paired)
              NlRow(
                icon: p.os == 'Android' ? Symbols.smartphone_rounded : Symbols.desktop_windows_rounded,
                title: p.name,
                subtitle: syncLine(p, l, app.now),
                end: Btn(tr('Unpair', 'Eşleşmeyi kaldır'), kind: BtnKind.text, onPressed: () => l?.unpair(p.id)),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      NlCard(
        color: c.surfaceLow,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CardLabel(tr('Different Wi-Fi?', 'Farklı Wi-Fi mı?')),
          Text(tr('Move your blocks with a .nolook file instead.', 'Engellerini bunun yerine bir .nolook dosyasıyla taşı.'), style: body(15, color: c.onSurfaceVariant)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Btn(tr('Export blocks', 'Engelleri dışa aktar'), icon: Symbols.upload_rounded, kind: BtnKind.outlined, onPressed: app.state.blocks.isEmpty ? null : () => exportBlocks(context, app)),
            Btn(tr('Import blocks', 'Engelleri içe aktar'), icon: Symbols.download_rounded, kind: BtnKind.outlined, onPressed: () => importBlocks(context, app)),
          ]),
        ]),
      ),
    ]);
  }
}

String syncLine(PairedDevice p, NoLookLink? link, DateTime now) {
  final synced = link?.lastSync[p.id] ?? p.lastSeen;
  if (synced == null) return tr('Paired, waiting to sync', 'Eşleşti, eşitleme bekleniyor');
  final when = ago(synced, now);
  return when == tr('now', 'şimdi') ? tr('Synced just now', 'Az önce eşitlendi') : tr('Synced $when ago', '$when önce eşitlendi');
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    return NlCard(
      color: c.primaryContainer,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Ms(Symbols.qr_code_scanner_rounded, size: 36, color: c.onPrimaryContainer),
        const SizedBox(height: 12),
        Text(tr('Scan the code on your PC', 'Bilgisayarındaki kodu okut'), style: body(22, weight: FontWeight.w600, color: c.onPrimaryContainer)),
        const SizedBox(height: 6),
        Text(tr('On your PC, open NoLook and go to Devices, Pair a device, with both on the same Wi-Fi.',
                'Bilgisayarında NoLook\'u aç, Cihazlar > Cihaz eşleştir bölümüne git, iki cihaz da aynı Wi-Fi ağında olsun.'),
            style: body(15, color: c.onPrimaryContainer, height: 1.5)),
        const SizedBox(height: 16),
        Btn(tr('Scan QR code', 'QR kodu okut'), icon: Symbols.photo_camera_rounded, onPressed: onScan),
      ]),
    );
  }
}

class _ShowCode extends StatelessWidget {
  const _ShowCode({required this.offer, required this.qr, required this.collapsed, required this.onNew});

  final PairOffer? offer;
  final Future<String>? qr;
  final bool collapsed;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final phone = context.isPhone;
    if (collapsed) {
      return NlCard(
        color: c.surfaceLow,
        child: NlRow(
          icon: Symbols.qr_code_2_rounded,
          title: tr('Show a code on this phone', 'Bu telefonda bir kod göster'),
          subtitle: tr('To pair another phone with this one', 'Başka bir telefonu bununla eşleştirmek için'),
          end: Btn(tr('Show', 'Göster'), kind: BtnKind.text, onPressed: onNew),
        ),
      );
    }
    final o = offer;
    final left = o == null ? Duration.zero : o.expires.difference(DateTime.now());
    final expired = o == null || left.isNegative;
    final code = o?.code ?? '';
    final pretty = code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;

    final qrBox = Container(
      width: 220,
      height: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: expired || qr == null
          ? Center(child: Ms(Symbols.qr_code_2_rounded, size: 64, color: c.outline))
          : FutureBuilder<String>(
              future: qr,
              builder: (context, snap) => snap.hasData
                  ? QrImageView(
                      data: snap.data!,
                      padding: EdgeInsets.zero,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF001C3B)),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF001C3B)),
                    )
                  : const SizedBox(),
            ),
    );

    final text = Column(crossAxisAlignment: phone ? CrossAxisAlignment.center : CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(onMobile ? tr('Scan this with the other phone', 'Bunu diğer telefonla okut') : tr('Scan this with NoLook on your phone', 'Bunu telefonundaki NoLook ile okut'),
          textAlign: phone ? TextAlign.center : TextAlign.start, style: body(22, weight: FontWeight.w600, color: c.onSurface)),
      const SizedBox(height: 6),
      Text(
          tr('In NoLook on your phone, go to Devices, Pair a device, Scan QR code, with both on the same Wi-Fi.',
              'Telefonundaki NoLook\'ta Cihazlar > Cihaz eşleştir > QR kodu okut bölümüne git, iki cihaz da aynı Wi-Fi ağında olsun.'),
          textAlign: phone ? TextAlign.center : TextAlign.start,
          style: body(15, color: c.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 18),
      Text(tr("Can't scan? Pick this device under Nearby on the phone and type", 'Okutamıyor musun? Telefonda Yakındakiler altından bu cihazı seç ve şunu yaz'),
          textAlign: phone ? TextAlign.center : TextAlign.start, style: body(14, color: c.onSurfaceVariant)),
      const SizedBox(height: 6),
      Text(expired ? '--- ---' : pretty, style: display(40, color: c.onSurface).copyWith(letterSpacing: 4)),
      const SizedBox(height: 10),
      if (expired)
        Btn(tr('Make a new code', 'Yeni kod oluştur'), icon: Symbols.refresh_rounded, kind: BtnKind.tonal, onPressed: onNew)
      else
        Text(tr('Works for ${left.inMinutes + 1} more min, once', '${left.inMinutes + 1} dakika daha geçerli, tek kullanımlık'), style: body(13, color: c.onSurfaceVariant)),
    ]);

    return NlCard(
      color: c.surfaceLow,
      child: phone
          ? Column(children: [qrBox, const SizedBox(height: 20), text])
          : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [qrBox, const SizedBox(width: 32), Expanded(child: text)]),
    );
  }
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog({required this.name});

  final String name;

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final ok = _code.text.length == 6;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('Pair with ${widget.name}', '${widget.name} ile eşleştir'), style: body(24, weight: FontWeight.w500, color: c.onSurface)),
      const SizedBox(height: 6),
      Text(tr('Type the 6-digit code it shows under Pair a device.', 'Cihaz eşleştir altında gösterdiği 6 haneli kodu yaz.'), style: body(15, color: c.onSurfaceVariant, height: 1.5)),
      const SizedBox(height: 16),
      NlField(
        label: tr('Code', 'Kod'),
        controller: _code,
        autofocus: true,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => ok ? Navigator.pop(context, _code.text) : null,
      ),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Btn(tr('Cancel', 'İptal'), kind: BtnKind.text, onPressed: () => Navigator.pop(context)),
        const SizedBox(width: 8),
        Btn(tr('Pair', 'Eşleştir'), icon: Symbols.link_rounded, onPressed: ok ? () => Navigator.pop(context, _code.text) : null),
      ]),
    ]);
  }
}

/// qr scanner
class _Scanner extends StatefulWidget {
  const _Scanner();

  @override
  State<_Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<_Scanner> {
  final _camera = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  var _done = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        MobileScanner(
          controller: _camera,
          onDetect: (capture) {
            final text = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
            if (text == null || _done) return;
            _done = true;
            Navigator.pop(context, text);
          },
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                tr("NoLook can't use the camera, allow it in Android's settings or pick the PC under Nearby and type its code.",
                    'NoLook kamerayı kullanamıyor, Android ayarlarından izin ver ya da Yakındakiler altından bilgisayarı seçip kodunu yaz.'),
                textAlign: TextAlign.center,
                style: body(16, color: Colors.white, height: 1.5),
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(28)),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 8),
              Text(tr('Point at the code on your PC', 'Kameranı bilgisayarındaki koda tut'), style: body(17, weight: FontWeight.w500, color: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }
}
