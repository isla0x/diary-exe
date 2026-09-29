import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Brightness;
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/commands.dart';
import '../pro/pro_controller.dart';
import '../theme/term_palette.dart';

/// 명령어 실행 결과로 열어야 할 화면.
typedef RouteRequest = ({String route, String? query});

/// 앱 상태. 명령어를 실행하고 기기에 저장한다.
class DiaryStore extends ChangeNotifier {
  DiaryStore({DateTime Function()? clock, this.pro}) : _clock = clock ?? DateTime.now {
    pro?.addListener(notifyListeners);
  }

  static const _key = 'diary_exe_state_v1';
  static const _maxLog = 4;
  static const _maxHistory = 50;

  final DateTime Function() _clock;

  /// PRO 결제 상태. 없으면 무료로 취급한다.
  final ProController? pro;

  DiaryData _data = const DiaryData();
  SharedPreferences? _prefs;

  final List<LogLine> _log = [
    const LogLine(LogKind.info, '그냥 입력하면 오늘 한 줄로 저장돼요.'),
  ];
  final List<String> _history = [];

  DiaryData get data => _data;
  List<LogLine> get log => List.unmodifiable(_log);
  List<String> get history => List.unmodifiable(_history);
  bool get isPro => pro?.isPro ?? false;

  /// 폰의 다크/라이트 설정.
  Brightness _systemBrightness = Brightness.dark;
  Brightness get systemBrightness => _systemBrightness;
  set systemBrightness(Brightness value) {
    if (value == _systemBrightness) return;
    _systemBrightness = value;
    notifyListeners();
  }

  /// 지금 밝은 모드로 보여야 하는지 (mode + 폰 설정).
  bool get lightMode => switch (_data.mode) {
        'light' => true,
        'dark' => false,
        _ => _systemBrightness == Brightness.light,
      };

  /// 실제로 쓰는 테마 이름. PRO 가 아니면 저장된 테마와 관계없이 cmd.
  String get themeId => isPro ? _data.theme : freeTheme;

  /// 밝은 모드는 cmd 테마에만 적용된다.
  TermPalette get palette => TermPalette.of(themeId, light: lightMode);
  bool get crtOn => isPro && _data.crt;
  DateTime now() => _clock();

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) return;
    try {
      _data = DiaryData.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (e) {
      debugPrint('diary.exe: 저장된 데이터를 읽지 못했어요. ($e)');
    }
  }

  /// 명령어를 실행하고, 열어야 할 화면이 있으면 알려준다.
  RouteRequest? run(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    _history.add(s);
    if (_history.length > _maxHistory) _history.removeAt(0);

    // 디버그 빌드 전용: 결제 없이 PRO 켜고 끄기.
    if (kDebugMode && pro != null && s.toLowerCase() == 'pro --dev') {
      pro!.debugToggle();
      _appendLog([
        LogLine(LogKind.cmd, 'C:\\diary> $s'),
        LogLine(LogKind.info, '[dev] PRO ${pro!.isPro ? 'on' : 'off'}'),
      ]);
      notifyListeners();
      return null;
    }

    final out = runCommand(_data, s, _clock(), pro: isPro);
    final changed = !identical(out.data, _data);
    _data = out.data;
    if (out.clearLog) {
      _log.clear();
    } else {
      _appendLog(out.lines);
    }
    notifyListeners();
    if (changed) _save();
    return out.route == null ? null : (route: out.route!, query: out.query);
  }

  /// 날짜가 바뀌었을 때 등, 데이터 변화 없이 다시 그리게 한다.
  void refresh() => notifyListeners();

  void _appendLog(List<LogLine> lines) {
    _log.addAll(lines);
    if (_log.length > _maxLog) _log.removeRange(0, _log.length - _maxLog);
  }

  void _save() {
    _prefs?.setString(_key, jsonEncode(_data.toJson()));
  }

  @override
  void dispose() {
    pro?.removeListener(notifyListeners);
    super.dispose();
  }
}
