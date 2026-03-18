import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Widget Localization Helper

private enum WidgetStrings {
    static let localizationMap: [String: [String: String]] = [
        "tr": [
            "today": "Bugün",
            "totalFocus": "Toplam odak",
            "sessions": "Seans",
            "streak": "Seri",
            "days": "gün",
            "minutes": "dk",
            "active": "Aktif",
            "done": "Bitti",
            "description": "Günlük odak ilerlemeni anlık gör."
        ],
        "en": [
            "today": "Today",
            "totalFocus": "Total focus",
            "sessions": "Sessions",
            "streak": "Streak",
            "days": "days",
            "minutes": "min",
            "active": "Active",
            "done": "Done",
            "description": "See your daily focus progress at a glance."
        ],
        "zh-Hans": [
            "today": "今天",
            "totalFocus": "总专注",
            "sessions": "次数",
            "streak": "连续",
            "days": "天",
            "minutes": "分钟",
            "active": "进行中",
            "done": "完成",
            "description": "一眼查看每日专注进度。"
        ]
    ]

    static func localized(_ key: String) -> String {
        let defaults = UserDefaults(suiteName: "group.vedatdaglar.FocusGarden")
        let storedLanguage = defaults?.string(forKey: "appLanguage") ?? "system"

        var languageCode: String?
        switch storedLanguage {
        case "tr":
            languageCode = "tr"
        case "en":
            languageCode = "en"
        case "zh-Hans":
            languageCode = "zh-Hans"
        default:
            // System default - use device locale
            if let preferredLanguage = Locale.preferredLanguages.first {
                if preferredLanguage.hasPrefix("tr") {
                    languageCode = "tr"
                } else if preferredLanguage.hasPrefix("zh") {
                    languageCode = "zh-Hans"
                } else {
                    languageCode = "en"
                }
            } else {
                languageCode = "en"
            }
        }

        guard let language = languageCode,
              let strings = localizationMap[language],
              let value = strings[key] else {
            // Fallback to English
            return localizationMap["en"]?[key] ?? key
        }
        return value
    }
}

private struct FocusEntry: TimelineEntry {
    let date: Date
    let totalFocusMinutes: Int
    let completedSessions: Int
    let focusStreak: Int
}

private struct FocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusEntry {
        FocusEntry(date: .now, totalFocusMinutes: 45, completedSessions: 3, focusStreak: 2)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusEntry>) -> Void) {
        let entry = loadEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadEntry() -> FocusEntry {
        let defaults = UserDefaults(suiteName: "group.vedatdaglar.FocusGarden")
        return FocusEntry(
            date: .now,
            totalFocusMinutes: defaults?.integer(forKey: "totalFocusMinutes") ?? 0,
            completedSessions: defaults?.integer(forKey: "completedSessions") ?? 0,
            focusStreak: defaults?.integer(forKey: "focusStreak") ?? 0
        )
    }
}

private struct FocusGardenWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    var entry: FocusProvider.Entry

    var body: some View {
        ZStack(alignment: .topLeading) {
            widgetBackground

            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    private var widgetBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.11),
                    Color(red: 0.07, green: 0.15, blue: 0.14),
                    Color(red: 0.08, green: 0.20, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.55, green: 0.88, blue: 0.80).opacity(0.14))
                .frame(width: family == .systemSmall ? 120 : 170, height: family == .systemSmall ? 120 : 170)
                .blur(radius: 16)
                .offset(x: family == .systemSmall ? 58 : 130, y: family == .systemSmall ? -36 : -42)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: family == .systemSmall ? 140 : 190, height: family == .systemSmall ? 140 : 190)
                .blur(radius: 20)
                .offset(x: family == .systemSmall ? -50 : -70, y: family == .systemSmall ? 70 : 88)
        }
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.totalFocusMinutes) \(WidgetStrings.localized("minutes"))")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(WidgetStrings.localized("totalFocus"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))

                    progressStrip
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    statPill(title: WidgetStrings.localized("sessions"), value: "\(entry.completedSessions)")
                    statPill(title: WidgetStrings.localized("streak"), value: "\(entry.focusStreak) \(WidgetStrings.localized("days"))")
                }
                .frame(width: 124)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.84, green: 0.97, blue: 0.90))

                Spacer()

                Text(WidgetStrings.localized("today"))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.62))
            }

            Spacer()

            Text("\(entry.totalFocusMinutes) \(WidgetStrings.localized("minutes"))")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(WidgetStrings.localized("totalFocus"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.74))
                .padding(.top, 2)

            Spacer()

            HStack(spacing: 8) {
                compactMetric(title: WidgetStrings.localized("sessions"), value: "\(entry.completedSessions)")
                compactMetric(title: WidgetStrings.localized("streak"), value: "\(entry.focusStreak)")
            }
        }
        .padding(16)
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.84, green: 0.97, blue: 0.90))

                Text("MindIsland")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.92, green: 0.99, blue: 0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer()

            Text(WidgetStrings.localized("today"))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
        }
    }

    private var progressStrip: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(index < min(entry.focusStreak, 7) ? Color(red: 0.79, green: 0.97, blue: 0.88) : Color.white.opacity(0.10))
                    .frame(height: 6)
            }
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.86, green: 0.98, blue: 0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func compactMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.83, green: 0.97, blue: 0.90))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct FocusGardenWidget: Widget {
    let kind: String = "FocusGardenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusProvider()) { entry in
            FocusGardenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MindIsland")
        .description(WidgetStrings.localized("description"))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@available(iOSApplicationExtension 16.2, *)
struct FocusGardenLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionActivityAttributes.self) { context in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.11),
                        Color(red: 0.09, green: 0.18, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("MindIsland", systemImage: "leaf.fill")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.84, green: 0.97, blue: 0.90))

                        Spacer()

                        Text(context.state.isRunning ? WidgetStrings.localized("active") : WidgetStrings.localized("done"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.66))
                    }

                    Text(context.state.sessionTitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.70))

                    HStack(alignment: .center, spacing: 14) {
                        countdownText(for: context)
                            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)

                        if context.state.isRunning {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(red: 0.84, green: 0.97, blue: 0.90))
                                .symbolEffect(.pulse, options: .repeating)
                        }
                    }

                    if context.state.isRunning {
                        ProgressView(timerInterval: context.state.startDate...context.state.endDate, countsDown: false)
                            .progressViewStyle(.linear)
                            .tint(Color(red: 0.72, green: 0.96, blue: 0.86))
                    }
                }
                .padding(18)
            }
            .activityBackgroundTint(Color(red: 0.06, green: 0.10, blue: 0.10))
            .activitySystemActionForegroundColor(Color(red: 0.84, green: 0.97, blue: 0.90))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(Color(red: 0.84, green: 0.97, blue: 0.90))
                        .symbolEffect(.pulse, options: .repeating)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownText(for: context)
                        .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.sessionTitle)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.80))

                        Spacer()

                        if context.state.isRunning {
                            ProgressView(timerInterval: context.state.startDate...context.state.endDate, countsDown: false)
                                .progressViewStyle(.linear)
                                .frame(width: 90)
                                .tint(Color(red: 0.72, green: 0.96, blue: 0.86))
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color(red: 0.84, green: 0.97, blue: 0.90))
            } compactTrailing: {
                compactCountdownText(for: context)
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color(red: 0.84, green: 0.97, blue: 0.90))
            }
            .contentMargins(.all, 12, for: .expanded)
            .keylineTint(Color(red: 0.70, green: 0.95, blue: 0.86))
        }
    }

    @ViewBuilder
    private func countdownText(for context: ActivityViewContext<FocusSessionActivityAttributes>) -> some View {
        if context.state.isRunning {
            Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                .multilineTextAlignment(.leading)
        } else {
            Text("00:00")
        }
    }

    @ViewBuilder
    private func compactCountdownText(for context: ActivityViewContext<FocusSessionActivityAttributes>) -> some View {
        if context.state.isRunning {
            Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
        } else {
            Text("0 \(WidgetStrings.localized("minutes"))")
        }
    }
}

@main
struct FocusGardenWidgetBundle: WidgetBundle {
    var body: some Widget {
        FocusGardenWidget()
        if #available(iOSApplicationExtension 16.2, *) {
            FocusGardenLiveActivity()
        }
    }
}
