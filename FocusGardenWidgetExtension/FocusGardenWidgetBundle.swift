import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - RGB Color Palette for Widget

private enum WidgetRGB {
    // 3 vibrant RGB neon colors
    static let cyan    = Color(red: 0.00, green: 0.90, blue: 1.00)
    static let magenta = Color(red: 0.92, green: 0.18, blue: 0.78)
    static let green   = Color(red: 0.20, green: 1.00, blue: 0.60)

    // Softer versions
    static let cyanSoft    = Color(red: 0.40, green: 0.95, blue: 1.00)
    static let magentaSoft = Color(red: 1.00, green: 0.50, blue: 0.88)
    static let greenSoft   = Color(red: 0.55, green: 1.00, blue: 0.75)

    // Backgrounds
    static let bgDeep   = Color(red: 0.03, green: 0.03, blue: 0.06)
    static let bgMid    = Color(red: 0.05, green: 0.05, blue: 0.10)
    static let bgCard   = Color(red: 0.08, green: 0.08, blue: 0.14)
    static let textMain = Color(red: 0.95, green: 0.97, blue: 1.00)
    static let textSub  = Color(red: 0.62, green: 0.68, blue: 0.80)
}

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
            return localizationMap["en"]?[key] ?? key
        }
        return value
    }
}

// MARK: - Data

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

// MARK: - Widget Entry View

private struct FocusGardenWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    var entry: FocusProvider.Entry

    var body: some View {
        ZStack {
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
        .widgetURL(URL(string: "focusgarden://"))
    }

    // MARK: - Background with RGB Glow

    private var widgetBackground: some View {
        ZStack {
            // Deep dark base
            LinearGradient(
                colors: [WidgetRGB.bgDeep, WidgetRGB.bgMid],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Cyan glow - top right
            Circle()
                .fill(WidgetRGB.cyan.opacity(0.30))
                .frame(width: family == .systemSmall ? 100 : 160, height: family == .systemSmall ? 100 : 160)
                .blur(radius: family == .systemSmall ? 28 : 40)
                .offset(x: family == .systemSmall ? 50 : 120, y: family == .systemSmall ? -40 : -50)

            // Magenta glow - bottom left
            Circle()
                .fill(WidgetRGB.magenta.opacity(0.22))
                .frame(width: family == .systemSmall ? 90 : 140, height: family == .systemSmall ? 90 : 140)
                .blur(radius: family == .systemSmall ? 24 : 36)
                .offset(x: family == .systemSmall ? -40 : -90, y: family == .systemSmall ? 50 : 50)

            // Green glow - center bottom
            Circle()
                .fill(WidgetRGB.green.opacity(0.16))
                .frame(width: family == .systemSmall ? 80 : 120, height: family == .systemSmall ? 80 : 120)
                .blur(radius: family == .systemSmall ? 20 : 30)
                .offset(x: family == .systemSmall ? 10 : 20, y: family == .systemSmall ? 30 : 40)

            // Subtle glass overlay
            RoundedRectangle(cornerRadius: family == .systemSmall ? 24 : 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(2)
        }
    }

    // MARK: - Medium Layout (Centered & Clean)

    private var mediumLayout: some View {
        HStack(spacing: 0) {
            // Left side - main focus stat
            VStack(spacing: 8) {
                // App header
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WidgetRGB.green)
                    Text("MindIsland")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetRGB.textMain)
                    Spacer()
                    Text(WidgetStrings.localized("today"))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetRGB.textSub)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }

                Spacer(minLength: 4)

                // Big number
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(entry.totalFocusMinutes)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [WidgetRGB.cyanSoft, WidgetRGB.greenSoft],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(WidgetStrings.localized("minutes"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetRGB.textSub)
                        .padding(.bottom, 5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(WidgetStrings.localized("totalFocus"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetRGB.textSub)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // RGB progress strip
                rgbProgressStrip
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 18)
            .padding(.vertical, 16)

            // Right side - stats
            VStack(spacing: 10) {
                rgbStatPill(
                    title: WidgetStrings.localized("sessions"),
                    value: "\(entry.completedSessions)",
                    accentColor: WidgetRGB.cyan
                )
                rgbStatPill(
                    title: WidgetStrings.localized("streak"),
                    value: "\(entry.focusStreak) \(WidgetStrings.localized("days"))",
                    accentColor: WidgetRGB.magenta
                )
            }
            .frame(width: 130)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Small Layout (Centered)

    private var smallLayout: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WidgetRGB.green)
                    Text("MindIsland")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetRGB.textMain)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(WidgetStrings.localized("today"))
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetRGB.textSub)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 6)

            // Main stat - centered
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.totalFocusMinutes)")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [WidgetRGB.cyanSoft, WidgetRGB.greenSoft],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(WidgetStrings.localized("minutes"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetRGB.textSub)
                        .padding(.bottom, 5)
                }

                Text(WidgetStrings.localized("totalFocus"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetRGB.textSub)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 6)

            // Bottom row - sessions and streak
            HStack(spacing: 0) {
                smallMetric(
                    value: "\(entry.completedSessions)",
                    title: WidgetStrings.localized("sessions"),
                    accent: WidgetRGB.cyan
                )

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1)
                    .padding(.vertical, 6)

                smallMetric(
                    value: "\(entry.focusStreak)",
                    title: WidgetStrings.localized("streak"),
                    accent: WidgetRGB.magenta
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [WidgetRGB.cyan.opacity(0.25), WidgetRGB.magenta.opacity(0.20)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 0.8
                    )
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    // MARK: - Subviews

    private var rgbProgressStrip: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                let filled = index < min(entry.focusStreak, 7)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        filled
                            ? LinearGradient(
                                colors: [WidgetRGB.cyan, WidgetRGB.green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.10), Color.white.opacity(0.06)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .frame(height: 5)
                    .shadow(color: filled ? WidgetRGB.cyan.opacity(0.40) : .clear, radius: 4)
            }
        }
    }

    private func rgbStatPill(title: String, value: String, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetRGB.textSub)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetRGB.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(0.28), lineWidth: 0.8)
        )
        .shadow(color: accentColor.opacity(0.12), radius: 8)
    }

    private func smallMetric(value: String, title: String, accent: Color) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetRGB.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(accent.opacity(0.80))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Static Widget

struct FocusGardenWidget: Widget {
    let kind: String = "FocusGardenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusProvider()) { entry in
            FocusGardenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MindIsland")
        .description(WidgetStrings.localized("description"))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Live Activity

@available(iOSApplicationExtension 16.2, *)
struct FocusGardenLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusSessionActivityAttributes.self) { context in
            // Lock screen / notification banner
            ZStack {
                // RGB gradient background
                LinearGradient(
                    colors: [WidgetRGB.bgDeep, WidgetRGB.bgMid],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // RGB glow effects
                Circle()
                    .fill(WidgetRGB.cyan.opacity(0.18))
                    .frame(width: 120, height: 120)
                    .blur(radius: 30)
                    .offset(x: 120, y: -30)

                Circle()
                    .fill(WidgetRGB.magenta.opacity(0.12))
                    .frame(width: 100, height: 100)
                    .blur(radius: 24)
                    .offset(x: -100, y: 20)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("MindIsland", systemImage: "leaf.fill")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(WidgetRGB.green)

                        Spacer()

                        Text(context.state.isRunning ? WidgetStrings.localized("active") : WidgetStrings.localized("done"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(WidgetRGB.textSub)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(
                                    context.state.isRunning
                                        ? WidgetRGB.cyan.opacity(0.15)
                                        : WidgetRGB.green.opacity(0.15)
                                )
                            )
                    }

                    Text(context.state.sessionTitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(WidgetRGB.textSub)

                    HStack(alignment: .center, spacing: 14) {
                        countdownText(for: context)
                            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(WidgetRGB.textMain)

                        if context.state.isRunning {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(WidgetRGB.magenta)
                                .symbolEffect(.pulse, options: .repeating)
                        }
                    }

                }
                .padding(18)
            }
            .activityBackgroundTint(WidgetRGB.bgDeep)
            .activitySystemActionForegroundColor(WidgetRGB.green)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(WidgetRGB.green)
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
                    }
                }
            } compactLeading: {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(WidgetRGB.green)
            } compactTrailing: {
                compactCountdownText(for: context)
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(WidgetRGB.green)
            }
            .contentMargins(.all, 12, for: .expanded)
            .keylineTint(WidgetRGB.cyan)
        }
    }

    @ViewBuilder
    private func countdownText(for context: ActivityViewContext<FocusSessionActivityAttributes>) -> some View {
        if context.state.isRunning {
            Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                .multilineTextAlignment(.leading)
        } else {
            if let total = context.state.dailyTotalMinutes {
                Text(WidgetStrings.localized("done") + " (\(total) " + WidgetStrings.localized("minutes") + ")")
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            } else {
                Text("0" + WidgetStrings.localized("minutes"))
            }
        }
    }

    @ViewBuilder
    private func compactCountdownText(for context: ActivityViewContext<FocusSessionActivityAttributes>) -> some View {
        if context.state.isRunning {
            Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
        } else {
            Text(WidgetStrings.localized("done"))
        }
    }
}

// MARK: - Widget Bundle

@main
struct FocusGardenWidgetBundle: WidgetBundle {
    var body: some Widget {
        FocusGardenWidget()
        if #available(iOSApplicationExtension 16.2, *) {
            FocusGardenLiveActivity()
        }
    }
}
