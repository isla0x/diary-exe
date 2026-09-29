import 'package:diary_exe/logic/commands.dart';
import 'package:diary_exe/logic/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 29, 21, 30);
  const empty = DiaryData();

  CommandOutcome run(DiaryData d, String s, {bool pro = false}) => runCommand(d, s, now, pro: pro);
  String lastText(CommandOutcome o) => o.lines.last.text;
  LogKind lastKind(CommandOutcome o) => o.lines.last.kind;

  group('echo', () {
    test('명령어 없이 입력하면 오늘 한 줄로 저장', () {
      final o = run(empty, '퇴근길 노을이 예뻤다');
      expect(o.data.entries['2026-09-29'], '퇴근길 노을이 예뻤다');
      expect(lastKind(o), LogKind.ok);
      expect(o.lines.first.text, r'C:\diary> 퇴근길 노을이 예뻤다');
    });

    test('echo 와 >> 리다이렉트를 떼어낸다', () {
      final o = run(empty, 'echo 라떼   맛있음 >> today');
      expect(o.data.entries['2026-09-29'], '라떼 맛있음');
    });

    test('오늘 이미 썼으면 echo 는 거절, edit 로 고친다', () {
      final d = run(empty, '첫 줄').data;
      final again = run(d, '두 번째');
      expect(lastKind(again), LogKind.err);
      expect(again.data.entries['2026-09-29'], '첫 줄');
      final edited = run(d, 'edit 고친 줄');
      expect(edited.data.entries['2026-09-29'], '고친 줄');
      expect(lastText(edited), contains('고쳐 썼어요'));
    });

    test('80자 제한 (한글도 한 글자로 센다)', () {
      final ok = run(empty, 'echo ${'가' * 80}');
      expect(ok.data.entries.length, 1);
      final tooLong = run(empty, 'echo ${'가' * 81}');
      expect(tooLong.data.entries, isEmpty);
      expect(lastText(tooLong), contains('81자'));
    });

    test('빈 echo 는 사용법', () {
      final o = run(empty, 'echo');
      expect(lastKind(o), LogKind.err);
      expect(o.data.entries, isEmpty);
    });
  });

  group('edit 날짜', () {
    test('지난 날짜에 쓰거나 고칠 수 있다', () {
      final o = run(empty, 'edit 09.27 드라마 정주행');
      expect(o.data.entries['2026-09-27'], '드라마 정주행');
      final y = run(empty, 'edit 어제 늦잠');
      expect(y.data.entries['2026-09-28'], '늦잠');
    });

    test('미래 날짜는 안 된다', () {
      final o = run(empty, 'edit 2026-10-02 미리 쓰기');
      expect(lastKind(o), LogKind.err);
      expect(o.data.entries, isEmpty);
    });

    test('날짜처럼 생기지 않은 첫 단어는 내용으로 본다', () {
      final o = run(empty, 'edit 3시간 잤다');
      expect(o.data.entries['2026-09-29'], '3시간 잤다');
    });
  });

  group('rm · cat', () {
    final d = const DiaryData(entries: {
      '2026-09-29': '오늘',
      '2026-09-28': '어제',
      '2025-09-29': '작년 오늘',
      '2024-09-29': '재작년 오늘',
    });

    test('rm 은 기본이 오늘', () {
      final o = run(d, 'rm');
      expect(o.data.entries.containsKey('2026-09-29'), isFalse);
      expect(o.data.entries.length, 3);
    });

    test('rm 날짜', () {
      expect(run(d, 'rm 09.28').data.entries.containsKey('2026-09-28'), isFalse);
      expect(lastKind(run(d, 'rm 09.20')), LogKind.info);
    });

    test('cat 날짜 / 없는 날', () {
      expect(lastText(run(d, 'cat 어제')), contains('어제'));
      expect(lastText(run(d, 'cat 09.01')), contains('기록 없음'));
      expect(lastKind(run(d, 'cat 카페 갔다')), LogKind.info); // 날짜 아님 → 안내
    });

    test('cat --ago 는 지난해부터', () {
      final o = run(d, 'cat --ago');
      final texts = o.lines.skip(1).map((l) => l.text).toList();
      expect(texts, ['1년 전 · 작년 오늘', '2년 전 · 재작년 오늘']);
    });
  });

  test('grep 은 최근 순, 대소문자 무시', () {
    const d = DiaryData(entries: {
      '2026-09-01': 'Coffee 한 잔',
      '2026-09-20': '커피 끊기 실패',
      '2026-09-25': '커피집 사장님',
      '2026-09-26': '떡볶이',
    });
    final o = run(d, 'grep 커피');
    expect(o.lines[1].text, "'커피' 2줄 찾음");
    expect(o.lines[2].text, startsWith('2026.09.25'));
    expect(search(d, 'coffee').length, 1);
  });

  test('ls 는 이번 달 줄 수', () {
    const d = DiaryData(entries: {'2026-09-01': 'a', '2026-09-02': 'b', '2026-08-31': 'c'});
    expect(lastText(run(d, 'ls')), '2026.09  2줄 · 전체 3줄');
    expect(lastText(run(d, 'ls 2026-08')), '2026.08  1줄 · 전체 3줄');
  });

  test('화면 이동 명령어', () {
    expect(run(empty, 'cal').route, 'cal');
    expect(run(empty, 'stats').route, 'cal');
    expect(run(empty, 'ago').route, 'ago');
    expect(run(empty, 'help').route, 'help');
    expect(run(empty, 'upgrade').route, 'pro');
    expect(run(empty, 'restore').route, 'restore');
    expect(run(empty, 'cls').clearLog, isTrue);
  });

  group('PRO', () {
    test('무료는 cmd 테마와 crt 가 잠겨 있다', () {
      final o = run(empty, 'theme amber');
      expect(o.lines[1].text, 'Access is denied.');
      expect(o.data.theme, 'cmd');
      expect(run(empty, 'crt on').data.crt, isFalse);
    });

    test('PRO 는 테마와 crt 를 바꾼다', () {
      expect(run(empty, 'theme amber', pro: true).data.theme, 'amber');
      expect(run(empty, 'crt on', pro: true).data.crt, isTrue);
    });

    test('mode 는 무료', () {
      expect(run(empty, 'mode light').data.mode, 'light');
      expect(lastKind(run(empty, 'mode pink')), LogKind.err);
    });
  });

  test('JSON 저장/불러오기, 잘못된 키는 버린다', () {
    const d = DiaryData(entries: {'2026-09-29': '한 줄'}, theme: 'amber', crt: true, mode: 'light');
    final back = DiaryData.fromJson(d.toJson());
    expect(back.entries, d.entries);
    expect(back.theme, 'amber');
    expect(back.mode, 'light');
    final messy = DiaryData.fromJson({
      'entries': {'2026-02-30': 'x', 'hello': 'y', '2026-09-01': 'ok'},
      'theme': 'neon',
    });
    expect(messy.entries.keys, ['2026-09-01']);
    expect(messy.theme, 'cmd');
  });

  group('날짜 해석', () {
    test('여러 형식', () {
      expect(dateKey(parseDateArg('2025-09-29', now)!), '2025-09-29');
      expect(dateKey(parseDateArg('2025.9.3', now)!), '2025-09-03');
      expect(dateKey(parseDateArg('9/28', now)!), '2026-09-28');
      expect(dateKey(parseDateArg('그제', now)!), '2026-09-27');
      expect(parseDateArg('13.01', now), isNull);
      expect(parseDateArg('02.30', now), isNull);
    });

    test('연도 없는 미래 날짜는 작년으로', () {
      expect(dateKey(parseDateArg('12.25', now)!), '2025-12-25');
    });
  });
}
