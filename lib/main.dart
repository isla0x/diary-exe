import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pro/pro_controller.dart';
import 'screens/boot_screen.dart';
import 'state/diary_store.dart';
import 'theme/term_palette.dart';
import 'widget_sync.dart';
import 'widgets/term_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final pro = ProController();
  await pro.init();
  final store = DiaryStore(pro: pro);
  await store.load();
  store.systemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;

  // 위젯은 일기나 PRO 상태가 바뀔 때마다 새로 그린다. (store 는 pro 변화도 알려준다)
  await WidgetSync.init();
  void pushWidget() => WidgetSync.push(store.data, store.now(), pro: store.isPro);
  pushWidget();
  store.addListener(pushWidget);

  runApp(DiaryExeApp(store: store));
}

class DiaryExeApp extends StatefulWidget {
  const DiaryExeApp({super.key, required this.store});

  final DiaryStore store;

  @override
  State<DiaryExeApp> createState() => _DiaryExeAppState();
}

class _DiaryExeAppState extends State<DiaryExeApp> with WidgetsBindingObserver {
  DiaryStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.systemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 다시 열었을 때 날짜가 바뀌었을 수 있으니 화면과 위젯을 새로 그린다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) store.refresh();
  }

  /// 폰에서 다크/라이트를 바꾸면 바로 따라간다.
  @override
  void didChangePlatformBrightness() {
    store.systemBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.palette;
        return MaterialApp(
          title: 'diary.exe',
          debugShowCheckedModeBanner: false,
          theme: _theme(p),
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: (p.isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light).copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: p.bar,
              systemNavigationBarIconBrightness: p.isLight ? Brightness.dark : Brightness.light,
            ),
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (store.crtOn)
                  const Positioned.fill(
                    child: IgnorePointer(child: CustomPaint(painter: ScanlinePainter())),
                  ),
              ],
            ),
          ),
          home: BootScreen(store: store),
        );
      },
    );
  }

  ThemeData _theme(TermPalette p) => ThemeData(
        useMaterial3: true,
        brightness: p.isLight ? Brightness.light : Brightness.dark,
        scaffoldBackgroundColor: p.bg,
        fontFamily: monoFamily,
        fontFamilyFallback: monoFallback,
        colorScheme: p.isLight
            ? ColorScheme.light(surface: p.bg, primary: p.tag, secondary: p.cmd, error: p.warn)
            : ColorScheme.dark(surface: p.bg, primary: p.tag, secondary: p.cmd, error: p.warn),
        splashFactory: NoSplash.splashFactory,
        highlightColor: p.fg.withAlpha(30),
        hoverColor: p.fg.withAlpha(16),
        focusColor: p.cmd.withAlpha(48),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: p.tag,
          selectionColor: p.cmd.withAlpha(90),
          selectionHandleColor: p.tag,
        ),
      );
}
