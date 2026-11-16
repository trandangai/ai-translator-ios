import AITranslatorCore
import SwiftUI

public struct AuthScreen: View {
    @Bindable var authService: AuthService
    @Bindable var prefsManager: LocalPreferencesManager

    private var strings: AppStrings {
        AppStrings.forLanguage(prefsManager.preferences.uiLanguage)
    }

    public init(authService: AuthService, prefsManager: LocalPreferencesManager) {
        self.authService = authService
        self.prefsManager = prefsManager
    }

    public var body: some View {
        ZStack {
            AppColors.deepNavy.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        prefsManager.preferences.uiLanguage =
                            prefsManager.preferences.uiLanguage == .vietnamese ? .english : .vietnamese
                    } label: {
                        Text(strings.languageToggleLabel)
                            .font(AppTypography.labelLarge())
                            .foregroundStyle(AppColors.electricCyan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(AppColors.electricCyan.opacity(0.6), lineWidth: 1)
                            )
                    }
                }

                // Hero Banner (200pt height, 24pt corner radius)
                ZStack {
                    LinearGradient(
                        colors: [AppColors.cyanContainer, AppColors.cardNavy, AppColors.coralContainer],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundStyle(AppColors.electricCyan)
                        Text("VI ↔ EN • 繁體中文")
                            .font(AppTypography.monoSmall())
                            .foregroundStyle(AppColors.onDarkSurfaceVariant)
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 24))

                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform")
                            .foregroundStyle(AppColors.electricCyan)
                        Text(strings.appTitle)
                            .font(AppTypography.displayLarge())
                            .foregroundStyle(AppColors.onDarkSurface)
                    }
                    Text(strings.authSubtitle)
                        .font(AppTypography.bodyMedium())
                        .foregroundStyle(AppColors.onDarkSurfaceVariant)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label(strings.authHighlightPairs, systemImage: "globe.asia.australia.fill")
                        .font(AppTypography.bodyMedium())
                        .foregroundStyle(AppColors.onDarkSurface)
                    Label(strings.authHighlightSecurity, systemImage: "lock.shield.fill")
                        .font(AppTypography.bodyMedium())
                        .foregroundStyle(AppColors.jadeMint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppColors.cardNavy)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if let error = authService.errorMessage {
                    Text(error)
                        .font(AppTypography.bodyMedium())
                        .foregroundStyle(AppColors.errorCrimson)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.errorCrimson.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                Button {
                    Task { await authService.signInWithGoogle() }
                } label: {
                    HStack(spacing: 12) {
                        if authService.isSigningIn {
                            ProgressView().tint(AppColors.deepNavy)
                        } else {
                            Image(systemName: "person.badge.key.fill")
                        }
                        Text(strings.signInWithGoogle)
                            .font(AppTypography.titleMedium())
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.electricCyan)
                    .foregroundStyle(AppColors.deepNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(authService.isSigningIn)
            }
            .padding(24)
            .frame(maxWidth: 600)
        }
        .task {
            await authService.attemptAutoSignIn()
        }
    }
}
