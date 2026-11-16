import Foundation

/// Script detection, locale resolution, prompt-echo guard, and deterministic direction inference (Sections 3.6, 5.3, 5.4).
public enum ScriptDetector: Sendable {
    private static let vietnameseSpecificChars: Set<Character> = Set(
        "ăâđêôơưĂÂĐÊÔƠƯáàảãạắằẳẵặấầẩẫậéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ" +
        "ÁÀẢÃẠẮẰẲẴẶẤẦẨẪẬÉÈẺẼẸẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌỐỒỔỖỘỚỜỞỠỢÚÙỦŨỤỨỪỬỮỰÝỲỶỸỴ"
    )

    public static func containsCJK(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (v >= 0x4E00 && v <= 0x9FFF) || (v >= 0x3400 && v <= 0x4DBF) {
                return true
            }
        }
        return false
    }

    public static func containsVietnameseDiacritics(_ text: String) -> Bool {
        text.contains { vietnameseSpecificChars.contains($0) }
    }

    /// Critical Safety Guard (Section 3.6): resolves TTS locale from actual text script first.
    public static func resolveTtsLocale(for text: String, fallbackLocale: String) -> String {
        if containsCJK(text) {
            return "zh-TW"
        }
        if containsVietnameseDiacritics(text) {
            return "vi-VN"
        }
        return fallbackLocale
    }

    /// Prompt-Echo & Silence Guard (Section 5.3).
    public static func isPromptEchoOrSilence(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let lower = trimmed.lowercased()
        if lower == "silence" || lower == "null" || lower == "none" || lower == "\"silence\"" {
            return true
        }
        if lower.contains("silent simultaneous interpreter") || lower.contains("strict language pair rule") {
            return true
        }
        return false
    }

    /// Deterministic direction inference from character scripts (Section 5.4).
    public static func inferDirectionFromOutput(
        pairId: String,
        sourceText: String,
        translatedText: String,
        modelHint: String? = nil
    ) -> SpokenDirection {
        if pairId == "vi_zhtw" {
            if containsCJK(translatedText) { return .aToB }
            if containsCJK(sourceText) { return .bToA }
            if containsVietnameseDiacritics(translatedText) { return .bToA }
            if containsVietnameseDiacritics(sourceText) { return .aToB }
        } else {
            let sourceHasVi = containsVietnameseDiacritics(sourceText)
            let targetHasVi = containsVietnameseDiacritics(translatedText)
            if targetHasVi && !sourceHasVi { return .bToA }
            if sourceHasVi && !targetHasVi { return .aToB }
        }

        switch modelHint?.uppercased() {
        case "A_TO_B": return .aToB
        case "B_TO_A": return .bToA
        default: return .unknown
        }
    }
}
