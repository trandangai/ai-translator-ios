import AITranslatorCore
import SwiftUI
import UIKit

public struct TranscribeStudioScreen: View {
    @State var viewModel: TranscribeViewModel
    @State private var copiedBanner = false

    private var strings: AppStrings {
        AppStrings.forLanguage(viewModel.prefsManager.preferences.uiLanguage)
    }

    public init(viewModel: TranscribeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack {
            AppColors.deepNavy.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 2-Column Model Switcher Chip Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(AIModelCatalog.availableTranscribeModels) { model in
                            let selected = viewModel.prefsManager.preferences.transcribeModelName == model.id
                            Button {
                                viewModel.prefsManager.preferences.transcribeModelName = model.id
                            } label: {
                                Text(model.id)
                                    .font(AppTypography.monoSmall())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(selected ? AppColors.cyanContainer : AppColors.cardNavy)
                                    .foregroundStyle(selected ? AppColors.electricCyan : AppColors.onDarkSurfaceVariant)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selected ? AppColors.electricCyan : Color.clear, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    // Live 24-Band Waveform Visualizer Card (56pt height)
                    Canvas { context, size in
                        let bands = viewModel.waveformBands
                        let count = max(1, bands.count)
                        let spacing: CGFloat = 4
                        let barWidth = (size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
                        for (idx, val) in bands.enumerated() {
                            let h = max(4, size.height * CGFloat(val))
                            let x = CGFloat(idx) * (barWidth + spacing)
                            let y = (size.height - h) / 2
                            context.fill(
                                Path(roundedRect: CGRect(x: x, y: y, width: barWidth, height: h), cornerRadius: barWidth / 2),
                                with: .color(viewModel.isRecording ? AppColors.warmCoral : AppColors.electricCyan)
                            )
                        }
                    }
                    .frame(height: 56)
                    .padding(14)
                    .background(AppColors.cardNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        viewModel.toggleRecording()
                    } label: {
                        HStack {
                            if viewModel.isProcessing {
                                ProgressView().tint(AppColors.deepNavy)
                            } else {
                                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                            }
                            Text(viewModel.isRecording ? strings.stopAndTranslate : strings.tapToRecord)
                                .font(AppTypography.titleMedium())
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(viewModel.isRecording ? AppColors.warmCoral : AppColors.electricCyan)
                        .foregroundStyle(AppColors.deepNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(viewModel.isProcessing)

                    if let hint = viewModel.diagnosticHint {
                        Text(hint)
                            .font(AppTypography.bodyMedium())
                            .foregroundStyle(AppColors.amberGold)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.cardNavy)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let result = viewModel.result {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(result.detectedLanguage) • \(viewModel.latencyMs) ms • \(viewModel.modelUsed)")
                                .font(AppTypography.monoSmall())
                                .foregroundStyle(AppColors.electricCyan)

                            Text(result.transcript)
                                .font(AppTypography.headlineMedium())
                                .foregroundStyle(AppColors.onDarkSurface)

                            if !result.translation.isEmpty {
                                Text(result.translation)
                                    .font(AppTypography.bodyLarge())
                                    .foregroundStyle(AppColors.onDarkSurface)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppColors.coralContainer)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            HStack(spacing: 12) {
                                Button {
                                    viewModel.speakTranscript()
                                } label: {
                                    Label(strings.speakTranscript, systemImage: "speaker.wave.2.fill")
                                        .font(AppTypography.labelLarge())
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(AppColors.elevatedNavy)
                                        .foregroundStyle(AppColors.electricCyan)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                Button {
                                    UIPasteboard.general.string = "\(result.transcript)\n\n\(result.translation)"
                                    copiedBanner = true
                                } label: {
                                    Label(copiedBanner ? strings.copiedToClipboard : strings.copyTranscript, systemImage: "doc.on.doc.fill")
                                        .font(AppTypography.labelLarge())
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(AppColors.elevatedNavy)
                                        .foregroundStyle(AppColors.jadeMint)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(16)
                        .background(AppColors.cardNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(strings.transcribeStudioTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
