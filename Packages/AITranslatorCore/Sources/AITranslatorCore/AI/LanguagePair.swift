import Foundation

public enum SpokenDirection: String, Codable, Sendable, Equatable {
    case aToB = "A_TO_B"
    case bToA = "B_TO_A"
    case unknown = "UNKNOWN"
}

public struct LanguagePair: Identifiable, Sendable, Equatable {
    public let id: String
    public let langACode: String
    public let langBCode: String
    public let shortBadge: String
    public let displayNameVi: String
    public let displayNameEn: String

    public init(
        id: String,
        langACode: String,
        langBCode: String,
        shortBadge: String,
        displayNameVi: String,
        displayNameEn: String
    ) {
        self.id = id
        self.langACode = langACode
        self.langBCode = langBCode
        self.shortBadge = shortBadge
        self.displayNameVi = displayNameVi
        self.displayNameEn = displayNameEn
    }
}

public enum BuiltInLanguagePairs: Sendable {
    public static let viEn = LanguagePair(
        id: "vi_en",
        langACode: "vi-VN",
        langBCode: "en-US",
        shortBadge: "VI ↔ EN",
        displayNameVi: "Tiếng Việt ↔ Tiếng Anh (Mỹ)",
        displayNameEn: "Vietnamese ↔ English (US)"
    )

    public static let viZhTw = LanguagePair(
        id: "vi_zhtw",
        langACode: "vi-VN",
        langBCode: "zh-TW",
        shortBadge: "VI ↔ 繁中(TW)",
        displayNameVi: "Tiếng Việt ↔ Tiếng Trung Phồn Thể (Đài Loan)",
        displayNameEn: "Vietnamese ↔ Traditional Chinese (Taiwan)"
    )

    public static let all: [LanguagePair] = [viEn, viZhTw]

    public static func pair(for id: String) -> LanguagePair {
        all.first { $0.id == id } ?? viEn
    }
}
