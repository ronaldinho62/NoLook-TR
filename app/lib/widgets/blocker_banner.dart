import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../platform/android_link.dart';
import '../platform/os.dart';
import '../theme.dart';
import 'common.dart';

/// android: blocker off banner
class BlockerBanner extends StatefulWidget {
  const BlockerBanner({super.key});

  @override
  State<BlockerBanner> createState() => _BlockerBannerState();
}

class _BlockerBannerState extends State<BlockerBanner> {
  @override
  void initState() {
    super.initState();
    if (!onAndroid) return;
    // ask for notifications after home is up
    Timer(const Duration(seconds: 1), AndroidLink.askNotifications);
  }

  @override
  Widget build(BuildContext context) {
    if (!onAndroid) return const SizedBox.shrink();
    return ValueListenableBuilder<bool?>(
      valueListenable: AndroidLink.blocker,
      builder: (context, on, _) {
        if (on != false) return const SizedBox.shrink();
        final c = context.nl;
        final phone = context.isPhone;
        final button = Btn(tr('Turn on', 'Aç'), onPressed: AndroidLink.openBlockerSettings);
        final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('The blocker is off', 'Engelleyici kapalı'), style: body(16, weight: FontWeight.w600, color: c.onPeachContainer)),
          const SizedBox(height: 2),
          Text(
            tr("Nothing gets blocked or covered on this phone until it's on in Accessibility settings.",
                'Erişilebilirlik ayarlarından açılana kadar bu telefonda hiçbir şey engellenmez veya örtülmez.'),
            style: body(14, color: c.onPeachContainer),
          ),
        ]);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: BoxDecoration(color: c.peachContainer, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Ms(Symbols.shield_rounded, color: c.onPeachContainer),
                const SizedBox(width: 14),
                Expanded(child: text),
                if (!phone) ...[const SizedBox(width: 12), button],
              ]),
              if (phone) ...[const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: button)],
            ]),
          ),
        );
      },
    );
  }
}
