import SwiftUI

/// Bundled Google Fonts typography scale with system fallbacks (Section 7.2).
public enum AppTypography {
    public static func displayLarge() -> Font {
        .custom("SpaceGrotesk-Bold", size: 36, relativeTo: .largeTitle)
    }

    public static func headlineLarge() -> Font {
        .custom("SpaceGrotesk-Bold", size: 28, relativeTo: .title)
    }

    public static func headlineMedium() -> Font {
        .custom("SpaceGrotesk-SemiBold", size: 22, relativeTo: .title2)
    }

    public static func titleLarge() -> Font {
        .custom("SpaceGrotesk-Bold", size: 19, relativeTo: .title3)
    }

    public static func titleMedium() -> Font {
        .custom("PlusJakartaSans-SemiBold", size: 16, relativeTo: .headline)
    }

    public static func bodyLarge() -> Font {
        .custom("PlusJakartaSans-Regular", size: 16, relativeTo: .body)
    }

    public static func bodyMedium() -> Font {
        .custom("PlusJakartaSans-Regular", size: 14, relativeTo: .subheadline)
    }

    public static func labelLarge() -> Font {
        .custom("PlusJakartaSans-SemiBold", size: 14, relativeTo: .callout)
    }

    public static func monoSmall() -> Font {
        .custom("JetBrainsMono-Medium", size: 11, relativeTo: .caption2)
    }
}
