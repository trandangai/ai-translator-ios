import SwiftUI

/// Dark (Default) and Light theme color tokens (Section 7.1).
public enum AppColors {
    public static let deepNavy = Color(hex: 0x0B132B)
    public static let surfaceNavy = Color(hex: 0x141E3C)
    public static let cardNavy = Color(hex: 0x1C284E)
    public static let elevatedNavy = Color(hex: 0x253463)

    public static let electricCyan = Color(hex: 0x00E5FF)
    public static let cyanContainer = Color(hex: 0x003B46)
    public static let warmCoral = Color(hex: 0xFF6B4A)
    public static let coralContainer = Color(hex: 0x4F190D)

    public static let amberGold = Color(hex: 0xFFC400)
    public static let jadeMint = Color(hex: 0x00E676)
    public static let errorCrimson = Color(hex: 0xFF5252)

    public static let onDarkSurface = Color(hex: 0xF2F6FF)
    public static let onDarkSurfaceVariant = Color(hex: 0xB8C5E0)

    // Light Theme equivalents
    public static let lightBackground = Color(hex: 0xF6F8FC)
    public static let lightSurface = Color(hex: 0xFFFFFF)
    public static let lightCard = Color(hex: 0xEEF2F9)
    public static let primaryCyanLight = Color(hex: 0x007A8C)
    public static let secondaryCoralLight = Color(hex: 0xD94726)
    public static let deepInk = Color(hex: 0x0D1528)
}

public extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
