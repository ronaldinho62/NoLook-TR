import 'dart:io';

import '../platform/os.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../platform/android_link.dart';
import '../platform/updates.dart';
import '../screens/settings.dart';
import '../theme.dart';
import 'common.dart';

/// update banner
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  double? _progress;
  var _failed = false;

  Future<void> _update(Update u) async {
    if (!Platform.isWindows && !Platform.isAndroid) {
      openUrl(u.url);
      return;
    }
    setState(() {
      _progress = 0;
      _failed = false;
    });
    if (Platform.isAndroid) {
      // android prompts by itself
      void onProgress() => mounted ? setState(() => _progress = AndroidLink.updateProgress.value ?? 0) : null;
      AndroidLink.updateProgress.addListener(onProgress);
      final error = await AndroidLink.installUpdate(u.url);
      AndroidLink.updateProgress.removeListener(onProgress);
      if (!mounted) return;
      setState(() {
        _progress = null;
        _failed = error != null;
      });
      return;
    }
    final ok = await installWindowsUpdate(u, progress: (p) => mounted ? setState(() => _progress = p) : null);
    if (!mounted) return;
    if (ok) {
      // the script restarts us
      exit(0);
    }
    setState(() {
      _progress = null;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Update?>(
        future: checkForUpdate(current: appVersion, repo: repoUrl),
        builder: (context, snap) {
          final u = snap.data;
          if (u == null) return const SizedBox.shrink();
          final c = context.nl;
          final busy = _progress != null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                Ms(Symbols.download_rounded, color: c.onPrimaryContainer),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('NoLook ${u.version} is out', 'NoLook ${u.version} çıktı'), style: body(16, weight: FontWeight.w600, color: c.onPrimaryContainer)),
                    const SizedBox(height: 2),
                    Text(
                      _failed
                          ? tr("Couldn't update, try again or download it from GitHub", 'Güncellenemedi, tekrar dene ya da GitHub\'dan indir')
                          : busy
                              ? (onAndroid ? tr('Downloading, then Android asks to update', 'İndiriliyor, sonra Android güncellemeyi soracak') : tr('Downloading, NoLook restarts by itself', 'İndiriliyor, NoLook kendiliğinden yeniden başlayacak'))
                              : tr('Your blocks stay as they are', 'Engellerin olduğu gibi kalır'),
                      style: body(14, color: c.onPrimaryContainer),
                    ),
                    if (busy) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _progress, borderRadius: BorderRadius.circular(4)),
                    ],
                  ]),
                ),
                const SizedBox(width: 12),
                Btn(tr('Update', 'Güncelle'), onPressed: busy ? null : () => _update(u)),
              ]),
            ),
          );
        },
      );
}
