import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @AppStorage("totalFocusMinutes", store: SharedStore.defaults) private var totalFocusMinutes = 0
    @AppStorage("completedSessions", store: SharedStore.defaults) private var completedSessions = 0
    @AppStorage("focusStreak",       store: SharedStore.defaults) private var focusStreak       = 0

    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [FocusSession]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        heroSection
                        HStack(spacing: 16) {
                            statSquare(title: localized("stats.activeStreak"), value: "\(focusStreak)", icon: "flame.fill", color: AppTheme.accentBreakBright, detail: localized("stats.activeStreak.detail"))
                            statSquare(title: localized("stats.completedSessions"), value: "\(completedSessions)", icon: "checkmark.circle.fill", color: AppTheme.accentBright, detail: localized("stats.completedSessions.detail"))
                        }
                        chartSection
                        categoryDistribution
                        insightCard
                    }
                    .padding(24).padding(.bottom, 36)
                }
            }
            .navigationTitle(localized("stats.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 80, height: 80)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(Circle())

            Text(localized("stats.hero.subtitle"))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 4) {
                Text(localizedFormat("format.minutes", totalFocusMinutes))
                    .font(.system(size: 42, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)
                Text(localized("stats.totalFocus.detail"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity).padding(24)
        .background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    private func statSquare(title: String, value: String, icon: String, color: Color, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)
                Text(title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
            }
            Text(detail).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary).opacity(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
        .background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("stats.weeklyChart.title"))
                .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)

            let data = last7DaysData
            if data.allSatisfy({ $0.minutes == 0 }) {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal").font(.system(size: 32)).foregroundStyle(AppTheme.textSecondary)
                    Text(localized("stats.noData"))
                        .font(.system(size: 14, weight: .medium, design: .rounded)).multilineTextAlignment(.center).foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180).background(AppTheme.cardSoft)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Chart {
                    ForEach(data) { day in
                        BarMark(x: .value("Day", day.label), y: .value("Mins", day.minutes))
                            .foregroundStyle(LinearGradient(colors: [AppTheme.accentBright, AppTheme.accent], startPoint: .top, endPoint: .bottom))
                            .cornerRadius(6)
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) { value in AxisGridLine().foregroundStyle(AppTheme.border); AxisValueLabel().foregroundStyle(AppTheme.textSecondary) } }
                .chartXAxis { AxisMarks { value in AxisValueLabel().foregroundStyle(AppTheme.textSecondary) } }
                .frame(height: 180).padding(.top, 10)
            }
        }
        .padding(20).background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    private var categoryDistribution: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localized("stats.categories"))
                .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)

            let stats = categoryStats
            if stats.isEmpty {
                Text(localized("stats.noData")).font(.system(size: 14)).foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(stats, id: \.category) { stat in
                    HStack {
                        Image(systemName: "circle.fill").font(.system(size: 8)).foregroundStyle(colorForCategory(stat.category))
                        Text(localized("category.\(stat.category)")).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(localizedFormat("format.minutes", stat.minutes)).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 8)
                    Divider().background(AppTheme.border)
                }
            }
        }
        .padding(20).background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1) }
    }

    private func colorForCategory(_ cat: String) -> Color {
        switch cat {
        case "general": return AppTheme.accent
        case "work":    return AppTheme.accentBreakBright
        case "study":   return Color(red: 0.6, green: 0.4, blue: 0.9)
        case "reading": return Color(red: 0.9, green: 0.6, blue: 0.4)
        default:        return Color.gray
        }
    }

    private var categoryStats: [(category: String, minutes: Int)] {
        var dict: [String: Int] = [:]
        for s in sessions where s.completed {
            dict[s.category, default: 0] += s.durationMinutes
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.minutes > $1.minutes }
    }

    private var insightCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "lightbulb.min.fill").font(.system(size: 24)).foregroundStyle(AppTheme.accentBreakBright)
            VStack(alignment: .leading, spacing: 4) {
                Text(localized("stats.insight.title")).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.textPrimary)
                Text(insightText).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(20).background(AppTheme.accentBreak.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.accentBreak.opacity(0.2), lineWidth: 1) }
    }

    private var insightText: String {
        if completedSessions > 20 { return localized("stats.insight.high") }
        if completedSessions > 5  { return localized("stats.insight.medium") }
        return localized("stats.insight.low")
    }

    struct DayData: Identifiable {
        let id    = UUID()
        let label: String
        let minutes: Int
    }

    private var last7DaysData: [DayData] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let fmt   = DateFormatter()
        fmt.locale = activeAppLocale()
        fmt.dateFormat = "E"
        return (0..<7).reversed().map { offset in
            let day  = cal.date(byAdding: .day, value: -offset, to: today)!
            let mins = sessions.filter { $0.completed && cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.durationMinutes }
            return DayData(label: fmt.string(from: day), minutes: mins)
        }
    }
}
