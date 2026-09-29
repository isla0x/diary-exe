// diary.exe 홈 화면 · 잠금화면 위젯
//
// 앱(Flutter)이 App Group 저장소에 "snapshot" 키로 JSON 을 넣으면 이 위젯이 읽어서 그린다.
// JSON 모양은 lib/widget_sync.dart 의 widgetSnapshot() 과 같다.
//
// 지원 크기
//   홈 화면   : 작게 / 중간
//   잠금 화면 : 직사각형 / 원형 / 시계 위 한 줄
//
// 앱을 열지 않아도 자정이 지나면 "오늘"이 바뀌어야 하므로, 스냅샷의 날짜와
// 위젯이 그리는 날짜가 다르면 DayView 에서 오늘 기록 · 연속 · 이번 주를 다시 계산한다.

import SwiftUI
import WidgetKit

private let appGroupId = "group.com.isla0x.diaryexe"
private let snapshotKey = "snapshot"

// MARK: - 데이터

struct AgoLine: Decodable, Hashable {
    /// 연도
    let y: Int
    /// 그날 한 줄
    let t: String
}

struct DiarySnapshot: Decodable {
    let pro: Bool?
    let theme: String
    /// auto | light | dark (cmd 테마에만 적용)
    let mode: String?
    /// 스냅샷을 만든 날 "YYYY-MM-DD"
    let date: String
    /// 그날 쓴 한 줄 (안 썼으면 nil)
    let today: String?
    let streak: Int
    let month: Int
    /// 이번 주 월~일: 1 씀, 0 안 씀, -1 아직 안 온 날
    let week: [Int]
    /// "MM-DD" → 가장 최근 해의 같은 날 기록 (오늘과 내일 것만 들어 있다)
    let ago: [String: AgoLine]

    var isPro: Bool { pro ?? false }

    func isLight(_ scheme: ColorScheme) -> Bool {
        switch mode ?? "auto" {
        case "light": return true
        case "dark": return false
        default: return scheme == .light
        }
    }

    /// 밝은 모드는 cmd 테마에만 적용된다.
    func colors(_ scheme: ColorScheme) -> TermColors {
        TermColors.of(isPro ? theme : "cmd", light: isLight(scheme))
    }

    static let empty = DiarySnapshot(
        pro: false, theme: "cmd", mode: "auto", date: "", today: nil, streak: 0, month: 0,
        week: [], ago: [:]
    )

    /// 위젯 고르는 화면에 보여줄 예시.
    static func sample(on date: Date) -> DiarySnapshot {
        DiarySnapshot(
            pro: true, theme: "cmd", mode: "auto", date: dayKey(date), today: nil, streak: 3, month: 24,
            week: sampleWeek(date),
            ago: [monthDay(date): AgoLine(y: Calendar.current.component(.year, from: date) - 1, t: "이사 박스 아직도 다 못 풀었다")]
        )
    }

    private static func sampleWeek(_ date: Date) -> [Int] {
        let idx = weekdayIndex(date)
        return (0..<7).map { $0 < idx ? 1 : ($0 == idx ? 0 : -1) }
    }

    static func load() -> DiarySnapshot {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let raw = defaults.string(forKey: snapshotKey),
            let data = raw.data(using: .utf8),
            let snap = try? JSONDecoder().decode(DiarySnapshot.self, from: data)
        else { return .empty }
        return snap
    }
}

/// 위젯이 실제로 그리는 하루. 스냅샷이 어제 것이어도 오늘 기준으로 맞춘다.
struct DayView {
    let date: Date
    let today: String?
    let streak: Int
    let month: Int
    let week: [Int]
    let ago: AgoLine?

    init(snap: DiarySnapshot, date: Date) {
        let cal = Calendar.current
        self.date = date
        let key = dayKey(date)
        ago = snap.ago[monthDay(date)]
        let snapDate = parseDayKey(snap.date)

        if snap.date == key {
            today = snap.today
            streak = snap.streak
            month = snap.month
            week = snap.week.count == 7 ? snap.week : DayView.freshWeek(date)
            return
        }

        today = nil
        if let s = snapDate, let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: date)),
           cal.isDate(s, inSameDayAs: yesterday) {
            // 어제 스냅샷: 어제 썼으면 연속이 이어지고 있다.
            streak = snap.today == nil ? 0 : snap.streak
        } else {
            streak = 0
        }
        if let s = snapDate, cal.isDate(s, equalTo: date, toGranularity: .month) {
            month = snap.month
        } else {
            month = 0
        }
        if let s = snapDate, snap.week.count == 7, cal.isDate(mondayOf(s), inSameDayAs: mondayOf(date)),
           weekdayIndex(s) <= weekdayIndex(date) {
            let idx = weekdayIndex(date)
            week = snap.week.enumerated().map { i, v in i <= idx && v < 0 ? 0 : v }
        } else {
            week = DayView.freshWeek(date)
        }
    }

    var written: Bool { today != nil }

    var agoYears: Int {
        guard let a = ago else { return 0 }
        return Calendar.current.component(.year, from: date) - a.y
    }

    private static func freshWeek(_ date: Date) -> [Int] {
        let idx = weekdayIndex(date)
        return (0..<7).map { $0 <= idx ? 0 : -1 }
    }
}

// MARK: - 날짜 도우미

private func formatter(_ format: String) -> DateFormatter {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.calendar = Calendar(identifier: .gregorian)
    f.dateFormat = format
    return f
}

/// "2026-09-29"
func dayKey(_ date: Date) -> String { formatter("yyyy-MM-dd").string(from: date) }

/// "09-29"
func monthDay(_ date: Date) -> String { formatter("MM-dd").string(from: date) }

func parseDayKey(_ key: String) -> Date? { formatter("yyyy-MM-dd").date(from: key) }

/// 월요일 0 … 일요일 6
func weekdayIndex(_ date: Date) -> Int {
    (Calendar(identifier: .gregorian).component(.weekday, from: date) + 5) % 7
}

/// 그 주 월요일 0시. (나라마다 주의 시작 요일이 달라서 직접 계산한다)
func mondayOf(_ date: Date) -> Date {
    let cal = Calendar.current
    let start = cal.startOfDay(for: date)
    return cal.date(byAdding: .day, value: -weekdayIndex(date), to: start) ?? start
}

/// "09.29 화"
private func shortDate(_ date: Date) -> String { formatter("MM.dd E").string(from: date) }

/// ■■■□□□□
private func streakBar(_ streak: Int, width: Int = 7) -> String {
    let n = min(max(streak, 0), width)
    return String(repeating: "■", count: n) + String(repeating: "□", count: width - n)
}

// MARK: - 색 (앱의 theme 명령어와 같은 팔레트)

struct TermColors {
    let bg, bar, fg, hi, dim, ok, tag, cmd, warn, line: Color

    static func of(_ id: String, light: Bool = false) -> TermColors {
        switch id {
        case "phosphor":
            return TermColors(bg: Color(hex: 0x050A06), bar: Color(hex: 0x0B170E), fg: Color(hex: 0x4AF626),
                              hi: Color(hex: 0xB8FFA8), dim: Color(hex: 0x2E9A1A), ok: Color(hex: 0xB8FFA8),
                              tag: Color(hex: 0xE8FF7A), cmd: Color(hex: 0x7CFFCB), warn: Color(hex: 0xFF6B5A),
                              line: Color(hex: 0x16361D))
        case "amber":
            return TermColors(bg: Color(hex: 0x0F0A02), bar: Color(hex: 0x1C1305), fg: Color(hex: 0xFFB000),
                              hi: Color(hex: 0xFFE3A3), dim: Color(hex: 0xB07A00), ok: Color(hex: 0xFFE3A3),
                              tag: Color(hex: 0xFFD166), cmd: Color(hex: 0xFFCF70), warn: Color(hex: 0xFF6B3D),
                              line: Color(hex: 0x3A2A0A))
        default:
            if light {
                // 종이에 출력한 터미널 (앱의 cmdLight 와 같은 색)
                return TermColors(bg: Color(hex: 0xF5F2E8), bar: Color(hex: 0xE8E4D6), fg: Color(hex: 0x2B2B2B),
                                  hi: Color(hex: 0x111111), dim: Color(hex: 0x6B6B6B), ok: Color(hex: 0x0B7A0B),
                                  tag: Color(hex: 0x7A5F00), cmd: Color(hex: 0x0B6E8A), warn: Color(hex: 0xC0282F),
                                  line: Color(hex: 0xD6D1C2))
            }
            return TermColors(bg: Color(hex: 0x0C0C0C), bar: Color(hex: 0x1A1A1A), fg: Color(hex: 0xCCCCCC),
                              hi: Color(hex: 0xF2F2F2), dim: Color(hex: 0xA3A3A3), ok: Color(hex: 0x16C60C),
                              tag: Color(hex: 0xF9F1A5), cmd: Color(hex: 0x61D6D6), warn: Color(hex: 0xE74856),
                              line: Color(hex: 0x2A2A2A))
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
}

/// 한글 본문: 고정폭은 한글 사이가 너무 벌어져서 기본 글꼴을 쓴다.
private func prose(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight)
}

// MARK: - 타임라인

struct DiaryEntry: TimelineEntry {
    let date: Date
    let snap: DiarySnapshot
    var day: DayView { DayView(snap: snap, date: date) }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DiaryEntry {
        DiaryEntry(date: .now, snap: .sample(on: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (DiaryEntry) -> Void) {
        // 위젯 고르는 화면에서는 어떤 모습인지 보이도록 예시를 보여준다.
        let snap = context.isPreview ? DiarySnapshot.sample(on: .now) : DiarySnapshot.load()
        completion(DiaryEntry(date: .now, snap: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DiaryEntry>) -> Void) {
        let now = Date()
        let snap = DiarySnapshot.load()
        // 자정에 날짜가 바뀐 화면을 미리 넣어 둔다. 일기를 쓰면 앱이 바로 새로 그리게 한다.
        let midnight = Calendar.current.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)
        let entries = [DiaryEntry(date: now, snap: snap), DiaryEntry(date: midnight, snap: snap)]
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
    }
}

// MARK: - 홈 화면 위젯

struct TitleStrip: View {
    let c: TermColors
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(">_").font(mono(11, .bold)).foregroundColor(c.hi)
            Text("diary.exe").font(mono(11)).foregroundColor(c.hi)
            Spacer(minLength: 4)
            if let t = trailing {
                Text(t).font(mono(10)).foregroundColor(c.dim).lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(c.bar)
    }
}

/// 깜빡이지 않는 프롬프트: C:\diary>_
struct PromptLine: View {
    let c: TermColors
    var size: CGFloat = 13

    var body: some View {
        (Text("C:\\diary>").foregroundColor(c.hi) + Text("_").foregroundColor(c.tag))
            .font(mono(size))
            .lineLimit(1)
    }
}

struct SmallView: View {
    let day: DayView
    let c: TermColors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TitleStrip(c: c)
            VStack(alignment: .leading, spacing: 4) {
                Text(shortDate(day.date)).font(mono(11)).foregroundColor(c.tag)
                if let text = day.today {
                    Text(text).font(prose(14, .medium)).foregroundColor(c.hi).lineLimit(4)
                } else {
                    PromptLine(c: c)
                    Text("오늘 한 줄, 아직이에요").font(prose(12)).foregroundColor(c.dim).lineLimit(2)
                }
                Spacer(minLength: 0)
                (Text(streakBar(day.streak)).foregroundColor(c.tag) + Text(" 연속 \(day.streak)일").foregroundColor(c.dim))
                    .font(mono(10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
    }
}

struct MediumView: View {
    let day: DayView
    let c: TermColors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TitleStrip(c: c, trailing: day.ago == nil ? shortDate(day.date) : "cat --ago")
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let ago = day.ago {
                        Text("\(day.agoYears)년 전 오늘 · \(String(ago.y))").font(mono(10)).foregroundColor(c.tag)
                        Text(ago.t).font(prose(15, .medium)).foregroundColor(c.hi).lineLimit(3)
                    } else if let text = day.today {
                        Text("오늘 · \(shortDate(day.date))").font(mono(10)).foregroundColor(c.tag)
                        Text(text).font(prose(15, .medium)).foregroundColor(c.hi).lineLimit(3)
                    } else {
                        Text(shortDate(day.date)).font(mono(10)).foregroundColor(c.tag)
                        Text("하루에 한 줄이면 충분해.").font(prose(14)).foregroundColor(c.hi).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if day.written {
                        (Text("✓ ").foregroundColor(c.tag) + Text("오늘 한 줄 저장됨").foregroundColor(c.dim))
                            .font(prose(11))
                            .lineLimit(1)
                    } else {
                        HStack(spacing: 4) {
                            PromptLine(c: c, size: 11)
                            Text("오늘은?").font(prose(11)).foregroundColor(c.dim)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle().fill(c.line).frame(width: 1)

                VStack(alignment: .leading, spacing: 4) {
                    Text("이번 주").font(prose(10)).foregroundColor(c.dim)
                    WeekGrid(week: day.week, c: c)
                    Spacer(minLength: 0)
                    (Text("연속 ").foregroundColor(c.hi) + Text("\(day.streak)").foregroundColor(c.tag) + Text("일").foregroundColor(c.hi))
                        .font(prose(11))
                    Text("\(Calendar.current.component(.month, from: day.date))월 \(day.month)줄")
                        .font(prose(10)).foregroundColor(c.dim)
                }
                .frame(width: 100, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
    }
}

struct WeekGrid: View {
    let week: [Int]
    let c: TermColors
    private let names = ["월", "화", "수", "목", "금", "토", "일"]

    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                ForEach(0..<7, id: \.self) { i in
                    Text(names[i]).font(prose(9)).foregroundColor(c.dim)
                }
            }
            GridRow {
                ForEach(0..<7, id: \.self) { i in
                    let v = i < week.count ? week[i] : -1
                    Text(v > 0 ? "■" : (v == 0 ? "·" : " "))
                        .font(mono(10))
                        .foregroundColor(v > 0 ? c.tag : c.dim)
                }
            }
        }
    }
}

// MARK: - 잠금화면 위젯

/// 직사각형: 1년 전 오늘이 있으면 그것, 없으면 오늘 상태.
struct LockRectView: View {
    let day: DayView

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let ago = day.ago {
                Text("\(day.agoYears)년 전 오늘").font(prose(11)).opacity(0.75)
                Text(ago.t).font(prose(13, .semibold)).lineLimit(2).widgetAccentable()
            } else if let text = day.today {
                Text("C:\\diary> 오늘").font(mono(11)).opacity(0.75)
                Text(text).font(prose(13, .semibold)).lineLimit(2).widgetAccentable()
            } else {
                Text("C:\\diary>_").font(mono(13, .bold)).widgetAccentable()
                Text("오늘 한 줄, 아직").font(prose(12))
                Text("연속 \(day.streak)일").font(prose(11)).opacity(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 원형: 연속 기록 일수
struct LockCircleView: View {
    let day: DayView

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(day.written ? ">_" : "_").font(mono(10))
                Text("\(day.streak)").font(mono(20, .bold)).widgetAccentable()
                Text("일째").font(prose(9)).opacity(0.75)
            }
        }
    }
}

/// 시계 위 한 줄
struct LockInlineView: View {
    let day: DayView

    var body: some View {
        Text(">_ 연속 \(day.streak)일 · 오늘 \(day.written ? "씀" : "아직")")
    }
}

// MARK: - PRO 가 아닐 때

struct LockedHomeView: View {
    let c: TermColors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TitleStrip(c: c)
            VStack(alignment: .leading, spacing: 4) {
                (Text("C:\\diary> ").foregroundColor(c.dim) + Text("widget").foregroundColor(c.cmd))
                    .font(mono(11))
                Text("Access is denied.").font(mono(12, .bold)).foregroundColor(c.warn)
                Text("위젯은 PRO 기능이에요.").font(prose(12)).foregroundColor(c.fg)
                Spacer(minLength: 0)
                (Text("앱에서 ").foregroundColor(c.dim) + Text("upgrade").foregroundColor(c.cmd) + Text(" 입력").foregroundColor(c.dim))
                    .font(prose(11))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
    }
}

struct LockedAccessoryView: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(">_").font(mono(11, .bold))
                    Text("PRO").font(mono(12, .bold))
                }
            }
            .widgetAccentable()
        case .accessoryInline:
            Text(">_ diary.exe · PRO 필요")
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text("C:\\diary> widget").font(mono(12, .bold)).widgetAccentable()
                Text("Access is denied.").font(mono(12))
                Text("앱에서 upgrade").font(prose(12))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 위젯 정의

struct DiaryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: DiaryEntry

    private var colors: TermColors { entry.snap.colors(scheme) }

    var body: some View {
        if entry.snap.isPro {
            unlocked
        } else {
            locked
        }
    }

    @ViewBuilder
    private var locked: some View {
        switch family {
        case .accessoryRectangular, .accessoryCircular, .accessoryInline:
            LockedAccessoryView(family: family).containerBackground(for: .widget) { Color.clear }
        default:
            LockedHomeView(c: colors).containerBackground(for: .widget) { colors.bg }
        }
    }

    @ViewBuilder
    private var unlocked: some View {
        let day = entry.day
        switch family {
        case .accessoryRectangular:
            LockRectView(day: day).containerBackground(for: .widget) { Color.clear }
        case .accessoryCircular:
            LockCircleView(day: day).containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            LockInlineView(day: day).containerBackground(for: .widget) { Color.clear }
        case .systemMedium:
            MediumView(day: day, c: colors).containerBackground(for: .widget) { colors.bg }
        default:
            SmallView(day: day, c: colors).containerBackground(for: .widget) { colors.bg }
        }
    }
}

struct DiaryWidget: Widget {
    /// Flutter 쪽 WidgetSync.iOSWidgetKind 와 같아야 한다.
    let kind = "DiaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DiaryWidgetView(entry: entry)
        }
        .configurationDisplayName("diary.exe")
        .description("오늘 한 줄과 1년 전 오늘을 cmd 스타일로 보여줘요.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryRectangular, .accessoryCircular, .accessoryInline,
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Xcode 미리보기

#Preview("작게", as: .systemSmall) {
    DiaryWidget()
} timeline: {
    DiaryEntry(date: .now, snap: .sample(on: .now))
}

#Preview("중간", as: .systemMedium) {
    DiaryWidget()
} timeline: {
    DiaryEntry(date: .now, snap: .sample(on: .now))
}

#Preview("잠금 직사각형", as: .accessoryRectangular) {
    DiaryWidget()
} timeline: {
    DiaryEntry(date: .now, snap: .sample(on: .now))
}

#Preview("잠금 원형", as: .accessoryCircular) {
    DiaryWidget()
} timeline: {
    DiaryEntry(date: .now, snap: .sample(on: .now))
}

#Preview("PRO 아님", as: .systemSmall) {
    DiaryWidget()
} timeline: {
    DiaryEntry(date: .now, snap: .empty)
}
