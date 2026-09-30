import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../state/diary_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';
import 'home_screen.dart';

const _logo = '████  ███  ███  ████  █   █\n'
    '█   █  █  █   █ █   █  █ █ \n'
    '█   █  █  █████ ████    █  \n'
    '█   █  █  █   █ █  █    █  \n'
    '████  ███ █   █ █   █   █  ';

/// 실행하면 처음 보이는 부팅 화면. 아무 데나 탭하면 건너뛴다.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key, required this.store});

  final DiaryStore store;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  static const _steps = 6;
  Timer? _timer;
  int _step = 0;

  bool get _ready => _step >= _steps;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 240), (t) {
      if (!mounted || _ready) {
        t.cancel();
        return;
      }
      setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTap() {
    if (!_ready) {
      _timer?.cancel();
      setState(() => _step = _steps);
      return;
    }
    _enter();
  }

  void _enter() {
    Navigator.of(context).pushReplacement(termRoute(HomeScreen(store: widget.store)));
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = store.palette;
    final now = store.now();
    final d = store.data;
    final date = '${now.year}-${two(now.month)}-${two(now.day)} (${weekdayKo[now.weekday - 1]})';
    final lines = [
      ('설정 불러오기', 'config'),
      ('일기장 열기', '${d.entries.length}줄'),
      ('날짜 확인', date),
      ('명령어 해석기', 'v1.0'),
      ('테마 적용', p.isLight ? '${p.id} · light' : p.id),
    ];
    final cells = (_step * 20 / _steps).round();
    final pct = (_step * 100 / _steps).round();

    return Scaffold(
      backgroundColor: p.bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TitleBar(palette: p, now: now),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight),
                    child: IntrinsicHeight(
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                label: 'DIARY',
                                excludeSemantics: true,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _logo,
                                    softWrap: false,
                                    style: termStyle(p.hi, size: 20, height: 1.05),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text('DIARY [Version 1.0.0]', style: termStyle(p.hi)),
                              Text('하루에 한 줄이면 충분해.', style: termStyle(p.dim, size: 13, ko: true)),
                              const SizedBox(height: 32),
                              Text.rich(TextSpan(children: [
                                TextSpan(text: 'C:\\> ', style: termStyle(p.dim)),
                                TextSpan(text: 'diary.exe --boot', style: termStyle(p.cmd)),
                              ])),
                              const SizedBox(height: 10),
                              for (var i = 0; i < lines.length; i++)
                                if (i < _step)
                                  _BootLine(palette: p, status: '[ OK ]', label: lines[i].$1, value: lines[i].$2)
                                else if (i == _step)
                                  _BootLine(palette: p, status: '[ .. ]', label: lines[i].$1, value: '', pending: true),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '[${'█' * cells}${'░' * (20 - cells)}]',
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.clip,
                                      style: termStyle(p.tag, size: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('$pct%', style: termStyle(p.hi, size: 13)),
                                ],
                              ),
                              const Spacer(),
                              const SizedBox(height: 24),
                              Text('Tip: 명령어 없이 입력하면 오늘 한 줄로 저장돼요.', style: termStyle(p.dim, size: 13, ko: true)),
                              const SizedBox(height: 14),
                              AnimatedOpacity(
                                opacity: _ready ? 1 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: IgnorePointer(
                                  ignoring: !_ready,
                                  child: TermWideButton(
                                    palette: p,
                                    keyLabel: '[ ENTER ]',
                                    label: '시작하기',
                                    onTap: _enter,
                                    trailing: BlinkingCursor(style: termStyle(p.hi, size: 15)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootLine extends StatelessWidget {
  const _BootLine({
    required this.palette,
    required this.status,
    required this.label,
    required this.value,
    this.pending = false,
  });

  final TermPalette palette;
  final String status;
  final String label;
  final String value;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(status, style: termStyle(pending ? p.dim : p.tag, size: 13)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: termStyle(pending ? p.hi : p.fg, size: 13))),
          Text(value, style: termStyle(p.dim, size: 13)),
        ],
      ),
    );
  }
}
