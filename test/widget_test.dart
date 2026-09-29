import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diary_exe/main.dart';
import 'package:diary_exe/pro/pro_controller.dart';
import 'package:diary_exe/state/diary_store.dart';

void main() {
  Future<DiaryStore> boot(WidgetTester tester, {ProController? pro, Map<String, Object> prefs = const {}}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(prefs);
    final store = DiaryStore(clock: () => DateTime(2026, 9, 29, 21), pro: pro);
    await store.load();

    await tester.pumpWidget(DiaryExeApp(store: store));
    expect(find.text('diary.exe'), findsOneWidget);

    // 부팅 애니메이션이 끝나고 시작 버튼이 나타난다.
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return store;
  }

  Future<void> type(WidgetTester tester, String cmd) async {
    await tester.enterText(find.byType(TextField), cmd);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
  }

  testWidgets('부팅 → 메인 → 오늘 한 줄 저장 → 키보드', (tester) async {
    final store = await boot(tester, prefs: {
      'diary_exe_state_v1': '{"entries":{"2025-09-29":"이사 박스 아직도 다 못 풀었다","2026-09-28":"노을"}}',
    });

    expect(find.text('아직 안 썼어요'), findsOneWidget);
    expect(find.text('이사 박스 아직도 다 못 풀었다'), findsOneWidget); // 1년 전 오늘
    expect(find.text('1년 전 오늘 · 2025.09.29 월'), findsOneWidget);

    // 입력하는 동안 글자 수가 보인다.
    await tester.enterText(find.byType(TextField), '점심 국밥');
    await tester.pump();
    expect(find.text('5/80'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(store.data.entries['2026-09-29'], '점심 국밥');
    expect(find.text('점심 국밥'), findsOneWidget);
    expect(find.text('아직 안 썼어요'), findsNothing);
    expect(find.textContaining('저장했어요'), findsOneWidget);

    // 한 번 더 쓰면 거절된다.
    await type(tester, '또 쓰기');
    expect(find.textContaining('이미 있어요'), findsOneWidget);

    // 어제 줄을 누르면 edit 가 채워진다.
    await tester.tap(find.text('노을'));
    await tester.pump();
    expect(find.text('edit 09.28 노을'), findsOneWidget);

    // 칩을 누르면 키보드가 유지되고, 입력 영역 밖을 탭하면 내려간다.
    await tester.tap(find.text('grep'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.text('DIARY [Version 1.0.0]'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('cal → 날짜 고르기 → 고쳐 쓰기로 돌아오기', (tester) async {
    await boot(tester, prefs: {
      'diary_exe_state_v1': '{"entries":{"2026-09-15":"커피 끊기 실패"}}',
    });
    await tester.tap(find.text('cal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('cal 2026-09'), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.pump();
    expect(find.text('커피 끊기 실패'), findsOneWidget);

    await tester.tap(find.text('고쳐 쓰기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('edit 09.15 커피 끊기 실패'), findsOneWidget);
  });

  testWidgets('ago 화면에서 grep', (tester) async {
    await boot(tester, prefs: {
      'diary_exe_state_v1': '{"entries":{"2026-09-15":"커피 끊기 실패","2026-08-01":"카페 커피","2026-07-01":"산책"}}',
    });
    await tester.tap(find.text('ago'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('지난해 오늘의 기록은 아직 없어요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '커피');
    await tester.pump();
    expect(find.text('2줄 찾음'), findsOneWidget);
  });

  testWidgets('무료: 테마 잠김 → upgrade 화면 → (dev) PRO 켜면 테마 변경', (tester) async {
    final pro = ProController(); // init() 을 부르지 않으면 스토어에 연결하지 않는다.
    final store = await boot(tester, pro: pro);

    expect(find.text('PRO'), findsOneWidget);
    await type(tester, 'theme amber');
    expect(find.text('Access is denied.'), findsOneWidget);
    expect(store.palette.id, 'cmd');

    await type(tester, 'upgrade');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('diary.exe PRO'), findsOneWidget);
    expect(find.text('스토어에 연결되지 않았어요.'), findsOneWidget);

    await tester.tap(find.text('[ ESC ] 닫기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await type(tester, 'pro --dev');
    expect(store.isPro, isTrue);
    await type(tester, 'theme amber');
    expect(store.palette.id, 'amber');
    expect(find.text('PRO'), findsNothing);
  });
}
