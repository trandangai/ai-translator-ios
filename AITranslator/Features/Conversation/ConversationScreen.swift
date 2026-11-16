import AITranslatorCore
import SwiftUI

public struct ConversationScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: InterpreterViewModel

    private var prefs: LocalAppPreferences {
        viewModel.prefsManager.preferences
    }

    private var strings: AppStrings {
        AppStrings.forLanguage(prefs.uiLanguage)
    }

    private var pair: LanguagePair {
        BuiltInLanguagePairs.pair(for: prefs.preferredPairId)
    }

    public var body: some View {
        ZStack {
            AppColors.deepNavy.ignoresSafeArea()

            VStack(spacing: 12) {
                // Top Status Bar
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isMuted ? AppColors.errorCrimson : AppColors.jadeMint)
                            .frame(width: 8, height: 8)
                        Text(strings.micActiveGateOnBadge)
                            .font(AppTypography.monoSmall())
                            .foregroundStyle(AppColors.onDarkSurface)
                    }
                    Spacer()
                    Button {
                        viewModel.prefsManager.preferences.subtitlesEnabled.toggle()
                    } label: {
                        Text("CC")
                            .font(AppTypography.monoSmall())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(prefs.subtitlesEnabled ? AppColors.electricCyan : AppColors.cardNavy)
                            .foregroundStyle(prefs.subtitlesEnabled ? AppColors.deepNavy : AppColors.onDarkSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button {
                        viewModel.prefsManager.preferences.showDebugOverlay.toggle()
                    } label: {
                        Image(systemName: "ladybug.fill")
                            .foregroundStyle(prefs.showDebugOverlay ? AppColors.amberGold : AppColors.onDarkSurfaceVariant)
                    }
                }

                if prefs.showDebugOverlay {
                    DebugTelemetryOverlay(viewModel: viewModel)
                }

                if let error = viewModel.errorBanner {
                    Text(error)
                        .font(AppTypography.bodyMedium())
                        .foregroundStyle(AppColors.errorCrimson)
                        .lineLimit(2)
                }

                // PARTNER B ZONE (ROTATED 180° UPSIDE DOWN)
                partnerZone(
                    title: pair.langBCode,
                    primaryText: viewModel.partnerBText,
                    secondaryText: viewModel.partnerBSubtext,
                    isHighlighted: viewModel.lastDirection == .aToB,
                    accent: AppColors.warmCoral,
                    locale: pair.langBCode,
                    talkButtonTitle: strings.talkBToA,
                    direction: .bToA
                )
                .rotationEffect(.degrees(180))

                // CENTER STATUS & 24-BAND WAVEFORM HUB
                centerHub

                // PARTNER A ZONE (UPRIGHT 0°)
                partnerZone(
                    title: pair.langACode,
                    primaryText: viewModel.partnerAText,
                    secondaryText: viewModel.partnerASubtext,
                    isHighlighted: viewModel.lastDirection == .bToA,
                    accent: AppColors.electricCyan,
                    locale: pair.langACode,
                    talkButtonTitle: strings.talkAToB,
                    direction: .aToB
                )

                // Bottom Controls
                HStack(spacing: 12) {
                    Button {
                        viewModel.toggleMute()
                    } label: {
                        Label(viewModel.isMuted ? strings.unmuteMic : strings.muteMic, systemImage: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(AppTypography.labelLarge())
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(viewModel.isMuted ? AppColors.errorCrimson : AppColors.cardNavy)
                            .foregroundStyle(AppColors.onDarkSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        viewModel.stopSession()
                        dismiss()
                    } label: {
                        Label(strings.endSession, systemImage: "xmark.circle.fill")
                            .font(AppTypography.labelLarge())
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppColors.coralContainer)
                            .foregroundStyle(AppColors.warmCoral)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(16)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }

    private var centerHub: some View {
        VStack(spacing: 8) {
            Text(viewModel.gatePhase.rawValue)
                .font(AppTypography.monoSmall())
                .foregroundStyle(phaseColor)

            // 24-Band Acoustic Waveform Visualizer
            Canvas { context, size in
                let bands = viewModel.waveformBands
                let count = max(1, bands.count)
                let spacing: CGFloat = 3
                let barWidth = (size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
                for (idx, val) in bands.enumerated() {
                    let barHeight = max(4, size.height * CGFloat(val))
                    let x = CGFloat(idx) * (barWidth + spacing)
                    let y = (size.height - barHeight) / 2
                    let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(phaseColor)
                    )
                }
            }
            .frame(height: 44)

            if prefs.interactionMode == .auto {
                Button {
                    viewModel.toggleManualAutoRecord()
                } label: {
                    Text(viewModel.isManualRecording ? strings.stopAndTranslate : strings.tapToRecord)
                        .font(AppTypography.labelLarge())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(viewModel.isManualRecording ? AppColors.warmCoral : AppColors.elevatedNavy)
                        .foregroundStyle(AppColors.onDarkSurface)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(AppColors.surfaceNavy)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func partnerZone(
        title: String,
        primaryText: String,
        secondaryText: String,
        isHighlighted: Bool,
        accent: Color,
        locale: String,
        talkButtonTitle: String,
        direction: SpokenDirection
    ) -> some View {
        VStack(spacing: 10) {
            if prefs.subtitlesEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title)
                            .font(AppTypography.monoSmall())
                            .foregroundStyle(accent)
                        Spacer()
                        if !primaryText.isEmpty {
                            Button {
                                viewModel.replayTTS(text: primaryText, locale: locale)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(accent)
                            }
                        }
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(primaryText.isEmpty ? "…" : primaryText)
                                .font(.system(size: CGFloat(prefs.subtitleFontSizeSp), weight: .bold))
                                .foregroundStyle(AppColors.onDarkSurface)
                            if !secondaryText.isEmpty {
                                Text(secondaryText)
                                    .font(.system(size: CGFloat(max(12, prefs.subtitleFontSizeSp - 3))))
                                    .foregroundStyle(AppColors.onDarkSurfaceVariant)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
                .background(AppColors.cardNavy)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isHighlighted ? accent : Color.clear, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Spacer()
            }

            if prefs.interactionMode == .twoButton {
                let isActive = viewModel.activeTwoButtonDirection == direction
                Button {
                    viewModel.toggleTwoButtonTalk(direction: direction)
                } label: {
                    HStack {
                        Image(systemName: isActive ? "stop.circle.fill" : "mic.circle.fill")
                        Text(isActive ? strings.stopAndTranslate : talkButtonTitle)
                            .font(AppTypography.titleMedium())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isActive ? AppColors.amberGold : accent)
                    .foregroundStyle(AppColors.deepNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var phaseColor: Color {
        switch viewModel.gatePhase {
        case .listeningGateOpen: return AppColors.electricCyan
        case .speechActive: return AppColors.jadeMint
        case .translating: return AppColors.amberGold
        case .playingGated, .tailHoldGated: return AppColors.warmCoral
        case .muted, .idle: return AppColors.onDarkSurfaceVariant
        }
    }
}
