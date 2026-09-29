import 'package:diary_exe/logic/commands.dart';
import 'package:diary_exe/logic/stats.dart';
import 'package:diary_exe/widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 29, 21, 30); // 화요일

  const d = DiaryData(entries: {
    '2026-09-28': '어제', // 월
    '2026-09-27': '그제',
    '2026-09-26': '사흘 전',
    '2026-09-24': '끊김',
    '2026-09-23': '끊김 전',
    '2026-09-22': '끊김 전2',
    '2026-09-21': '끊김 전3',
    '2026-08-31': '지난달',
    '2025-09-29': '작년 오늘',
    '2024-09-30': '재작년 내일',
  });

  test('오늘 안 썼으면 어제까지 연속', () {
    final s = DiaryStats.compute(d, now);
    expect(s.writtenToday, isFalse);
    expect(s.streak, 3);
    expect(s.bestStreak, 4);
    expect(s.monthCount, 7);
    expect(s.monthDays, 29);
    expect(s.total, 10);
    expect(s.byMonth.length, 9);
    expect(s.byMonth[8], 7);
    expect(s.byMonth[7], 1);
  });

  test('오늘 쓰면 연속에 포함', () {
    final s = DiaryStats.compute(d.withEntry(DateTime(2026, 9, 29), '오늘'), now);
    expect(s.writtenToday, isTrue);
    expect(s.streak, 4);
  });

  test('이번 주 표시 (월~일)', () {
    expect(weekMarks(d, now), [true, false, null, null, null, null, null]);
  });

  test('막대', () {
    expect(streakBar(3), '■■■□□□□');
    expect(streakBar(12), '■■■■■■■');
    expect(textBar(5, 10), '█████░░░░░');
  });

  test('위젯 스냅샷', () {
    final snap = widgetSnapshot(d, now, pro: true);
    expect(snap['date'], '2026-09-29');
    expect(snap['today'], isNull);
    expect(snap['streak'], 3);
    expect(snap['week'], [1, 0, -1, -1, -1, -1, -1]);
    expect(snap['ago'], {
      '09-29': {'y': 2025, 't': '작년 오늘'},
      '09-30': {'y': 2024, 't': '재작년 내일'},
    });
  });

  test('무료면 위젯 테마는 cmd', () {
    final snap = widgetSnapshot(d.copyWith(theme: 'amber'), now);
    expect(snap['pro'], isFalse);
    expect(snap['theme'], 'cmd');
  });
}
