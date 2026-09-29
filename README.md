# diary.exe

하루 한 줄, Windows cmd 느낌의 명령어 입력형 일기 앱 (Flutter). [todo.exe](https://github.com/isla0x/todo-exe) 시리즈.

```
C:\diary> 퇴근길 노을이 진짜 예뻤다
저장했어요 → 09.29 화  (15/80)
C:\diary> cat --ago
1년 전 · 이사 박스 아직도 다 못 풀었다
```

## 화면

| 메인 | ago | cal | help · PRO |
| --- | --- | --- | --- |
| 1년 전 오늘 + 이번 주 7줄 + `C:\diary>` 입력창 | 해마다 같은 날 쓴 한 줄 + grep 검색 | 달력(■ 씀 · 안 씀), 연속 기록, 월별 줄 수 | 명령어 설명 / 테마 · 위젯 · CRT 결제 |

## 명령어

| 명령어 | 설명 | 예 |
| --- | --- | --- |
| `echo <한 줄>` | 오늘 한 줄 저장 (80자). 명령어 없이 쳐도 echo | `echo 라떼 맛있음` |
| `edit [날짜] <내용>` | 고쳐 쓰기. 날짜를 붙이면 지난 날 | `edit 어제 늦잠` |
| `rm [날짜]` | 그날 한 줄 지우기 (기본 오늘) | `rm 09.28` |
| `cat [날짜 \| --ago]` | 그날 한 줄 / 지난해 오늘들 | `cat --ago` |
| `grep <단어>` | 전체 검색 | `grep 커피` |
| `ls [YYYY-MM]` | 그 달 줄 수 | `ls 2026-08` |
| `ago` · `cal` · `help` | 화면 열기 | |
| `mode auto\|light\|dark` | 밝기 (cmd 테마, 무료) | |
| `theme cmd\|phosphor\|amber`, `crt on\|off` | PRO | |
| `upgrade` · `restore` | PRO 구매 · 복원 | |

날짜는 `09.28`, `9/28`, `2025-09-29`, `어제`, `그제` 를 알아들어요.

## 위젯 (iOS, PRO)

| 위치 | 크기 | 내용 |
| --- | --- | --- |
| 홈 화면 | 작게 | 오늘 한 줄 (안 썼으면 `C:\diary>_`) + 연속 기록 |
| 홈 화면 | 중간 | 1년 전 오늘 + 이번 주 ■·· + 연속 · 이번 달 줄 수 |
| 잠금화면 | 직사각형 · 원형 · 한 줄 | 1년 전 오늘 / 연속 N일째 / 오늘 씀·아직 |

앱을 열지 않아도 자정에 날짜가 넘어가도록, 스냅샷에 오늘과 내일의 "N년 전 오늘"을 같이 넣어요.

## 개발

```bash
flutter pub get
dart run flutter_launcher_icons   # 아이콘 다시 만들 때만
flutter test
open ios/Runner.xcworkspace      # Xcode 로 실행 · 배포
```

- 번들 ID `com.isla0x.diaryExe`, 위젯 `com.isla0x.diaryExe.DiaryWidget`
- App Group `group.com.isla0x.diaryexe` (Runner, DiaryWidgetExtension 둘 다)
- 인앱 결제 비소모성 `diary_exe_pro`
- 지원 페이지 / 개인정보처리방침: `docs/` (GitHub Pages)

```
lib/
  logic/commands.dart   명령어 해석 · 실행 (순수 Dart)
  logic/stats.dart      연속 기록, 월별 줄 수, 이번 주
  logic/dates.dart      날짜 키 · 날짜 인자 해석
  state/diary_store.dart 상태 + 기기 저장 (shared_preferences)
  screens/              boot · home · ago · cal · help · pro
  widget_sync.dart      위젯 스냅샷 (App Group)
ios/DiaryWidget/        WidgetKit (SwiftUI)
```
