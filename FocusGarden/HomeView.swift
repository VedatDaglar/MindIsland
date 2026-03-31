import SwiftUI
import SwiftData
import Combine

struct HomeView: View {
    private let presetOptions = [15, 25, 45, 60]
    private let categories = ["general", "work", "study", "reading", "other"]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("activeThemeId", store: SharedStore.defaults) private var activeThemeId = "theme.zen"
    @State private var viewModel = FocusTimerViewModel()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let _ = activeThemeId

        NavigationStack {
            ZStack {
                background

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        header
                        focusOrb
                        if viewModel.breakIsRunning {
                            breakTimerCard
                        } else {
                            sessionButton
                            durationPicker
                        }
                        statsGrid
                        quickTipsCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 36)
                }

                if viewModel.showCelebration { celebrationOverlay }
                if viewModel.sessionFailed { failedOverlay }
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(AppTheme.tabBarBackground, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .onAppear {
                viewModel.attach(modelContext: modelContext)
                viewModel.reloadStoredValues()
            }
            .onChange(of: scenePhase) {
                viewModel.handleScenePhaseChange(scenePhase)
            }
            .onReceive(timer) { _ in
                viewModel.handleTick()
            }
            .task {
                viewModel.attach(modelContext: modelContext)
                await viewModel.requestNotificationAuthorizationIfNeeded()
            }
            .sheet(isPresented: showCustomSheetBinding) {
                customDurationSheet
            }
        }
    }

    private var showCustomSheetBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showCustomSheet },
            set: { viewModel.showCustomSheet = $0 }
        )
    }

    private var customMinutesBinding: Binding<Double> {
        Binding(
            get: { viewModel.customMinutes },
            set: { viewModel.customMinutes = $0 }
        )
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle RGB ambient glow spots in the background
            Circle()
                .fill(AppTheme.accent.opacity(0.06))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -80, y: -200)

            Circle()
                .fill(AppTheme.glowSecondary.opacity(0.05))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 100, y: 200)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localized("app.name"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(localized("home.hero.subtitle"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(localized("home.hero.badge"))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.accentBright)
                        Text(localizedFormat("format.minutes", viewModel.totalFocusMinutes))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Divider()
                        .frame(height: 30)
                        .background(AppTheme.textSecondary.opacity(0.3))
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.accentBreakBright)
                        Text("\(viewModel.focusCoins)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.card.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                }
            }

            Text(viewModel.statusText)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary.opacity(0.84))
        }
    }

    private var focusOrb: some View {
        VStack(spacing: 16) {
            // "Ready?" / orb title - ABOVE the circle
            Text(viewModel.orbTitle)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)

            ZStack {
                // RGB ambient glow behind the orb
                Circle()
                    .fill(AppTheme.accent.opacity(0.14))
                    .frame(width: 280, height: 280)
                    .blur(radius: 20)
                    .offset(x: -20, y: -10)

                Circle()
                    .fill(AppTheme.glowSecondary.opacity(0.10))
                    .frame(width: 250, height: 250)
                    .blur(radius: 22)
                    .offset(x: 25, y: 15)

                Circle()
                    .fill((viewModel.breakIsRunning ? AppTheme.accentBreak : AppTheme.accentBright).opacity(0.08))
                    .frame(width: 220, height: 220)
                    .blur(radius: 16)
                    .offset(x: 0, y: -20)

                Circle()
                    .stroke(AppTheme.border.opacity(0.4), lineWidth: 18)
                    .frame(width: 236, height: 236)

                Circle()
                    .trim(from: 0, to: viewModel.progressValue)
                    .stroke(
                        LinearGradient(
                            colors: viewModel.breakIsRunning
                                ? [AppTheme.accentBreakBright, AppTheme.accentBreak]
                                : [AppTheme.accentBright, AppTheme.accent, AppTheme.glowSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 236, height: 236)
                    .shadow(
                        color: AppTheme.accent.opacity(0.30),
                        radius: 16,
                        y: 4
                    )
                    .shadow(
                        color: AppTheme.glowSecondary.opacity(0.20),
                        radius: 20,
                        y: -4
                    )
                    .animation(.easeInOut(duration: 0.35), value: viewModel.progressValue)

                Circle()
                    .fill(LinearGradient(colors: [AppTheme.cardSoft, AppTheme.card], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 188, height: 188)
                    .overlay {
                        Circle().stroke(AppTheme.border, lineWidth: 1)
                    }

                NeonEggEvolutionView(
                    completedSessions: viewModel.completedSessions,
                    timerIsRunning: viewModel.timerIsRunning || viewModel.breakIsRunning,
                    sessionCompleted: viewModel.sessionCompleted,
                    isBreak: viewModel.breakIsRunning,
                    size: 120
                )
            }

            // Timer - BELOW the circle
            Text(viewModel.timeString)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 12) {
                capsuleInfo(title: localized("home.hero.focus"), value: localizedFormat("format.minutes", viewModel.selectedMinutes))
                capsuleInfo(title: localized("home.hero.streak"), value: localizedFormat("format.days", viewModel.focusStreak))
            }
        }
        .padding(22)
        .background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(categories, id: \.self) { category in
                Button(localized("category.\(category)")) {
                    viewModel.selectCategory(category)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.accent)
                Text(localized("category.\(viewModel.selectedCategory)"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.cardSoft)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(AppTheme.border, lineWidth: 1)
            }
        }
    }

    private var sessionButton: some View {
        VStack(spacing: 14) {
            if !viewModel.timerIsRunning && !viewModel.breakIsRunning {
                categoryMenu
            }

            Button {
                if viewModel.timerIsRunning {
                    viewModel.stopSession()
                } else {
                    viewModel.startSession()
                }
            } label: {
                Text(viewModel.buttonTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.05, green: 0.11, blue: 0.10))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient(colors: [AppTheme.accentBright, AppTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)

            Text(viewModel.timerIsRunning ? localized("home.footer.running") : localized("home.footer.ready"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(20)
        .background(AppTheme.card.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.20), radius: 18, y: 10)
    }

    private var breakTimerCard: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.accentBreakBright)
                Text(localized("home.break.title"))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(localized("home.break.badge"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.accentBreakBright)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.accentBreak.opacity(0.18))
                    .clipShape(Capsule())
            }

            Button {
                viewModel.skipBreak()
            } label: {
                Text(localized("home.break.skip"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.cardSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Text(localized("home.break.footer"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(20)
        .background(AppTheme.accentBreak.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.accentBreak.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: AppTheme.accentBreak.opacity(0.12), radius: 18, y: 10)
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localized("home.duration.title"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 8) {
                ForEach(presetOptions, id: \.self) { minutes in
                    Button {
                        viewModel.selectDuration(minutes)
                    } label: {
                        VStack(spacing: 5) {
                            Text("\(minutes)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text(localized("common.minutesShort"))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(viewModel.selectedMinutes == minutes ? AppTheme.accent.opacity(0.24) : AppTheme.cardSoft)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(viewModel.selectedMinutes == minutes ? AppTheme.accent.opacity(0.42) : AppTheme.border, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.timerIsRunning)
                    .opacity(viewModel.timerIsRunning && viewModel.selectedMinutes != minutes ? 0.45 : 1)
                }

                Button {
                    viewModel.presentCustomSheet()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                        Text(localized("home.duration.custom"))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(viewModel.isCustomSelected ? AppTheme.accent.opacity(0.24) : AppTheme.cardSoft)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(viewModel.isCustomSelected ? AppTheme.accent.opacity(0.42) : AppTheme.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.timerIsRunning)
                .opacity(viewModel.timerIsRunning && !viewModel.isCustomSelected ? 0.45 : 1)
            }
        }
        .padding(18)
        .background(AppTheme.card.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private var customDurationSheet: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    VStack(spacing: 10) {
                        Text("\(Int(viewModel.customMinutes))")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(localized("home.duration.minutes"))
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.top, 24)

                    VStack(spacing: 12) {
                        Slider(value: customMinutesBinding, in: 5...120, step: 5)
                            .tint(AppTheme.accent)
                            .padding(.horizontal, 24)
                        HStack {
                            Text("5 \(localized("common.minutesShort"))")
                            Spacer()
                            Text("120 \(localized("common.minutesShort"))")
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 28)
                    }

                    Button {
                        viewModel.confirmCustomDurationSelection()
                    } label: {
                        Text(localizedFormat("home.startSession", Int(viewModel.customMinutes)))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.05, green: 0.11, blue: 0.10))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient(colors: [AppTheme.accentBright, AppTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle(localized("home.duration.customTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            // dynamic color scheme from ContentView
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("common.cancel")) {
                        viewModel.dismissCustomSheet()
                    }
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 14) {
            statCard(title: localized("home.today"), value: localizedFormat("format.minutes", viewModel.todayPreviewMinutes), icon: "clock.fill")
            statCard(title: localized("home.sessions"), value: "\(viewModel.completedSessions)", icon: "checkmark.circle.fill")
            statCard(title: localized("home.streak"), value: localizedFormat("format.days", viewModel.focusStreak), icon: "flame.fill")
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accentBright)
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(AppTheme.cardSoft)
                        .frame(width: 104, height: 104)
                        .overlay {
                            Circle().stroke(AppTheme.border, lineWidth: 1)
                        }
                    NeonEggEvolutionView(
                        completedSessions: viewModel.completedSessions,
                        timerIsRunning: false,
                        sessionCompleted: true,
                        isBreak: false,
                        size: 78
                    )
                }

                Text(localized("celebration.title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(localizedFormat("celebration.message", viewModel.selectedMinutes))
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 12) {
                    celebrationPill(title: localized("celebration.total"), value: localizedFormat("format.minutes", viewModel.totalFocusMinutes))
                    celebrationPill(title: localized("home.sessions"), value: "\(viewModel.completedSessions)")
                }

                Button {
                    viewModel.startBreakFromCelebration()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text(localizedFormat("home.break.start", viewModel.breakDuration / 60))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color(red: 0.10, green: 0.08, blue: 0.03))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [AppTheme.accentBreakBright, AppTheme.accentBreak], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.dismissCelebration()
                } label: {
                    Text(localized("common.continue"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.05, green: 0.11, blue: 0.10))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [AppTheme.accentBright, AppTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 330)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 16)
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func celebrationPill(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.cardSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var failedOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color(red: 0.95, green: 0.45, blue: 0.45).opacity(0.9))

                Text(localized("failed.title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(localized("failed.message"))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textSecondary)

                Button {
                    viewModel.dismissFailure()
                } label: {
                    Text(localized("common.continue"))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.95, green: 0.45, blue: 0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .frame(maxWidth: 330)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(radius: 24)
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private var quickTipsCard: some View {
        HStack(spacing: 14) {
            Image(systemName: viewModel.notificationsEnabled ? "bell.badge.fill" : "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.accentBright)
                .frame(width: 42, height: 42)
                .background(AppTheme.cardSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(localized("home.tip.title"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(viewModel.notificationsEnabled ? localized("home.tip.notificationsOn") : localized("home.tip.notificationsOff"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(AppTheme.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private func capsuleInfo(title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.cardSoft)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
