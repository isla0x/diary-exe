import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../logic/stats.dart';
import '../state/diary_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';
import 'ago_screen.dart';

/// `cal`: 달력(■ 씀 · 안 씀) + 기록 요약 + 월별 줄 수.
///
/// 날짜를 누르면 그날 한 줄이 나오고, "고쳐 쓰기" 를 누르면
/// `edit MM.DD ...` 명령어를 들고 메인 화면으로 돌아간다.
class CalScreen extends StatefulWidget {
  const CalScreen({super.key, required this.store});

  final DiaryStore store;

  @override
  State<CalScreen> createState() => _CalScreenState();
}

class _CalScreenState extends State<CalScreen> {
  late DateTime _month;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final today = dayOf(widget.store.now());
    _month = DateTime(today.year, today.month);
    _selected = today;
  }

  void _shiftMonth(int delta) {
    final today = dayOf(widget.store.now());
    final next = DateTime(_month.year, _month.month + delta);
    if (next.isAfter(DateTime(today.year, today.month))) return;
    setState(() {
      _month = next;
      final sameMonth = next.year == today.year && next.month == today.month;
      _selected = sameMonth ? today : DateTime(next.year, next.month + 1, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = store.palette;
    final d = store.data;
    final now = store.now();
    final today = dayOf(now);
    final stats = DiaryStats.compute(d, now);

    final isThisMonth = _month.year == today.year && _month.month == today.month;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final daysSoFar = isThisMonth ? today.day : daysInMonth;
    final prefix = '${_month.year}-${two(_month.month)}-';
    final monthCount = d.entries.keys.where((k) => k.startsWith(prefix)).length;
    final pct = daysSoFar == 0 ? 0 : (monthCount * 100 / daysSoFar).round();

    final lastMonth = _month.year == today.year ? today.month : 12;
    final byMonth = [
      for (var m = 1; m <= lastMonth; m++)
        d.entries.keys.where((k) => k.startsWith('${_month.year}-${two(m)}-')).length,
    ];
    final maxMonth = byMonth.fold(0, (a, b) => a > b ? a : b);

    final selectedText = d.on(_selected);

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitleBar(
            palette: p,
            now: now,
            active: 'cal',
            onAgo: () => Navigator.of(context).pushReplacement(termRoute(AgoScreen(store: store))),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'C:\\diary> ', style: termStyle(p.dim)),
                  TextSpan(text: 'cal ${_month.year}-${two(_month.month)}', style: termStyle(p.cmd)),
                ])),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(border: Border.all(color: p.line)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _stat(p, '${_month.month}월', '$monthCount / $daysSoFar일', '$pct%', p.tag),
                      _stat(p, '연속 기록', '${stats.streak}일', '최고 ${stats.bestStreak}일', p.dim),
                      _stat(p, '전체', '${stats.total}줄', '평균 ${stats.avgLength}자', p.dim),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _NavButton(palette: p, label: '◀', semantic: '이전 달', onTap: () => _shiftMonth(-1)),
                    Expanded(
                      child: Text(
                        '${_month.year} · ${two(_month.month)}',
                        textAlign: TextAlign.center,
                        style: termStyle(p.hi),
                      ),
                    ),
                    _NavButton(
                      palette: p,
                      label: '▶',
                      semantic: '다음 달',
                      onTap: isThisMonth ? null : () => _shiftMonth(1),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _MonthGrid(
                  palette: p,
                  month: _month,
                  today: today,
                  selected: _selected,
                  written: (day) => d.on(day) != null,
                  onPick: (day) => setState(() => _selected = day),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(style: termStyle(p.dim, size: 12), children: [
                    TextSpan(text: '■', style: termStyle(p.tag, size: 12)),
                    const TextSpan(text: ' 씀   ·  안 씀   '),
                    TextSpan(text: '□', style: termStyle(p.hi, size: 12)),
                    const TextSpan(text: ' 오늘'),
                  ]),
                ),
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    decoration: BoxDecoration(color: p.bar, border: Border.all(color: p.line)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(shortDate(_selected), style: termStyle(p.dim, size: 12)),
                              Text(
                                selectedText ?? (_selected == today ? '아직 안 썼어요' : '(기록 없음)'),
                                style: termStyle(selectedText == null ? p.dim : p.hi, size: 15, ko: true),
                              ),
                            ],
                          ),
                        ),
                        TermBoxButton(
                          palette: p,
                          label: selectedText == null ? '쓰기' : '고쳐 쓰기',
                          textColor: p.cmd,
                          onTap: () {
                            final date = '${two(_selected.month)}.${two(_selected.day)}';
                            Navigator.of(context).pop(
                              selectedText == null ? 'edit $date ' : 'edit $date $selectedText',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('${_month.year} · 월별 줄 수', style: termStyle(p.hi)),
                const SizedBox(height: 6),
                for (var m = 0; m < byMonth.length; m++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        SizedBox(width: 44, child: Text('${m + 1}월', style: termStyle(p.dim, size: 13))),
                        Flexible(
                          child: Text(
                            textBar(byMonth[m], maxMonth, width: 16),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: termStyle(p.tag, size: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${byMonth[m]}', style: termStyle(p.fg, size: 13)),
                      ],
                    ),
                  ),
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

  Widget _stat(TermPalette p, String label, String value, String extra, Color extraColor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            SizedBox(width: 88, child: Text(label, style: termStyle(p.dim))),
            Text(value, style: termStyle(p.hi)),
            const SizedBox(width: 10),
            Flexible(child: Text(extra, style: termStyle(extraColor))),
          ],
        ),
      );
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.palette, required this.label, required this.semantic, this.onTap});

  final TermPalette palette;
  final String label;
  final String semantic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        label: semantic,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(label, style: termStyle(onTap == null ? palette.line : palette.fg, size: 13)),
            ),
          ),
        ),
      );
}

/// 월~일 7칸 달력.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.palette,
    required this.month,
    required this.today,
    required this.selected,
    required this.written,
    required this.onPick,
  });

  final TermPalette palette;
  final DateTime month;
  final DateTime today;
  final DateTime selected;
  final bool Function(DateTime day) written;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final first = DateTime(month.year, month.month);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var dd = 1; dd <= days; dd++) DateTime(month.year, month.month, dd),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    Widget cell(DateTime? day) {
      if (day == null) return const SizedBox(height: 46);
      final future = day.isAfter(today);
      final isToday = day == today;
      final has = !future && written(day);
      final sel = day == selected;
      final mark = future ? ' ' : (isToday && !has ? '□' : (has ? '■' : '·'));
      final markColor = has ? p.tag : (isToday ? p.hi : p.dim.withAlpha(120));
      return Semantics(
        button: !future,
        selected: sel,
        label: '${day.month}월 ${day.day}일 ${future ? '' : (has ? '씀' : '안 씀')}',
        excludeSemantics: true,
        child: InkWell(
          onTap: future ? null : () => onPick(day),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: sel ? p.tag.withAlpha(28) : null,
              border: Border.all(
                color: sel ? p.tag : (isToday ? p.dim : Colors.transparent),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${day.day}', style: termStyle(future ? p.line : (isToday ? p.hi : p.fg), size: 12, height: 1.2)),
                Text(mark, style: termStyle(markColor, size: 12, height: 1.1)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (final w in weekdayKo)
              Expanded(
                child: Text(w, textAlign: TextAlign.center, style: termStyle(p.dim, size: 12)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < cells.length ~/ 7; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                for (var c = 0; c < 7; c++) Expanded(child: cell(cells[r * 7 + c])),
              ],
            ),
          ),
      ],
    );
  }
}
