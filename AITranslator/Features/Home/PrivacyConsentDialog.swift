import AITranslatorCore
import SwiftUI

public struct PrivacyConsentDialog: View {
    let strings: AppStrings
    let onAccept: () -> Void

    public var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Label(strings.consentTitle, systemImage: "hand.raised.fill")
                    .font(AppTypography.headlineMedium())
                    .foregroundStyle(AppColors.electricCyan)

                Text(strings.consentBody)
                    .font(AppTypography.bodyMedium())
                    .foregroundStyle(AppColors.onDarkSurface)

                Button(action: onAccept) {
                    Text(strings.consentAcceptButton)
                        .font(AppTypography.titleMedium())
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.electricCyan)
                        .foregroundStyle(AppColors.deepNavy)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(24)
            .background(AppColors.surfaceNavy)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(24)
            .frame(maxWidth: 500)
        }
        .interactiveDismissDisabled(true)
    }
}
