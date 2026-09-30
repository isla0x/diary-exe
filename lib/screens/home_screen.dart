import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/commands.dart';
import '../logic/dates.dart';
import '../logic/stats.dart';
import '../state/diary_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';
import 'ago_screen.dart';
import 'cal_screen.dart';
import 'help_screen.dart';
import 'pro_screen.dart';

/// 메인 화면: 1년 전 오늘 + 이번 주 7줄 + 입력창.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final DiaryStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  int? _histIdx;

  DiaryStore get store => widget.store;

  static const _chips = ['echo', 'edit', 'cat', 'grep', 'cls', 'help'];
  static const _prefillChips = {'echo', 'edit', 'cat', 'grep'};

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onText);
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    _ctrl.removeListener(_onText);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _run(String raw, {bool fromInput = false}) {
    if (raw.trim().isEmpty) return;
    final req = store.run(raw);
    if (fromInput) _ctrl.clear();
    _histIdx = null;
    if (req != null) _open(req.route, query: req.query);
  }

  Future<void> _open(String route, {String? query}) async {
    if (route == 'restore') store.pro?.restore();
    final Widget page = switch (route) {
      'ago' => AgoScreen(store: store, initialQuery: query),
      'cal' => CalScreen(store: store),
      'pro' || 'restore' => ProScreen(store: store),
      _ => HelpScreen(store: store),
    };
    _focus.unfocus();
    // cal 화면에서 "이 날 고쳐 쓰기" 를 누르면 명령어가 돌아온다.
    final result = await Navigator.of(context).push<String>(termRoute(page));
    if (result != null && mounted) _prefill(result, raw: true);
  }

  void _prefill(String cmd, {bool raw = false}) {
    final text = raw ? cmd : '$cmd ';
    _ctrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    _focus.requestFocus();
  }

  /// 하드웨어 키보드 ↑ ↓ 로 이전 명령어 불러오기.
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final up = e.logicalKey == LogicalKeyboardKey.arrowUp;
    final down = e.logicalKey == LogicalKeyboardKey.arrowDown;
    if (!up && !down) return KeyEventResult.ignored;
    final h = store.history;
    if (h.isEmpty) return KeyEventResult.ignored;
    final cur = _histIdx ?? h.length;
    final i = up ? math.max(0, cur - 1) : math.min(h.length, cur + 1);
    _histIdx = i;
    final text = i == h.length ? '' : h[i];
    _ctrl.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    return KeyEventResult.handled;
  }

  Color _logColor(TermPalette p, LogKind k) => switch (k) {
        LogKind.cmd => p.fg,
        LogKind.ok => p.tag,
        LogKind.err => p.warn,
        LogKind.info => p.dim,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.palette;
        final d = store.data;
        final now = store.now();
        final today = dayOf(now);
        final stats = DiaryStats.compute(d, now);
        final past = onThisDay(d, today);

        return Scaffold(
          backgroundColor: p.bg,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TitleBar(
                palette: p,
                now: now,
                onAgo: () => _open('ago'),
                onCal: () => _open('cal'),
                onPro: store.isPro ? null : () => _open('pro'),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(top: 14, bottom: 8),
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          children: [
                            Text('DIARY [Version 1.0.0]', style: termStyle(p.hi)),
                            Text('(c) 채은. 하루에 한 줄이면 충분해.', style: termStyle(p.dim, size: 13, ko: true)),
                            const SizedBox(height: 16),
                            _prompt(p, 'cat --ago'),
                            const SizedBox(height: 6),
                            _AgoBox(palette: p, today: today, past: past, onTap: () => _open('ago')),
                            const SizedBox(height: 16),
                            _prompt(p, 'type week.txt'),
                            const SizedBox(height: 4),
                            for (var i = 0; i < 7; i++)
                              _DayRow(
                                palette: p,
                                day: addDays(today, -i),
                                text: d.on(addDays(today, -i)),
                                isToday: i == 0,
                                onTap: () => _onDayTap(addDays(today, -i), d.on(addDays(today, -i)), i == 0),
                              ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              children: [
                                Text('연속', style: termStyle(p.dim, size: 13)),
                                Text(streakBar(stats.streak), style: termStyle(p.tag, size: 13)),
                                Text('${stats.streak}일', style: termStyle(p.hi, size: 13)),
                                Text('· ${today.month}월 ${stats.monthCount}줄', style: termStyle(p.dim, size: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 64),
                          alignment: Alignment.bottomLeft,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final l in store.log)
                                Text(l.text, style: termStyle(_logColor(p, l.kind), size: 13, ko: true)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextFieldTapRegion(child: _footer(p, now, written: stats.writtenToday)),
            ],
          ),
        );
      },
    );
  }

  /// 줄을 누르면: 오늘 빈 줄은 입력창으로, 나머지는 `edit 날짜 내용` 을 채워 준다.
  void _onDayTap(DateTime day, String? text, bool isToday) {
    if (isToday && text == null) {
      _focus.requestFocus();
      return;
    }
    final date = '${two(day.month)}.${two(day.day)}';
    _prefill(text == null ? 'edit $date ' : 'edit $date $text', raw: true);
  }

  Widget _prompt(TermPalette p, String cmd) => Text.rich(TextSpan(children: [
        TextSpan(text: 'C:\\diary> ', style: termStyle(p.dim)),
        TextSpan(text: cmd, style: termStyle(p.cmd)),
      ]));

  /// 입력 중인 한 줄의 글자 수. 명령어(cat, grep 등)를 치는 중이면 -1.
  int _draftLength(DateTime now) {
    final s = _ctrl.text.trimLeft();
    if (s.isEmpty) return 0;
    final m = RegExp(r'^(\S+)\s*(.*)$').firstMatch(s)!;
    final cmd = m[1]!.toLowerCase();
    var body = s;
    if (cmd == 'echo') {
      body = m[2]!;
    } else if (cmd == 'edit') {
      body = m[2]!;
      final head = body.split(' ').first;
      if (head.isNotEmpty && parseDateArg(head, now) != null) body = body.substring(head.length);
    } else if (knownCommands.contains(cmd) || cmd == 'cls') {
      return -1;
    }
    return lineLength(cleanLine(body));
  }

  Widget _footer(TermPalette p, DateTime now, {required bool written}) {
    final len = _draftLength(now);
    return Container(
      decoration: BoxDecoration(
        color: p.bar,
        border: Border(top: BorderSide(color: p.line)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in _chips)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TermBoxButton(
                        palette: p,
                        label: c,
                        textColor: p.cmd,
                        onTap: () {
                          if (c == 'help') {
                            _open('help');
                          } else if (_prefillChips.contains(c)) {
                            _prefill(c);
                          } else {
                            _run(c);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 50,
              padding: const EdgeInsets.only(left: 12, right: 2),
              decoration: BoxDecoration(color: p.bg, border: Border.all(color: p.line)),
              child: Row(
                children: [
                  Text('C:\\diary>', style: termStyle(p.hi)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Focus(
                      onKeyEvent: _onKey,
                      child: Semantics(
                        label: '오늘 한 줄 또는 명령어',
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          style: termStyle(p.hi, size: 16, height: 1.2, ko: true),
                          cursorColor: p.tag,
                          keyboardAppearance: p.isLight ? Brightness.light : Brightness.dark,
                          cursorWidth: 9,
                          cursorHeight: 18,
                          autocorrect: false,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration.collapsed(
                            hintText: written ? 'edit 로 고쳐 쓰기' : '오늘 한 줄',
                            hintStyle: termStyle(p.dim, size: 16, height: 1.2, ko: true),
                          ),
                          onChanged: (_) => _histIdx = null,
                          // 입력 영역(칩, 저장 버튼 포함) 밖을 탭하면 키보드를 내린다.
                          onTapOutside: (_) => _focus.unfocus(),
                          onSubmitted: (v) => _run(v, fromInput: true),
                          // 비워두면 Enter 후에도 키보드가 닫히지 않는다.
                          onEditingComplete: () {},
                        ),
                      ),
                    ),
                  ),
                  if (len >= 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        '$len/$maxLineLength',
                        style: termStyle(len > maxLineLength ? p.warn : p.dim, size: 11),
                      ),
                    ),
                  Semantics(
                    button: true,
                    label: '저장',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () {
                        _run(_ctrl.text, fromInput: true);
                        _focus.requestFocus();
                      },
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: CustomPaint(size: const Size(18, 18), painter: ReturnIconPainter(p.tag)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `1년 전 오늘` 상자. 지난 기록이 없으면 안내 문구.
class _AgoBox extends StatelessWidget {
  const _AgoBox({required this.palette, required this.today, required this.past, required this.onTap});

  final TermPalette palette;
  final DateTime today;
  final List<DiaryLine> past;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final first = past.isEmpty ? null : past.first;
    final years = first == null ? 0 : today.year - first.day.year;
    return Semantics(
      button: true,
      label: first == null ? '지난 기록 보기' : '$years년 전 오늘, ${longDate(first.day)}. ${first.text}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(border: Border.all(color: p.tag.withAlpha(90))),
          child: first == null
              ? Text('1년 뒤 오늘, 오늘 쓴 한 줄이 여기 돌아와요.', style: termStyle(p.dim, size: 13, ko: true))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$years년 전 오늘 · ${longDate(first.day)}', style: termStyle(p.tag, size: 12)),
                    Text(first.text, style: termStyle(p.hi, size: 14, ko: true)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// 이번 주 한 줄: `09.28 월  퇴근길 노을이 ...`
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.palette,
    required this.day,
    required this.text,
    required this.isToday,
    required this.onTap,
  });

  final TermPalette palette;
  final DateTime day;
  final String? text;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final Widget body;
    if (text != null) {
      body = Text(text!, style: termStyle(p.hi, size: 14, ko: true));
    } else if (isToday) {
      body = Row(
        children: [
          BlinkingCursor(style: termStyle(p.tag, size: 14)),
          const SizedBox(width: 8),
          Text('아직 안 썼어요', style: termStyle(p.dim, size: 13, ko: true)),
        ],
      );
    } else {
      body = Text('·········', style: termStyle(p.dim.withAlpha(120), size: 13));
    }
    final status = text ?? (isToday ? '아직 안 씀. 눌러서 쓰기' : '기록 없음. 눌러서 쓰기');
    return Semantics(
      button: true,
      label: '${shortDate(day)} $status',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(shortDate(day), style: termStyle(isToday ? p.tag : p.dim, size: 12)),
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
