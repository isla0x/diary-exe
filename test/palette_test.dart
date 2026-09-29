import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diary_exe/pro/pro_controller.dart';
import 'package:diary_exe/state/diary_store.dart';
import 'package:diary_exe/theme/term_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mode auto 는 폰 설정을, light/dark 는 고정값을 따른다 (cmd)', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DiaryStore();
    await store.load();

    store.systemBrightness = Brightness.light;
    expect(store.palette, same(TermPalette.cmdLight));
    store.systemBrightness = Brightness.dark;
    expect(store.palette, same(TermPalette.cmdTheme));

    store.run('mode light');
    expect(store.palette.isLight, isTrue);
    store.run('mode dark');
    store.systemBrightness = Brightness.light;
    expect(store.palette.isLight, isFalse);
  });

  test('phosphor · amber 는 밝은 모드에서도 어둡다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = DiaryStore(pro: ProController());
    await store.load();
    store.run('pro --dev');
    store.run('mode light');
    store.run('theme amber');
    expect(store.palette, same(TermPalette.amber));
    expect(store.palette.isLight, isFalse);
  });

  test('저장한 일기는 다시 불러온다', () async {
    SharedPreferences.setMockInitialValues({});
    final a = DiaryStore(clock: () => DateTime(2026, 9, 29, 9));
    await a.load();
    a.run('한 줄');
    final b = DiaryStore();
    await b.load();
    expect(b.data.entries['2026-09-29'], '한 줄');
  });

  test('한글 본문은 단어 간격을 줄인다', () {
    expect(termStyle(const Color(0xFFFFFFFF), size: 15, ko: true).wordSpacing, closeTo(-4.5, 0.001));
    expect(termStyle(const Color(0xFFFFFFFF)).wordSpacing, isNull);
  });
}
