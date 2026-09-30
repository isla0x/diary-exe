import 'package:flutter/material.dart';

import '../logic/commands.dart';
import '../logic/dates.dart';
import '../state/diary_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';
import 'cal_screen.dart';

/// `ago`: 해마다 같은 날 쓴 한 줄 + 전체 검색(grep).
class AgoScreen extends StatefulWidget {
  const AgoScreen({super.key, required this.store, this.initialQuery});

  final DiaryStore store;
  final String? initialQuery;

  @override
  State<AgoScreen> createState() => _AgoScreenState();
}

class _AgoScreenState extends State<AgoScreen> {
  late final _ctrl = TextEditingController(text: widget.initialQuery ?? '');
  final _focus = FocusNode();

  static const _maxHits = 100;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onText);
    _focus.addListener(_onText);
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    _ctrl.removeListener(_onText);
    _focus.removeListener(_onText);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = store.palette;
    final d = store.data;
    final now = store.now();
    final today = dayOf(now);
    final past = onThisDay(d, today);
    final word = _ctrl.text.trim();
    final hits = word.isEmpty ? const <DiaryLine>[] : search(d, word);

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitleBar(
            palette: p,
            now: now,
            active: 'ago',
            onCal: () => Navigator.of(context).pushReplacement(termRoute(CalScreen(store: store))),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                _prompt(p, 'cat --ago'),
                Text('${today.month}월 ${today.day}일, 해마다 남긴 한 줄', style: termStyle(p.dim, size: 13, ko: true)),
                const SizedBox(height: 12),
                _YearRow(
                  palette: p,
                  year: today.year,
                  sub: '오늘 · ${weekdayKo[today.weekday - 1]}',
                  text: d.on(today),
                  current: true,
                  last: past.isEmpty,
                ),
                for (final (i, e) in past.indexed)
                  _YearRow(
                    palette: p,
                    year: e.day.year,
                    sub: '${today.year - e.day.year}년 전 · ${weekdayKo[e.day.weekday - 1]}',
                    text: e.text,
                    last: i == past.length - 1,
                  ),
                if (past.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '지난해 오늘의 기록은 아직 없어요.\n오늘 한 줄을 쓰면 내년 오늘 여기 돌아와요.',
                      style: termStyle(p.dim, size: 13, ko: true),
                    ),
                  ),
                const SizedBox(height: 20),
                DashedDivider(color: p.line),
                const SizedBox(height: 14),
                Container(
                  height: 48,
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  decoration: BoxDecoration(border: Border.all(color: _focus.hasFocus ? p.fg : p.line)),
                  child: Row(
                    children: [
                      Text('C:\\diary> grep ', style: termStyle(p.cmd)),
                      Expanded(
                        child: Semantics(
                          label: '기록 검색',
                          child: TextField(
                            controller: _ctrl,
                            focusNode: _focus,
                            style: termStyle(p.hi, size: 16, height: 1.2, ko: true),
                            cursorColor: p.tag,
                            keyboardAppearance: p.isLight ? Brightness.light : Brightness.dark,
                            autocorrect: false,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration.collapsed(
                              hintText: '단어',
                              hintStyle: termStyle(p.dim, size: 16, height: 1.2),
                            ),
                            onTapOutside: (_) => _focus.unfocus(),
                          ),
                        ),
                      ),
                      if (word.isNotEmpty)
                        Semantics(
                          button: true,
                          label: '검색어 지우기',
                          excludeSemantics: true,
                          child: InkWell(
                            onTap: _ctrl.clear,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(child: Text('×', style: termStyle(p.dim, size: 18))),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (word.isEmpty)
                  Text('전체 ${d.entries.length}줄에서 찾아요.', style: termStyle(p.dim, size: 12, ko: true))
                else ...[
                  Semantics(
                    liveRegion: true,
                    child: Text('${hits.length}줄 찾음', style: termStyle(p.dim, size: 12)),
                  ),
                  const SizedBox(height: 6),
                  for (final h in hits.take(_maxHits))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 92,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(h.key.replaceAll('-', '.'), style: termStyle(p.dim, size: 12)),
                            ),
                          ),
                          Expanded(child: _Highlighted(text: h.text, word: word, palette: p)),
                        ],
                      ),
                    ),
                  if (hits.length > _maxHits)
                    Text('최근 $_maxHits줄만 보여요.', style: termStyle(p.dim, size: 12, ko: true)),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TermWideButton(
                palette: p,
                keyLabel: '[ ESC ]',
                label: '오늘로',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prompt(TermPalette p, String cmd) => Text.rich(TextSpan(children: [
        TextSpan(text: 'C:\\diary> ', style: termStyle(p.dim)),
        TextSpan(text: cmd, style: termStyle(p.cmd)),
      ]));
}

/// 연도 줄: 왼쪽에 굵은 연도와 세로선, 오른쪽에 그날 한 줄.
class _YearRow extends StatelessWidget {
  const _YearRow({
    required this.palette,
    required this.year,
    required this.sub,
    required this.text,
    this.current = false,
    this.last = false,
  });

  final TermPalette palette;
  final int year;
  final String sub;
  final String? text;
  final bool current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Text('$year', style: termStyle(current ? p.tag : p.hi, weight: FontWeight.w700)),
                if (!last) Expanded(child: Container(width: 1, color: p.line)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub, style: termStyle(p.dim, size: 12)),
                  if (text != null)
                    Text(text!, style: termStyle(p.hi, size: 14, ko: true))
                  else
                    Row(
                      children: [
                        BlinkingCursor(style: termStyle(p.tag, size: 14)),
                        const SizedBox(width: 8),
                        Flexible(child: Text('아직 안 썼어요', style: termStyle(p.dim, size: 13, ko: true))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 검색어 부분만 반전 표시.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.word, required this.palette});

  final String text;
  final String word;
  final TermPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final lower = text.toLowerCase();
    final w = word.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (true) {
      final j = lower.indexOf(w, i);
      if (j < 0 || w.isEmpty) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (j > i) spans.add(TextSpan(text: text.substring(i, j)));
      spans.add(TextSpan(
        text: text.substring(j, j + w.length),
        style: TextStyle(color: p.bg, backgroundColor: p.tag),
      ));
      i = j + w.length;
    }
    return Text.rich(TextSpan(style: termStyle(p.hi, size: 14, ko: true), children: spans));
  }
}
