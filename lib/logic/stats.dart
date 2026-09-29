import 'dart:math' as math;

import 'commands.dart';
import 'dates.dart';

/// cal 화면과 위젯에 필요한 숫자들.
class DiaryStats {
  DiaryStats._({
    required this.total,
    required this.streak,
    required this.bestStreak,
    required this.writtenToday,
    required this.monthCount,
    required this.monthDays,
    required this.avgLength,
    required this.byMonth,
  });

  /// 전체 줄 수.
  final int total;

  /// 오늘(아직 안 썼으면 어제)까지 하루도 빠짐없이 쓴 날 수.
  final int streak;
  final int bestStreak;
  final bool writtenToday;

  /// 이번 달 쓴 날 / 이번 달 오늘까지 지난 날.
  final int monthCount;
  final int monthDays;

  /// 평균 글자 수 (반올림). 기록이 없으면 0.
  final int avgLength;

  /// 올해 1월~이번 달까지 월별 줄 수.
  final List<int> byMonth;

  int get monthPct => monthDays == 0 ? 0 : (monthCount * 100 / monthDays).round();

  factory DiaryStats.compute(DiaryData d, DateTime now) {
    final today = dayOf(now);
    final keys = d.entries.keys.toSet();
    bool has(DateTime day) => keys.contains(dateKey(day));

    final writtenToday = has(today);
    var cur = writtenToday ? today : addDays(today, -1);
    var streak = 0;
    while (has(cur)) {
      streak++;
      cur = addDays(cur, -1);
    }

    final days = [for (final k in keys) parseKey(k)].whereType<DateTime>().toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final day in days) {
      run = (prev != null && addDays(prev, 1) == day) ? run + 1 : 1;
      best = math.max(best, run);
      prev = day;
    }

    final monthPrefix = '${today.year}-${two(today.month)}-';
    final monthCount = keys.where((k) => k.startsWith(monthPrefix) && k.compareTo(dateKey(today)) <= 0).length;

    final byMonth = [
      for (var m = 1; m <= today.month; m++) keys.where((k) => k.startsWith('${today.year}-${two(m)}-')).length,
    ];

    final lengths = d.entries.values.map(lineLength);
    final avg = lengths.isEmpty ? 0 : (lengths.reduce((a, b) => a + b) / lengths.length).round();

    return DiaryStats._(
      total: keys.length,
      streak: streak,
      bestStreak: math.max(best, streak),
      writtenToday: writtenToday,
      monthCount: monthCount,
      monthDays: today.day,
      avgLength: avg,
      byMonth: byMonth,
    );
  }
}

/// 이번 주 월~일 중 쓴 날. 미래는 null.
List<bool?> weekMarks(DiaryData d, DateTime now) {
  final today = dayOf(now);
  final monday = addDays(today, -(today.weekday - 1));
  return [
    for (var i = 0; i < 7; i++)
      () {
        final day = addDays(monday, i);
        return day.isAfter(today) ? null : d.on(day) != null;
      }(),
  ];
}

/// `■■■□□□□` 연속 기록 막대.
String streakBar(int streak, {int width = 7}) {
  final n = math.min(streak, width);
  return '■' * n + '□' * (width - n);
}

/// `████░░░░░░` 형태의 막대. [max]가 0이면 빈 막대.
String textBar(int value, int max, {int width = 10}) {
  final cells = max <= 0 ? 0 : math.min(width, math.max(0, (value * width / max).round()));
  return '█' * cells + '░' * (width - cells);
}
