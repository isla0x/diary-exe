import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'logic/commands.dart';
import 'logic/dates.dart';
import 'logic/stats.dart';

/// 홈 화면·잠금화면 위젯(iOS WidgetKit)으로 데이터를 넘긴다.
///
/// 앱과 위젯은 App Group 저장소를 같이 쓴다. Runner 와 DiaryWidget
/// 두 타깃 모두 아래 [appGroupId] 로 App Groups 가 켜져 있어야 한다.
class WidgetSync {
  static const appGroupId = 'group.com.isla0x.diaryexe';
  static const iOSWidgetKind = 'DiaryWidget';
  static const snapshotKey = 'snapshot';

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<void> init() async {
    if (!_supported) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      debugPrint('diary.exe widget: setAppGroupId 실패 ($e)');
    }
  }

  static Future<void> push(DiaryData d, DateTime now, {required bool pro}) async {
    if (!_supported) return;
    try {
      await HomeWidget.saveWidgetData<String>(snapshotKey, jsonEncode(widgetSnapshot(d, now, pro: pro)));
      await HomeWidget.updateWidget(iOSName: iOSWidgetKind);
    } catch (e) {
      // 위젯 타깃이 없거나 App Group 이 꺼져 있어도 앱은 계속 동작해야 한다.
      debugPrint('diary.exe widget: 업데이트 실패 ($e)');
    }
  }
}

/// 위젯이 읽는 JSON. Swift 쪽 `DiarySnapshot` 과 키가 같아야 한다.
///
/// 위젯은 앱을 열지 않아도 자정에 날짜가 바뀌므로, 오늘과 내일의
/// "N년 전 오늘"을 함께 넘긴다 (`ago` 는 'MM-DD' 키).
Map<String, dynamic> widgetSnapshot(DiaryData d, DateTime now, {bool pro = false}) {
  final today = dayOf(now);
  final stats = DiaryStats.compute(d, today);
  Map<String, dynamic>? agoFor(DateTime day) {
    final past = onThisDay(d, day);
    if (past.isEmpty) return null;
    return {'y': past.first.day.year, 't': past.first.text};
  }

  final tomorrow = addDays(today, 1);
  return {
    'v': 1,
    'pro': pro,
    'theme': pro ? d.theme : freeTheme,
    // 위젯은 auto 일 때 iOS 의 다크/라이트 설정을 직접 따른다.
    'mode': d.mode,
    'date': dateKey(today),
    'today': d.on(today),
    'streak': stats.streak,
    'month': stats.monthCount,
    // 이번 주 월~일: 1 = 씀, 0 = 안 씀, -1 = 아직 안 온 날
    'week': [for (final w in weekMarks(d, today)) w == null ? -1 : (w ? 1 : 0)],
    'ago': {
      for (final day in [today, tomorrow])
        if (agoFor(day) case final a?) dateKey(day).substring(5): a,
    },
  };
}
