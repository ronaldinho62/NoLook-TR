import 'block.dart';
import 'i18n.dart';
import 'state.dart';
import 'unlock.dart';

/// shared block text for the app, helper and extension
class Describe {
  const Describe._();

  static const monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const monthsTr = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  static String month(int m) => isTr ? monthsTr[m - 1] : monthsEn[m - 1];

  /// year only if not this year
  static String day(DateTime d, DateTime now) {
    return d.year == now.year ? '${d.day} ${month(d.month)}' : '${d.day} ${month(d.month)} ${d.year}';
  }

  /// "until" form
  static String until(DateTime d, DateTime now) {
    if (!isTr) return day(d, now);
    return '${day(d, now)} tarihine kadar';
  }

  static String time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Türkçede bulunma ekiyle saat: "14:30'da", "13:00'te". İngilizcede sadece saat.
  static String at(DateTime d) {
    final t = time(d);
    if (!isTr) return t;
    return "$t'${_locative(d.minute == 0 ? d.hour : d.minute)}";
  }

  static String _locative(int n) {
    const units = ['sıfır', 'bir', 'iki', 'üç', 'dört', 'beş', 'altı', 'yedi', 'sekiz', 'dokuz'];
    const tens = ['', 'on', 'yirmi', 'otuz', 'kırk', 'elli'];
    final word = n == 0 ? units[0] : n % 10 != 0 ? units[n % 10] : tens[n ~/ 10];
    final hard = 'çfhkpsşt'.contains(word[word.length - 1]);
    final vowel = word.split('').lastWhere((c) => 'aeıioöuü'.contains(c));
    final back = 'aıou'.contains(vowel);
    return '${hard ? 't' : 'd'}${back ? 'a' : 'e'}';
  }

  static String minutes(int m) {
    if (m < 60) return tr('$m min', '$m dk');
    if (m % 60 == 0) return tr(m == 60 ? '1 hour' : '${m ~/ 60} hours', '${m ~/ 60} saat');
    return tr('${m ~/ 60} h ${m % 60} min', '${m ~/ 60} sa ${m % 60} dk');
  }

  /// "24 keywords, 9 sites", or "Empty".
  static String contents(Block b) {
    final parts = <String>[];
    void add(int n, String one, String many, String turkce) {
      if (n > 0) parts.add(tr('$n ${n == 1 ? one : many}', '$n $turkce'));
    }

    add(b.wordCount, 'keyword', 'keywords', 'anahtar kelime');
    add(b.sites.length, 'site', 'sites', 'site');
    add(b.apps.length, 'app', 'apps', 'uygulama');
    return parts.isEmpty ? tr('Empty', 'Boş') : parts.join(', ');
  }

  /// (before, bold, after)
  static (String, String, String) lockLineParts(Block b, DateTime now) {
    if (b.isPaused(now)) {
      return isTr ? ('Erken açıldı, saat ', at(b.pausedUntil!), ' yeniden açılır') : ('Unlocked early, back on at ', time(b.pausedUntil!), '');
    }
    if (!b.enabled) return (tr('Off', 'Kapalı'), '', '');
    if (b.isLocked(now) && b.lock == LockKind.untilDate) {
      return (tr('Locked until ', 'Kilitli: '), until(b.lockedUntil!, now), '');
    }
    if (!b.schedule.always && !b.schedule.contains(now)) {
      final next = b.schedule.nextStart(now);
      if (next != null) {
        final unlock = switch (b.lock) {
          LockKind.wait => tr(', ${minutes(b.waitMinutes)} wait to unlock', ', ${minutes(b.waitMinutes)} beklemeyle açılır'),
          LockKind.type => tr(', type to unlock', ', yazarak açılır'),
          _ => '',
        };
        return isTr ? ('Saat ', at(next), ' açılır$unlock') : ('Turns on at ', time(next), unlock);
      }
    }
    final line = switch (b.lock) {
      LockKind.none => tr('No lock', 'Kilit yok'),
      LockKind.untilDate =>
        tr('Lock ended ${day(b.lockedUntil ?? now, now)}', 'Kilit bitti: ${day(b.lockedUntil ?? now, now)}'),
      LockKind.wait =>
        tr('${minutes(b.waitMinutes)} wait to unlock early', 'Erken açmak için ${minutes(b.waitMinutes)} bekleme'),
      LockKind.type => tr('Type a sentence to unlock early', 'Erken açmak için bir cümle yaz'),
    };
    return (line, '', '');
  }

  static String lockLine(Block b, DateTime now) {
    final (a, bold, c) = lockLineParts(b, now);
    return '$a$bold$c';
  }

  /// "Wait 30 min, then type a sentence".
  static String unlockSteps(Block b) {
    final s = Unlocker.stepsFor(b);
    final m = minutes(s.waitMinutes);
    if (s.wait && s.type) return tr('Wait $m, then type a sentence', '$m bekle, sonra bir cümle yaz');
    if (s.wait) return tr('Wait $m', '$m bekle');
    if (s.type) return tr('Type a sentence', 'Bir cümle yaz');
    return tr('Nothing, turn it off any time', 'Hiçbir şey, istediğin zaman kapat');
  }

  static String relock(Block b) => b.relockMinutes == null
      ? tr('Stays off until you turn it on', 'Sen açana kadar kapalı kalır')
      : tr('Turns back on after ${minutes(b.relockMinutes!)}', '${minutes(b.relockMinutes!)} sonra yeniden açılır');

  static String emergency(Block b, DateTime now) {
    final limit = b.emergencyPerMonth;
    if (limit == null) return tr('No limit', 'Sınırsız');
    if (limit == 0) return tr('None', 'Yok');
    final left = Unlocker.emergencyLeft(b, now)!;
    return tr('$limit a month, $left left in ${month(now.month)}', 'Ayda $limit, ${month(now.month)} ayında $left kaldı');
  }

  static String summary(Block b) {
    final when = b.schedule.always
        ? tr('Always on', 'Her zaman açık')
        : tr('On ${b.schedule.describe()}', 'Açık: ${b.schedule.describe()}');
    final s = Unlocker.stepsFor(b);
    final m = minutes(s.waitMinutes);
    final how = switch ((s.wait, s.type)) {
      (true, true) => tr('to unlock early you wait $m and type a sentence', 'erken açmak için $m bekleyip bir cümle yazarsın'),
      (true, false) => tr('to unlock early you wait $m', 'erken açmak için $m beklersin'),
      (false, true) => tr('to unlock early you type a sentence', 'erken açmak için bir cümle yazarsın'),
      _ => tr('turn it off any time', 'istediğin zaman kapatabilirsin'),
    };
    return '$when, $how.';
  }
}

/// sent to the extension
class BrowserRules {
  const BrowserRules._();

  static Map<String, Object?> build(NoLookState state, DateTime now, {String? deviceId}) => {
        'type': 'rules',
        'at': now.toIso8601String(),
        'settings': {
          'blurStrength': state.settings.blurStrength.name,
          'twoClickReveal': state.settings.twoClickReveal,
          'sayKeyword': state.settings.sayKeyword,
          'lang': currentLang.name,
          'language': state.settings.language.name,
        },
        'blocks': [
          for (final b in state.blocks)
            if (deviceId == null || b.runsOn(deviceId))
              {
                'id': b.id,
                'name': b.name,
                'color': b.color.name,
                'iconText': b.iconText,
                'iconName': b.iconName,
                'on': b.isOn(now),
                'active': b.isActive(now),
                'locked': b.isLocked(now),
                'lockLine': Describe.lockLine(b, now),
                'lockBold': Describe.lockLineParts(b, now).$2,
                'keywords': b.keywords,
                'spoilerWords': b.spoilerWords,
                'topicWords': b.topicWords,
                'sites': b.sites,
                // the extension ignores apps
                'apps': [for (final a in b.apps) a.toJson()],
                'matchMode': b.matchMode.name,
              },
        ],
      };
}
