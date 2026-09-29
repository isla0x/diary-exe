import 'dates.dart';

/// 명령어 해석과 실행. UI와 저장소에 의존하지 않는 순수 로직이라 테스트하기 쉽다.

enum LogKind { cmd, ok, err, info }

class LogLine {
  const LogLine(this.kind, this.text);

  final LogKind kind;
  final String text;
}

const themeIds = ['cmd', 'phosphor', 'amber'];

/// 밝기 모드. auto = 폰 설정을 따른다. (cmd 테마에만 적용, 무료)
const modeIds = ['auto', 'light', 'dark'];

/// 무료로 쓸 수 있는 테마.
const freeTheme = 'cmd';

/// 하루 한 줄의 최대 글자 수.
const maxLineLength = 80;

class DiaryData {
  const DiaryData({
    this.entries = const {},
    this.theme = 'cmd',
    this.crt = false,
    this.mode = 'auto',
  });

  /// 'YYYY-MM-DD' → 그날의 한 줄.
  final Map<String, String> entries;
  final String theme;
  final bool crt;
  final String mode;

  String? on(DateTime day) => entries[dateKey(day)];

  DiaryData copyWith({Map<String, String>? entries, String? theme, bool? crt, String? mode}) => DiaryData(
        entries: entries ?? this.entries,
        theme: theme ?? this.theme,
        crt: crt ?? this.crt,
        mode: mode ?? this.mode,
      );

  DiaryData withEntry(DateTime day, String? text) {
    final next = Map<String, String>.of(entries);
    if (text == null) {
      next.remove(dateKey(day));
    } else {
      next[dateKey(day)] = text;
    }
    return copyWith(entries: next);
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'entries': entries,
        'theme': theme,
        'crt': crt,
        'mode': mode,
      };

  factory DiaryData.fromJson(Map<String, dynamic> json) {
    final theme = (json['theme'] as String?) ?? 'cmd';
    final mode = (json['mode'] as String?) ?? 'auto';
    final raw = Map<String, dynamic>.from((json['entries'] as Map?) ?? const {});
    return DiaryData(
      entries: {
        for (final e in raw.entries)
          if (parseKey(e.key) != null && e.value is String) e.key: e.value as String,
      },
      theme: themeIds.contains(theme) ? theme : 'cmd',
      crt: (json['crt'] as bool?) ?? false,
      mode: modeIds.contains(mode) ? mode : 'auto',
    );
  }
}

/// 글자 수 (한글 한 글자 = 1).
int lineLength(String s) => s.runes.length;

final _spaceRe = RegExp(r'\s+');

/// `퇴근길 노을 >> today` 처럼 뒤에 붙은 리다이렉트는 떼어낸다.
final _redirectRe = RegExp(r'\s*>>\s*\S*\s*$');

String cleanLine(String s) => s.replaceAll(_redirectRe, '').replaceAll(_spaceRe, ' ').trim();

class CommandOutcome {
  const CommandOutcome(this.data, this.lines, {this.clearLog = false, this.route, this.query});

  final DiaryData data;
  final List<LogLine> lines;

  /// `cls` 일 때 true.
  final bool clearLog;

  /// 열어야 할 화면 ('ago' | 'cal' | 'help' | 'pro' | 'restore').
  final String? route;

  /// ago 화면에 넘길 검색어 (`grep`).
  final String? query;
}

const knownCommands = {
  'echo', 'edit', 'rm', 'cat', 'grep', 'ls', 'cal', 'ago', 'stats', 'help', //
  'theme', 'crt', 'mode', 'upgrade', 'pro', 'restore',
};

/// [pro] 가 false 면 cmd 외 테마와 crt 는 잠겨 있다.
CommandOutcome runCommand(DiaryData d, String raw, DateTime now, {bool pro = false}) {
  final s = raw.trim();
  if (s.isEmpty) return CommandOutcome(d, const []);

  final first = s.split(_spaceRe).first;
  var cmd = first.toLowerCase();
  var arg = s.substring(first.length).trim();

  if (cmd == 'cls') return CommandOutcome(d, const [], clearLog: true);

  // 모르는 명령어는 통째로 오늘 한 줄로 쓴다.
  if (!knownCommands.contains(cmd)) {
    cmd = 'echo';
    arg = s;
  }

  final today = dayOf(now);
  final lines = <LogLine>[LogLine(LogKind.cmd, 'C:\\diary> $s')];
  void ok(String t) => lines.add(LogLine(LogKind.ok, t));
  void err(String t) => lines.add(LogLine(LogKind.err, t));
  void info(String t) => lines.add(LogLine(LogKind.info, t));

  var data = d;
  String? route;
  String? query;

  void denied(String what) {
    err('Access is denied.');
    info("$what 은(는) PRO 기능이에요. 'upgrade' 로 열 수 있어요.");
  }

  void badDate(String a) {
    err("'$a' 는 알 수 없는 날짜예요. 예: 09.28 · 어제 · 2025-09-29");
    info("일기로 쓰려면 앞에 echo 를 붙여 주세요.");
  }

  /// 글자 수를 확인하고 저장. 성공하면 true.
  bool write(DateTime day, String text, {required bool overwrite}) {
    final line = cleanLine(text);
    if (line.isEmpty) {
      err(overwrite ? '사용법: edit [날짜] <내용>' : '사용법: echo <오늘 한 줄>');
      return false;
    }
    final len = lineLength(line);
    if (len > maxLineLength) {
      err('한 줄은 $maxLineLength자까지예요. (지금 $len자)');
      return false;
    }
    final existed = d.on(day) != null;
    if (existed && !overwrite) {
      err('${day == today ? '오늘' : shortDate(day)} 한 줄은 이미 있어요. 고치려면 edit');
      return false;
    }
    data = d.withEntry(day, line);
    ok('${existed ? '고쳐 썼어요' : '저장했어요'} → ${shortDate(day)}  ($len/$maxLineLength)');
    return true;
  }

  switch (cmd) {
    case 'echo':
      write(today, arg, overwrite: false);

    case 'edit':
      // `edit 09.28 내용` 이면 그날을, 아니면 오늘을 고친다.
      final head = arg.split(_spaceRe).first;
      final day = head.isEmpty ? null : parseDateArg(head, now);
      if (day != null) {
        if (day.isAfter(today)) {
          err('아직 오지 않은 날은 쓸 수 없어요.');
          break;
        }
        write(day, arg.substring(head.length), overwrite: true);
      } else {
        write(today, arg, overwrite: true);
      }

    case 'rm':
      final day = arg.isEmpty ? today : parseDateArg(arg, now);
      if (day == null) {
        badDate(arg);
        break;
      }
      if (d.on(day) == null) {
        info('${shortDate(day)} 에는 지울 한 줄이 없어요.');
        break;
      }
      data = d.withEntry(day, null);
      ok('- ${shortDate(day)} 한 줄을 지웠어요.');

    case 'cat':
      if (arg == '--ago' || arg == '-a') {
        final past = onThisDay(d, today);
        if (past.isEmpty) {
          info('지난해 오늘의 기록이 아직 없어요.');
        } else {
          for (final e in past.take(3)) {
            info('${today.year - e.day.year}년 전 · ${e.text}');
          }
        }
        break;
      }
      final day = arg.isEmpty ? today : parseDateArg(arg, now);
      if (day == null) {
        badDate(arg);
        break;
      }
      info('${longDate(day)}  ${d.on(day) ?? '(기록 없음)'}');

    case 'grep':
      final word = arg.trim();
      if (word.isEmpty) {
        err('사용법: grep <단어>');
        break;
      }
      final hits = search(d, word);
      info("'$word' ${hits.length}줄 찾음");
      for (final h in hits.take(2)) {
        info('${h.key.replaceAll('-', '.')}  ${h.text}');
      }
      if (hits.length > 2) {
        route = 'ago';
        query = word;
      }

    case 'ls':
      final m = RegExp(r'^(\d{4})[-.](\d{1,2})$').firstMatch(arg);
      final year = m == null ? today.year : int.parse(m[1]!);
      final month = m == null ? today.month : int.parse(m[2]!);
      if (arg.isNotEmpty && (m == null || month < 1 || month > 12)) {
        err('사용법: ls [YYYY-MM]');
        break;
      }
      final prefix = '$year-${two(month)}-';
      final n = d.entries.keys.where((k) => k.startsWith(prefix)).length;
      info('$year.${two(month)}  $n줄 · 전체 ${d.entries.length}줄');

    case 'cal' || 'stats':
      route = 'cal';

    case 'ago':
      route = 'ago';
      if (arg.isNotEmpty) query = arg;

    case 'help':
      route = 'help';

    case 'upgrade' || 'pro':
      route = 'pro';

    case 'restore':
      route = 'restore';

    case 'mode':
      final a = arg.toLowerCase();
      if (a.isEmpty) {
        info('현재 모드: ${d.mode}  (${modeIds.join(' | ')})');
      } else if (!modeIds.contains(a)) {
        err("mode: '$arg' 는 없는 모드예요. (${modeIds.join(' | ')})");
      } else {
        data = d.copyWith(mode: a);
        ok('모드 변경: $a');
        if (pro && d.theme != freeTheme) info('밝은 모드는 cmd 테마에서만 보여요.');
      }

    case 'theme':
      final a = arg.toLowerCase();
      if (a.isEmpty) {
        info('현재 테마: ${pro ? d.theme : freeTheme}  (${themeIds.join(' | ')})');
        if (!pro) info("phosphor · amber 는 PRO 테마예요. 'upgrade'");
      } else if (!themeIds.contains(a)) {
        err("theme: '$arg' 는 없는 테마예요. (${themeIds.join(' | ')})");
      } else if (a != freeTheme && !pro) {
        denied('$a 테마');
      } else {
        data = d.copyWith(theme: a);
        ok('테마 변경: $a');
      }

    case 'crt':
      if (!pro) {
        denied('crt 효과');
        break;
      }
      final a = arg.toLowerCase();
      final bool? next = switch (a) {
        '' => !d.crt,
        'on' => true,
        'off' => false,
        _ => null,
      };
      if (next == null) {
        err('사용법: crt [on | off]');
        break;
      }
      data = d.copyWith(crt: next);
      ok('crt ${next ? 'on' : 'off'}');
  }

  return CommandOutcome(data, lines, route: route, query: query);
}

/// 기록 한 줄 (날짜 포함).
class DiaryLine {
  const DiaryLine(this.key, this.day, this.text);

  final String key;
  final DateTime day;
  final String text;
}

/// 지난 해들의 같은 날짜 기록. 최근 해부터.
List<DiaryLine> onThisDay(DiaryData d, DateTime today) {
  final mmdd = dateKey(today).substring(5);
  final out = <DiaryLine>[];
  for (final e in d.entries.entries) {
    if (!e.key.endsWith(mmdd)) continue;
    final day = parseKey(e.key);
    if (day == null || day.year >= today.year) continue;
    out.add(DiaryLine(e.key, day, e.value));
  }
  out.sort((a, b) => b.key.compareTo(a.key));
  return out;
}

/// 단어가 들어간 기록. 최근 날짜부터. 대소문자 구분 없음.
List<DiaryLine> search(DiaryData d, String word) {
  final w = word.toLowerCase();
  final out = <DiaryLine>[
    for (final e in d.entries.entries)
      if (e.value.toLowerCase().contains(w)) DiaryLine(e.key, parseKey(e.key)!, e.value),
  ];
  out.sort((a, b) => b.key.compareTo(a.key));
  return out;
}
