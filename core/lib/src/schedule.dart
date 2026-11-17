import 'i18n.dart';

/// always, or days + a time range.
///
/// minutes after midnight, end < start = overnight (counts as the start day)
class Schedule {
  const Schedule.always()
      : always = true,
        days = const {1, 2, 3, 4, 5, 6, 7},
        start = 0,
        end = 0;

  const Schedule.on({required this.days, required this.start, required this.end}) : always = false;

  final bool always;

  /// 1 = mon, same as [DateTime.weekday]
  final Set<int> days;
  final int start;
  final int end;

  bool get overnight => !always && end <= start;

  bool contains(DateTime now) {
    if (always) return true;
    if (days.isEmpty) return false;
    final minute = now.hour * 60 + now.minute;
    if (!overnight) return days.contains(now.weekday) && minute >= start && minute < end;
    if (minute >= start) return days.contains(now.weekday);
    final yesterday = now.weekday == 1 ? 7 : now.weekday - 1;
    return minute < end && days.contains(yesterday);
  }

  /// null if always/never
  DateTime? nextStart(DateTime now) {
    if (always || days.isEmpty) return null;
    for (var i = 0; i <= 7; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      if (!days.contains(day.weekday)) continue;
      final at = day.add(Duration(minutes: start));
      if (at.isAfter(now)) return at;
    }
    return null;
  }

  Map<String, Object?> toJson() =>
      always ? {'always': true} : {'always': false, 'days': days.toList()..sort(), 'start': start, 'end': end};

  factory Schedule.fromJson(Map<String, Object?>? json) {
    if (json == null || json['always'] != false) return const Schedule.always();
    return Schedule.on(
      days: {for (final d in (json['days'] as List? ?? const [])) (d as num).toInt()},
      start: (json['start'] as num? ?? 0).toInt(),
      end: (json['end'] as num? ?? 0).toInt(),
    );
  }

  /// Short text like "Every day, 23:00 - 07:00" or "Mon - Fri, 9:00 - 17:00".
  String describe() {
    if (always) return tr('Always', 'Her zaman');
    return '${describeDays(days)}, ${clock(start)} - ${clock(end)}';
  }

  static String clock(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static const _shortEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _shortTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  static List<String> get dayLetters => isTr ? const ['Pt', 'S', 'Ç', 'P', 'C', 'Ct', 'Pz'] : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  static String describeDays(Set<int> days) {
    final short = isTr ? _shortTr : _shortEn;
    final sorted = days.toList()..sort();
    if (sorted.length == 7) return tr('Every day', 'Her gün');
    if (sorted.isEmpty) return tr('No days', 'Hiçbir gün');
    if (sorted.join() == '12345') return tr('Mon - Fri', 'Pzt - Cum');
    if (sorted.join() == '67') return tr('Weekends', 'Hafta sonları');
    final contiguous = sorted.last - sorted.first == sorted.length - 1;
    if (contiguous && sorted.length > 2) return '${short[sorted.first - 1]} - ${short[sorted.last - 1]}';
    return sorted.map((d) => short[d - 1]).join(', ');
  }

  @override
  bool operator ==(Object other) =>
      other is Schedule &&
      other.always == always &&
      other.start == start &&
      other.end == end &&
      other.days.length == days.length &&
      other.days.containsAll(days);

  @override
  int get hashCode => Object.hash(always, start, end, Object.hashAllUnordered(days));
}
