import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nolook_core/nolook_core.dart';

import '../controller.dart';
import '../theme.dart';
import '../widgets/block_card.dart';
import '../widgets/common.dart';
import 'unlock.dart';

/// shown after closing a blocked app
Future<void> showAppBlocked(BuildContext context, NoLook app, BlockedAppNotice notice) => showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, _) => _AppBlocked(app: app, notice: notice),
      transitionBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    );

class _AppBlocked extends StatelessWidget {
  const _AppBlocked({required this.app, required this.notice});

  final NoLook app;
  final BlockedAppNotice notice;

  @override
  Widget build(BuildContext context) {
    final c = context.nl;
    final b = notice.block;
    final now = app.now;
    final (bg, fg) = c.block(b.color);
    final lockLine = b.isLocked(now) && b.lock == LockKind.untilDate
        ? tr('${b.name} is locked until ${Describe.day(b.lockedUntil!, now)}', '${b.name} engeli ${Describe.until(b.lockedUntil!, now)} kilitli')
        : tr('${b.name} is on', '${b.name} engeli açık');
    final times = notice.timesToday;
    return Material(
      color: c.surface,
      child: Stack(children: [
        Positioned(right: -120, top: -140, child: Blob(size: 420, color: bg.withValues(alpha: .6))),
        Positioned(left: -160, bottom: -200, child: Blob(size: 460, color: c.surfaceLow, radii: const [.58, .42, .40, .60, .55, .45, .55, .45])),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
                  alignment: Alignment.center,
                  child: BlockIcon(b, size: 56, color: fg),
                ),
                const SizedBox(height: 24),
                Text(tr('${notice.appName} is blocked', '${notice.appName} engellendi'),
                    textAlign: TextAlign.center, style: display(context.isPhone ? 30 : 38, color: c.onSurface, height: 1.1)),
                const SizedBox(height: 14),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Ms(Symbols.lock_rounded, size: 20, color: c.onSurfaceVariant, fill: true),
                  const SizedBox(width: 8),
                  Flexible(child: Text(lockLine, style: body(16, color: c.onSurfaceVariant))),
                ]),
                const SizedBox(height: 6),
                Text(
                    notice.site
                        ? (times <= 1 ? tr('NoLook sent your browser back', 'NoLook tarayıcını geri gönderdi') : tr("You've tried it $times times today", 'Bugün $times kez denedin'))
                        : (times <= 1 ? tr('NoLook closed it', 'NoLook onu kapattı') : tr("You've opened it $times times today", 'Bugün $times kez açtın')),
                    style: body(15, color: c.onSurfaceVariant)),
                const SizedBox(height: 32),
                Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                  Btn(tr('OK', 'Tamam'), big: true, onPressed: () => Navigator.pop(context)),
                  if (b.isLocked(now))
                    Btn(tr('Unlock early', 'Kilidi erken aç'), kind: BtnKind.text, big: true, onPressed: () {
                      final nav = Navigator.of(context);
                      nav.pop();
                      showUnlock(nav.context, app, b);
                    }),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
