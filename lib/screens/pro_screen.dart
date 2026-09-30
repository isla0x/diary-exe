import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../pro/pro_controller.dart';
import '../state/diary_store.dart';
import '../theme/term_palette.dart';
import '../widgets/term_widgets.dart';

/// `upgrade` 화면: PRO 소개 + 구매 / 복원.
class ProScreen extends StatelessWidget {
  const ProScreen({super.key, required this.store});

  final DiaryStore store;

  /// 위젯은 iOS 에만 있다 (안드로이드는 테마 · CRT 만).
  static bool get _hasWidgets => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static List<(String, String)> get _features => [
        for (final f in _allFeatures)
          if (_hasWidgets || !f.$1.contains('위젯')) f,
      ];

  static const _allFeatures = [
    ('테마 3종', 'cmd · phosphor · amber'),
    ('홈 화면 위젯', '오늘 한 줄 · 1년 전 오늘'),
    ('잠금화면 위젯', '1년 전 오늘 · 연속 기록'),
    ('CRT 효과', '옛날 모니터 주사선'),
    ('앞으로 나올 PRO 기능', '내보내기 · 잠금 등, 추가 결제 없이'),
  ];

  @override
  Widget build(BuildContext context) {
    final pro = store.pro;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.palette;
        final isPro = store.isPro;
        return Scaffold(
          backgroundColor: p.bg,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TitleBar(palette: p, now: store.now()),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: 'C:\\diary> ', style: termStyle(p.dim)),
                      TextSpan(text: 'upgrade', style: termStyle(p.cmd)),
                    ])),
                    const SizedBox(height: 14),
                    Text('diary.exe PRO', style: termStyle(p.hi, size: 22, weight: FontWeight.w700)),
                    Text('한 번 결제, 계속 사용', style: termStyle(p.dim, size: 13)),
                    const SizedBox(height: 16),
                    const _ThemePreview(),
                    const SizedBox(height: 16),
                    DashedDivider(color: p.line),
                    const SizedBox(height: 8),
                    for (final f in _features)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isPro ? '[x]' : '[+]', style: termStyle(p.tag)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.$1, style: termStyle(p.hi)),
                                  Text(f.$2, style: termStyle(p.dim, size: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    DashedDivider(color: p.line),
                    const SizedBox(height: 14),
                    if (isPro) ..._activeInfo(p) else ..._buyInfo(p, pro),
                    if (pro?.message != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '> ${pro!.message}',
                          style: termStyle(pro.messageIsError ? p.warn : p.tag, size: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isPro) ...[
                        Opacity(
                          opacity: (pro?.busy ?? false) ? 0.5 : 1,
                          child: TermWideButton(
                            palette: p,
                            keyLabel: '[ ENTER ]',
                            label: pro?.price == null ? '구매하기' : '${pro!.price} 구매하기',
                            onTap: () => pro?.buy(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TermBoxButton(
                                palette: p,
                                label: '구매 복원',
                                textColor: p.cmd,
                                onTap: () => pro?.restore(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TermBoxButton(
                                palette: p,
                                label: '[ ESC ] 닫기',
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        TermWideButton(
                          palette: p,
                          keyLabel: '[ ESC ]',
                          label: '오늘로',
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _activeInfo(TermPalette p) => [
        Text('✓ PRO 활성화됨', style: termStyle(p.tag, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        _tip(p, 'theme amber', '테마 바꾸기'),
        _tip(p, 'crt on', '주사선 효과'),
        const SizedBox(height: 6),
        if (_hasWidgets) Text('위젯: 홈 화면 길게 누르기 → + → diary.exe', style: termStyle(p.dim, size: 13)),
      ];

  List<Widget> _buyInfo(TermPalette p, ProController? pro) {
    final String status;
    if (pro == null || !pro.available) {
      status = '스토어에 연결되지 않았어요.';
    } else if (pro.price == null) {
      status = '가격을 불러오는 중...';
    } else {
      status = '가격 ${pro.price} · 한 번만 결제';
    }
    return [
      Text(status, style: termStyle(p.fg, size: 13)),
      Text('같은 Apple ID 로는 다른 기기에서도 복원할 수 있어요.', style: termStyle(p.dim, size: 13)),
    ];
  }

  Widget _tip(TermPalette p, String cmd, String desc) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            SizedBox(width: 120, child: Text(cmd, style: termStyle(p.cmd, size: 13))),
            Expanded(child: Text(desc, style: termStyle(p.dim, size: 13))),
          ],
        ),
      );
}

/// 세 테마를 나란히 보여주는 미리보기.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final (i, id) in const ['cmd', 'phosphor', 'amber'].indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _swatch(TermPalette.of(id))),
          ],
        ],
      ),
    );
  }

  Widget _swatch(TermPalette t) => Container(
        height: 72,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.id, maxLines: 1, overflow: TextOverflow.clip, style: termStyle(t.hi, size: 11)),
            const Spacer(),
            Text('■ 한 줄', maxLines: 1, overflow: TextOverflow.clip, style: termStyle(t.tag, size: 11)),
            Text('C:\\>_', maxLines: 1, overflow: TextOverflow.clip, style: termStyle(t.fg, size: 11)),
          ],
        ),
      );
}
