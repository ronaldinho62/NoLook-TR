import 'block.dart';
import 'i18n.dart';

class UnlockSteps {
  const UnlockSteps({required this.wait, required this.type, required this.waitMinutes, required this.sentence});

  final bool wait;
  final bool type;
  final int waitMinutes;
  final String sentence;

  bool get none => !wait && !type;
}

enum UnlockResult { unlocked, waitNotOver, wrongSentence, noEmergencyLeft, notLocked }

class Unlocker {
  const Unlocker._();

  static String sentenceFor(Block b) => b.sentence.trim().isNotEmpty
      ? b.sentence.trim()
      : tr('I really want to turn off ${b.name} right now', 'Şu an gerçekten ${b.name} engelini kapatmak istiyorum');

  static UnlockSteps stepsFor(Block b) {
    final (wait, type) = switch (b.lock) {
      LockKind.none => (false, false),
      LockKind.wait => (true, false),
      LockKind.type => (false, true),
      LockKind.untilDate => switch (b.earlyUnlock) {
          EarlyUnlock.wait => (true, false),
          EarlyUnlock.type => (false, true),
          EarlyUnlock.both => (true, true),
        },
    };
    return UnlockSteps(wait: wait, type: type, waitMinutes: b.waitMinutes, sentence: sentenceFor(b));
  }

  /// ignores case, extra spaces, trailing full stop
  static bool sentenceMatches(String typed, String sentence) {
    String norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[.!]+$'), '').toLowerCase();
    return norm(typed) == norm(sentence) && norm(sentence).isNotEmpty;
  }

  static void startWait(Block b, DateTime now) => b.unlockStartedAt ??= now;

  static void cancelUnlock(Block b) => b.unlockStartedAt = null;

  static Duration? waitLeft(Block b, DateTime now) {
    final started = b.unlockStartedAt;
    if (started == null) return null;
    final left = started.add(Duration(minutes: b.waitMinutes)).difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  static bool waitOver(Block b, DateTime now) => waitLeft(b, now) == Duration.zero;

  static UnlockResult unlockEarly(Block b, DateTime now, {String typed = ''}) {
    if (!b.isLocked(now)) {
      turnOff(b, now);
      return UnlockResult.notLocked;
    }
    final steps = stepsFor(b);
    if (steps.wait && !waitOver(b, now)) return UnlockResult.waitNotOver;
    if (steps.type && !sentenceMatches(typed, steps.sentence)) return UnlockResult.wrongSentence;
    _release(b, now);
    return UnlockResult.unlocked;
  }

  /// null = unlimited
  static int? emergencyLeft(Block b, DateTime now) {
    final limit = b.emergencyPerMonth;
    if (limit == null) return null;
    final used = b.emergencyUses.where((d) => d.year == now.year && d.month == now.month).length;
    return (limit - used).clamp(0, limit);
  }

  static UnlockResult emergencyUnlock(Block b, DateTime now) {
    if (!b.isLocked(now)) {
      turnOff(b, now);
      return UnlockResult.notLocked;
    }
    final left = emergencyLeft(b, now);
    if (left != null && left <= 0) return UnlockResult.noEmergencyLeft;
    b.emergencyUses.add(now);
    // prune old ones
    b.emergencyUses.removeWhere((d) => d.year < now.year);
    _release(b, now);
    return UnlockResult.unlocked;
  }

  /// locked ones go through [unlockEarly]
  static bool turnOff(Block b, DateTime now) {
    if (b.isLocked(now)) return false;
    b.enabled = false;
    b.pausedUntil = null;
    b.unlockStartedAt = null;
    return true;
  }

  static void turnOn(Block b) {
    b.enabled = true;
    b.pausedUntil = null;
    b.unlockStartedAt = null;
  }

  static void _release(Block b, DateTime now) {
    b.unlockStartedAt = null;
    final relock = b.relockMinutes;
    if (relock != null) {
      b.pausedUntil = now.add(Duration(minutes: relock));
    } else {
      b.enabled = false;
    }
  }

  /// what an edit would weaken. locked blocks can only get stricter, empty = ok
  static List<String> problemsWithEdit(Block before, Block after, DateTime now) {
    if (!before.isLocked(now)) return const [];
    final problems = <String>[];
    bool removed(List<String> a, List<String> b) {
      final kept = {for (final s in b) s.toLowerCase()};
      return a.any((s) => !kept.contains(s.toLowerCase()));
    }

    if (removed(before.keywords, after.keywords)) problems.add(tr("Keywords can't be removed while it's locked.", 'Kilitliyken anahtar kelimeler kaldırılamaz.'));
    if (removed(before.spoilerWords, after.spoilerWords) || removed(before.topicWords, after.topicWords)) {
      problems.add(tr("Words can't be removed while it's locked.", 'Kilitliyken kelimeler kaldırılamaz.'));
    }
    if (removed(before.sites, after.sites)) problems.add(tr("Sites can't be removed while it's locked.", 'Kilitliyken siteler kaldırılamaz.'));
    if (removed([for (final a in before.apps) a.name], [for (final a in after.apps) a.name])) {
      problems.add(tr("Apps can't be removed while it's locked.", 'Kilitliyken uygulamalar kaldırılamaz.'));
    }
    if (after.lock != before.lock) problems.add(tr("The lock type can't change while it's locked.", 'Kilitliyken kilit türü değiştirilemez.'));
    if (before.lock == LockKind.untilDate &&
        (after.lockedUntil == null || after.lockedUntil!.isBefore(before.lockedUntil!))) {
      problems.add(tr("The date can only move later while it's locked.", 'Kilitliyken tarih yalnızca ileri alınabilir.'));
    }
    final s1 = stepsFor(before), s2 = stepsFor(after);
    if ((s1.wait && !s2.wait) || (s1.type && !s2.type)) problems.add(tr("Unlocking early can't get easier while it's locked.", 'Kilitliyken erken açma kolaylaştırılamaz.'));
    if (s1.wait && after.waitMinutes < before.waitMinutes) problems.add(tr("The wait can't get shorter while it's locked.", 'Kilitliyken bekleme kısaltılamaz.'));
    final e1 = before.emergencyPerMonth, e2 = after.emergencyPerMonth;
    if (e1 != null && (e2 == null || e2 > e1)) problems.add(tr("Emergency unlocks can't go up while it's locked.", 'Kilitliyken acil kilit açma sayısı artırılamaz.'));
    final r1 = before.relockMinutes, r2 = after.relockMinutes;
    if (r1 != null && (r2 == null || r2 > r1)) problems.add(tr("It can't stay off for longer while it's locked.", 'Kilitliyken daha uzun süre kapalı kalamaz.'));
    if (after.schedule != before.schedule) problems.add(tr("The schedule can't change while it's locked.", 'Kilitliyken zamanlama değiştirilemez.'));
    if (before.devices.isEmpty && after.devices.isNotEmpty ||
        before.devices.isNotEmpty && after.devices.isNotEmpty && !after.devices.toSet().containsAll(before.devices)) {
      problems.add(tr("Devices can't be taken off while it's locked.", 'Kilitliyken cihazlar çıkarılamaz.'));
    }
    if (before.matchMode == MatchMode.hide && after.matchMode == MatchMode.blur) {
      problems.add(tr("Matches can't go from hidden to blurred while it's locked.", 'Kilitliyken eşleşmeler gizliden bulanığa geçemez.'));
    }
    if (before.imageText && !after.imageText) problems.add(tr("Checking images can't be turned off while it's locked.", 'Kilitliyken görsel kontrolü kapatılamaz.'));
    return problems;
  }
}
