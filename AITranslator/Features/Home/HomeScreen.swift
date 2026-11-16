import AITranslatorCore
import SwiftUI

public struct HomeScreen: View {
    @Bindable var prefsManager: LocalPreferencesManager
    @Bindable var userRepo: UserSettingsRepository
    @Bindable var audioSession: AudioSessionManager
    @Bindable var remoteConfig: RemoteInterpreterConfig
    @Bindable var authService: AuthService
    let historyStore: EncryptedHistoryStore
    let onStartConversation: () -> Void
    let onOpenTranscribe: () -> Void

    @State private var showSettingsSheet = false
    @State private var showMicRationale = false

    private var strings: AppStrings {
        AppStrings.forLanguage(prefsManager.preferences.uiLanguage)
    }

    private var recentTurns: [SavedHistoryTurn] {
        guard prefsManager.preferences.saveEncryptedHistory else { return [] }
        return Array(historyStore.loadTurns().suffix(3).reversed())
    }

    public var body: some View {
        ZStack {
            AppColors.deepNavy.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if remoteConfig.isKillSwitchActive {
                        Text(strings.killSwitchBanner)
                            .font(AppTypography.labelLarge())
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(AppColors.errorCrimson)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 1. Hero Banner Card (132pt)
                    ZStack(alignment: .leading) {
                        LinearGradient(
                            colors: [AppColors.cyanContainer, AppColors.surfaceNavy],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(strings.appTitle)
                                    .font(AppTypography.headlineMedium())
                                    .foregroundStyle(AppColors.onDarkSurface)
                                Text(strings.authSubtitle)
                                    .font(AppTypography.bodyMedium())
                                    .foregroundStyle(AppColors.onDarkSurfaceVariant)
                            }
                            Spacer()
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(AppColors.electricCyan)
                        }
                        .padding(16)
                    }
                    .frame(height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // 2. Mic Permission Banner
                    Button {
                        if !audioSession.hasMicPermission {
                            showMicRationale = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: audioSession.hasMicPermission ? "checkmark.shield.fill" : "mic.slash.fill")
                            Text(audioSession.hasMicPermission ? strings.micReadyBanner : strings.micNeededBanner)
                                .font(AppTypography.labelLarge())
                            Spacer()
                        }
                        .padding(14)
                        .foregroundStyle(audioSession.hasMicPermission ? AppColors.jadeMint : AppColors.amberGold)
                        .background(AppColors.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // 3. Language Pair Selector Cards
                    VStack(spacing: 10) {
                        ForEach(BuiltInLanguagePairs.all) { pair in
                            let selected = prefsManager.preferences.preferredPairId == pair.id
                            Button {
                                prefsManager.preferences.preferredPairId = pair.id
                                syncToFirestore()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(prefsManager.preferences.uiLanguage == .vietnamese ? pair.displayNameVi : pair.displayNameEn)
                                            .font(AppTypography.titleMedium())
                                            .foregroundStyle(AppColors.onDarkSurface)
                                        Text(pair.shortBadge)
                                            .font(AppTypography.monoSmall())
                                            .foregroundStyle(AppColors.electricCyan)
                                    }
                                    Spacer()
                                    if selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppColors.electricCyan)
                                    }
                                }
                                .padding(14)
                                .background(selected ? AppColors.cyanContainer.opacity(0.6) : AppColors.cardNavy)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selected ? AppColors.electricCyan : Color.clear, lineWidth: 1.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .accessibilityIdentifier("pair_card_\(pair.id)")
                        }
                    }

                    // 4. Interaction Mode 2-Column Row
                    HStack(spacing: 12) {
                        modeCard(
                            mode: .auto,
                            title: strings.modeAutoTitle,
                            subtitle: strings.modeAutoSubtitle,
                            accent: AppColors.electricCyan,
                            id: "mode_auto_card"
                        )
                        modeCard(
                            mode: .twoButton,
                            title: strings.modeTwoButtonTitle,
                            subtitle: strings.modeTwoButtonSubtitle,
                            accent: AppColors.warmCoral,
                            id: "mode_two_button_card"
                        )
                    }

                    // 5. Subtitles Switch Card
                    Toggle(isOn: Binding(
                        get: { prefsManager.preferences.subtitlesEnabled },
                        set: {
                            prefsManager.preferences.subtitlesEnabled = $0
                            syncToFirestore()
                        }
                    )) {
                        Text(strings.subtitlesToggleTitle)
                            .font(AppTypography.titleMedium())
                            .foregroundStyle(AppColors.onDarkSurface)
                    }
                    .tint(AppColors.electricCyan)
                    .padding(14)
                    .background(AppColors.cardNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // 6. Primary CTA (60pt height)
                    Button {
                        if audioSession.hasMicPermission {
                            onStartConversation()
                        } else {
                            showMicRationale = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text(strings.startLiveSessionCta)
                                .font(AppTypography.titleMedium())
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(remoteConfig.isKillSwitchActive ? Color.gray : AppColors.electricCyan)
                        .foregroundStyle(AppColors.deepNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(remoteConfig.isKillSwitchActive)

                    // 7. Secondary CTA: Transcribe Studio
                    Button(action: onOpenTranscribe) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(strings.transcribeStudioTitle)
                                    .font(AppTypography.titleMedium())
                                    .foregroundStyle(AppColors.onDarkSurface)
                                Text(prefsManager.preferences.transcribeModelName)
                                    .font(AppTypography.monoSmall())
                                    .foregroundStyle(AppColors.warmCoral)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppColors.onDarkSurfaceVariant)
                        }
                        .padding(16)
                        .background(AppColors.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(remoteConfig.isKillSwitchActive)

                    // 8. Daily Usage Quota Meter Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(strings.quotaMeterTitle)
                                .font(AppTypography.labelLarge())
                                .foregroundStyle(AppColors.onDarkSurface)
                            Spacer()
                            Text("\(userRepo.todayQuota.audioSecondsUsed)s / \(prefsManager.preferences.dailyCapSeconds)s")
                                .font(AppTypography.monoSmall())
                                .foregroundStyle(AppColors.electricCyan)
                        }
                        ProgressView(
                            value: Double(userRepo.todayQuota.audioSecondsUsed),
                            total: Double(max(1, prefsManager.preferences.dailyCapSeconds))
                        )
                        .tint(AppColors.electricCyan)
                        Text("Live: \(prefsManager.preferences.liveModelName) • Transcribe: \(prefsManager.preferences.transcribeModelName)")
                            .font(AppTypography.monoSmall())
                            .foregroundStyle(AppColors.onDarkSurfaceVariant)
                    }
                    .padding(14)
                    .background(AppColors.cardNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // 9. Encrypted Local History Preview (only if enabled & non-empty)
                    if !recentTurns.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(strings.encryptedHistoryTitle)
                                .font(AppTypography.labelLarge())
                                .foregroundStyle(AppColors.jadeMint)
                            ForEach(recentTurns) { turn in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(turn.sourceText)
                                        .font(AppTypography.bodyMedium())
                                        .foregroundStyle(AppColors.onDarkSurfaceVariant)
                                    Text(turn.translatedText)
                                        .font(AppTypography.bodyLarge())
                                        .foregroundStyle(AppColors.onDarkSurface)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(AppColors.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(16)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }

            if !prefsManager.preferences.hasAcceptedPrivacyConsent {
                PrivacyConsentDialog(strings: strings) {
                    prefsManager.preferences.hasAcceptedPrivacyConsent = true
                }
            }
        }
        .navigationTitle(strings.appTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    prefsManager.preferences.uiLanguage =
                        prefsManager.preferences.uiLanguage == .vietnamese ? .english : .vietnamese
                } label: {
                    Text(prefsManager.preferences.uiLanguage == .vietnamese ? "VI" : "EN")
                        .font(AppTypography.monoSmall())
                }
                Button {
                    prefsManager.preferences.showDebugOverlay.toggle()
                } label: {
                    Image(systemName: "ladybug.fill")
                        .foregroundStyle(prefsManager.preferences.showDebugOverlay ? AppColors.amberGold : AppColors.onDarkSurfaceVariant)
                }
                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheet(
                prefsManager: prefsManager,
                authService: authService,
                historyStore: historyStore,
                onSync: syncToFirestore
            )
        }
        .sheet(isPresented: $showMicRationale) {
            AudioPermissionRationaleSheet(strings: strings) {
                Task {
                    _ = await audioSession.requestMicPermission()
                    showMicRationale = false
                }
            }
        }
    }

    private func modeCard(
        mode: InteractionMode,
        title: String,
        subtitle: String,
        accent: Color,
        id: String
    ) -> some View {
        let selected = prefsManager.preferences.interactionMode == mode
        return Button {
            prefsManager.preferences.interactionMode = mode
            syncToFirestore()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(AppTypography.titleMedium())
                    .foregroundStyle(AppColors.onDarkSurface)
                Text(subtitle)
                    .font(AppTypography.bodyMedium())
                    .foregroundStyle(AppColors.onDarkSurfaceVariant)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppColors.cardNavy)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? accent : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityIdentifier(id)
    }

    private func syncToFirestore() {
        guard let uid = authService.currentUser?.uid else { return }
        Task {
            await userRepo.syncSettings(uid: uid, prefs: prefsManager.preferences)
        }
    }
}
