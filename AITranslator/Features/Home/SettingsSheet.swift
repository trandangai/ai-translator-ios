import AITranslatorCore
import SwiftUI

public struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var prefsManager: LocalPreferencesManager
    @Bindable var authService: AuthService
    let historyStore: EncryptedHistoryStore
    let onSync: () -> Void

    private var strings: AppStrings {
        AppStrings.forLanguage(prefsManager.preferences.uiLanguage)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(strings.liveModelLabel) {
                    Picker(strings.liveModelLabel, selection: $prefsManager.preferences.liveModelName) {
                        ForEach(AIModelCatalog.availableLiveModels) { model in
                            Text("\(model.id) (\(model.badge))").tag(model.id)
                        }
                    }
                    Picker(strings.transcribeModelLabel, selection: $prefsManager.preferences.transcribeModelName) {
                        ForEach(AIModelCatalog.availableTranscribeModels) { model in
                            Text("\(model.id) (\(model.badge))").tag(model.id)
                        }
                    }
                }

                Section("Audio & Quotas") {
                    intSlider(
                        label: strings.dailyCapLabel,
                        value: $prefsManager.preferences.dailyCapSeconds,
                        range: 300...14400,
                        step: 300,
                        unit: "s"
                    )
                    intSlider(
                        label: strings.rpmLimitLabel,
                        value: $prefsManager.preferences.maxRequestsPerMinute,
                        range: 5...120,
                        step: 5,
                        unit: "RPM"
                    )
                    intSlider(
                        label: strings.volumeBoostLabel,
                        value: $prefsManager.preferences.volumeBoostDb,
                        range: 0...12,
                        step: 1,
                        unit: "dB"
                    )
                    intSlider(
                        label: strings.subtitleFontSizeLabel,
                        value: $prefsManager.preferences.subtitleFontSizeSp,
                        range: 14...32,
                        step: 1,
                        unit: "sp"
                    )
                    intSlider(
                        label: strings.echoTailLabel,
                        value: $prefsManager.preferences.echoGatingTailMs,
                        range: 150...800,
                        step: 10,
                        unit: "ms"
                    )
                    intSlider(
                        label: strings.vadSilenceLabel,
                        value: $prefsManager.preferences.vadSilenceMs,
                        range: 200...1200,
                        step: 50,
                        unit: "ms"
                    )
                    intSlider(
                        label: strings.vadSensitivityLabel,
                        value: $prefsManager.preferences.vadSensitivityPct,
                        range: 10...95,
                        step: 5,
                        unit: "%"
                    )
                }

                Section("Behavior") {
                    Toggle(strings.keepScreenOnLabel, isOn: $prefsManager.preferences.keepScreenOn)
                    Toggle(strings.saveHistoryLabel, isOn: Binding(
                        get: { prefsManager.preferences.saveEncryptedHistory },
                        set: { enabled in
                            prefsManager.preferences.saveEncryptedHistory = enabled
                            if !enabled { historyStore.wipeAll() }
                        }
                    ))
                    Toggle(strings.fixedAbModeLabel, isOn: $prefsManager.preferences.twoSessionFixedAbMode)
                    Toggle(strings.allowBargeInLabel, isOn: $prefsManager.preferences.allowBargeIn)
                }

                Section {
                    Button(role: .destructive) {
                        historyStore.wipeAll()
                        prefsManager.resetAll()
                    } label: {
                        Text(strings.deleteAllLocalData)
                    }

                    Button {
                        authService.signOut()
                        dismiss()
                    } label: {
                        Text(strings.signOut)
                    }
                }
            }
            .navigationTitle(strings.settingsTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSync()
                        dismiss()
                    }
                }
            }
        }
    }

    private func intSlider(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String
    ) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue) \(unit)")
                    .font(AppTypography.monoSmall())
                    .foregroundStyle(AppColors.electricCyan)
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
            .tint(AppColors.electricCyan)
        }
    }
}
