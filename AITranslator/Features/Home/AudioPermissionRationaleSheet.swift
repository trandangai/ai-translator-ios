import AITranslatorCore
import SwiftUI

public struct AudioPermissionRationaleSheet: View {
    let strings: AppStrings
    let onGrant: () -> Void

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.electricCyan)
            Text(strings.micNeededBanner)
                .font(AppTypography.titleLarge())
                .foregroundStyle(AppColors.onDarkSurface)
                .multilineTextAlignment(.center)
            Button(action: onGrant) {
                Text(strings.grantMicPermission)
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
        .presentationDetents([.medium])
    }
}
