import 'package:flutter/material.dart';

import '../state/diary_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';
import 'cal_screen.dart';

/// (명령어, 인자, 설명, 예시)
const _entries = <(String, String, String, String?)>[
  ('echo', '<오늘 한 줄>', '오늘 한 줄 저장. 명령어 없이 입력해도 echo 로 처리돼요. 80자까지.', 'echo 퇴근길 노을이 예뻤다'),
  ('edit', '[날짜] <내용>', '고쳐 쓰기. 날짜를 붙이면 지난 날도 쓰거나 고칠 수 있어요.', 'edit 어제 늦잠 잤다'),
  ('rm', '[날짜]', '그날 한 줄 지우기. 날짜를 빼면 오늘.', 'rm 09.28'),
  ('cat', '[날짜 | --ago]', '그날 한 줄 보기. --ago 는 지난해 오늘들.', 'cat --ago'),
  ('grep', '<단어>', '모든 기록에서 단어 찾기.', 'grep 커피'),
  ('ls', '[YYYY-MM]', '그 달에 쓴 줄 수.', 'ls 2026-08'),
  ('ago', '', '해마다 같은 날 쓴 한 줄 모아 보기.', null),
  ('cal', '', '달력, 연속 기록, 월별 줄 수.', null),
  ('cls', '', '화면 로그만 지워요. 일기는 그대로예요.', null),
  ('theme', '[cmd | phosphor | amber]', '색 테마 변경. phosphor · amber 는 PRO.', 'theme amber'),
  ('mode', '[auto | light | dark]', '밝기 모드. auto 는 폰 설정을 따라가요. (cmd 테마)', 'mode light'),
  ('crt', '[on | off]', '옛날 모니터 같은 주사선 효과. (PRO)', null),
  ('upgrade', '', 'PRO 소개와 구매. 테마 · 위젯 · CRT 를 한 번 결제로 열어요.', null),
  ('restore', '', '예전에 산 PRO 를 다시 불러와요. (기기 변경, 재설치)', null),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.store});

  final DiaryStore store;

  @override
  Widget build(BuildContext context) {
    final p = store.palette;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitleBar(
            palette: p,
            now: store.now(),
            onCal: () => Navigator.of(context).pushReplacement(termRoute(CalScreen(store: store))),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'C:\\diary> ', style: termStyle(p.dim)),
                  TextSpan(text: 'help', style: termStyle(p.cmd)),
                ])),
                const SizedBox(height: 10),
                Text('명령어 목록', style: termStyle(p.hi)),
                Text('<필수>  [선택]  |  또는', style: termStyle(p.dim, size: 13)),
                const SizedBox(height: 10),
                DashedDivider(color: p.line),
                for (final e in _entries)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(text: e.$1, style: termStyle(p.cmd)),
                          if (e.$2.isNotEmpty) TextSpan(text: ' ${e.$2}', style: termStyle(p.fg)),
                        ])),
                        const SizedBox(height: 2),
                        Text(e.$3, style: termStyle(p.dim, size: 13, ko: true)),
                        if (e.$4 != null) Text('예) ${e.$4}', style: termStyle(p.tag, size: 13, ko: true)),
                      ],
                    ),
                  ),
                const SizedBox(height: 18),
                Text('날짜 쓰는 법', style: termStyle(p.hi)),
                const SizedBox(height: 6),
                _SyntaxRow(palette: p, token: '09.28', text: '올해 9월 28일 (9/28, 9-28 도 돼요)'),
                _SyntaxRow(palette: p, token: '2025-09-29', text: '연도까지'),
                _SyntaxRow(palette: p, token: '어제 그제', text: 'yesterday 도 돼요'),
                const SizedBox(height: 10),
                Text('팁', style: termStyle(p.hi)),
                const SizedBox(height: 6),
                _SyntaxRow(palette: p, token: '줄 탭', text: '이번 주 줄을 누르면 edit 가 채워져요'),
                _SyntaxRow(palette: p, token: '↑ ↓', text: '이전 명령어 (키보드 연결 시)'),
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
}

class _SyntaxRow extends StatelessWidget {
  const _SyntaxRow({required this.palette, required this.token, required this.text});

  final TermPalette palette;
  final String token;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: Text(token, style: termStyle(palette.tag, size: 13))),
            Expanded(child: Text(text, style: termStyle(palette.dim, size: 13, ko: true))),
          ],
        ),
      );
}
