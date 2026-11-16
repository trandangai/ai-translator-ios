import Foundation

/// Instant in-app bilingual VI/EN localization dictionary (Section 8).
public struct AppStrings: Sendable {
    public let appTitle: String
    public let authSubtitle: String
    public let authHighlightPairs: String
    public let authHighlightSecurity: String
    public let signInWithGoogle: String
    public let languageToggleLabel: String

    public let consentTitle: String
    public let consentBody: String
    public let consentAcceptButton: String

    public let micReadyBanner: String
    public let micNeededBanner: String
    public let grantMicPermission: String
    public let modeAutoTitle: String
    public let modeAutoSubtitle: String
    public let modeTwoButtonTitle: String
    public let modeTwoButtonSubtitle: String
    public let subtitlesToggleTitle: String
    public let startLiveSessionCta: String
    public let transcribeStudioTitle: String
    public let quotaMeterTitle: String
    public let encryptedHistoryTitle: String

    public let settingsTitle: String
    public let liveModelLabel: String
    public let transcribeModelLabel: String
    public let dailyCapLabel: String
    public let rpmLimitLabel: String
    public let volumeBoostLabel: String
    public let subtitleFontSizeLabel: String
    public let echoTailLabel: String
    public let vadSilenceLabel: String
    public let vadSensitivityLabel: String
    public let keepScreenOnLabel: String
    public let saveHistoryLabel: String
    public let fixedAbModeLabel: String
    public let allowBargeInLabel: String
    public let deleteAllLocalData: String
    public let signOut: String

    public let micActiveGateOnBadge: String
    public let muteMic: String
    public let unmuteMic: String
    public let endSession: String
    public let tapToRecord: String
    public let stopAndTranslate: String
    public let talkAToB: String
    public let talkBToA: String
    public let speakTranscript: String
    public let copyTranscript: String
    public let copiedToClipboard: String
    public let killSwitchBanner: String

    public static func forLanguage(_ lang: AppUILanguage) -> AppStrings {
        switch lang {
        case .vietnamese: return .vietnamese
        case .english: return .english
        }
    }

    public static let vietnamese = AppStrings(
        appTitle: "AI Translator",
        authSubtitle: "Thông dịch viên giọng nói hai chiều đặt bàn • Loa ngoài thông minh",
        authHighlightPairs: "Tiếng Việt (vi-VN) ↔ English (en-US) & 繁體中文 (zh-TW)",
        authHighlightSecurity: "App Check • Chống vọng loa ngoài • Không lưu giọng nói",
        signInWithGoogle: "Đăng nhập bằng Google",
        languageToggleLabel: "Tiếng Việt • EN",
        consentTitle: "Quyền riêng tư & An toàn âm thanh",
        consentBody: "• Không lưu trữ âm thanh hoặc bản ghi trên máy chủ (Zero Voice Retention).\n• Bảo vệ bởi Firebase App Check.\n• Cặp Tiếng Trung mặc định dùng Phồn thể Đài Loan (繁體中文 zh-TW).\n• Tự động ngắt micro ngay khi ứng dụng xuống nền.",
        consentAcceptButton: "Tôi hiểu và Đồng ý",
        micReadyBanner: "Micro sẵn sàng • Chống vọng Echo Gate đang bật",
        micNeededBanner: "Cần quyền Micro để thông dịch trực tiếp",
        grantMicPermission: "Cấp quyền Micro",
        modeAutoTitle: "Tự động (Auto)",
        modeAutoSubtitle: "VAD liên tục + Echo Gate",
        modeTwoButtonTitle: "2 Nút (180°)",
        modeTwoButtonSubtitle: "Chạm để nói đối diện",
        subtitlesToggleTitle: "Hiển thị phụ đề hai chiều",
        startLiveSessionCta: "Bắt đầu Phiên Thông dịch Trực tiếp",
        transcribeStudioTitle: "Phòng Thu Chép Lời (Transcribe Studio)",
        quotaMeterTitle: "Hạn mức sử dụng hôm nay",
        encryptedHistoryTitle: "Lịch sử mã hóa gần đây (AES-256-GCM)",
        settingsTitle: "Cài đặt",
        liveModelLabel: "Mô hình Thông dịch Trực tiếp",
        transcribeModelLabel: "Mô hình Chép lời (Transcribe)",
        dailyCapLabel: "Giới hạn âm thanh mỗi ngày",
        rpmLimitLabel: "Giới hạn yêu cầu / phút (RPM)",
        volumeBoostLabel: "Tăng âm lượng loa ngoài",
        subtitleFontSizeLabel: "Cỡ chữ phụ đề",
        echoTailLabel: "Độ trễ chống vọng sau phát (Tail Hold)",
        vadSilenceLabel: "Ngắt câu khi im lặng (VAD Silence)",
        vadSensitivityLabel: "Độ nhạy giọng nói (VAD)",
        keepScreenOnLabel: "Giữ màn hình luôn sáng khi dịch",
        saveHistoryLabel: "Lưu lịch sử mã hóa trên máy",
        fixedAbModeLabel: "Chế độ 2 phiên cố định (A/B Test)",
        allowBargeInLabel: "Cho phép ngắt lời khi loa đang phát",
        deleteAllLocalData: "Xóa toàn bộ dữ liệu trên máy",
        signOut: "Đăng xuất",
        micActiveGateOnBadge: "MICRO BẬT • ECHO GATE BẬT",
        muteMic: "Tắt Micro",
        unmuteMic: "Mở Micro",
        endSession: "Kết thúc",
        tapToRecord: "Chạm để thu âm",
        stopAndTranslate: "Dừng & Dịch ngay",
        talkAToB: "Nói (A → B)",
        talkBToA: "Nói (B → A)",
        speakTranscript: "Đọc bản ghi",
        copyTranscript: "Sao chép",
        copiedToClipboard: "Đã sao chép vào bộ nhớ tạm",
        killSwitchBanner: "Dịch vụ tạm thời bảo trì do vượt ngưỡng ngân sách."
    )

    public static let english = AppStrings(
        appTitle: "AI Translator",
        authSubtitle: "Tabletop two-way voice interpreter • Smart loudspeaker gating",
        authHighlightPairs: "Tiếng Việt (vi-VN) ↔ English (en-US) & 繁體中文 (zh-TW)",
        authHighlightSecurity: "App Check Enforced • Loudspeaker Echo Gating • Zero Voice Retention",
        signInWithGoogle: "Sign in with Google",
        languageToggleLabel: "English • VI",
        consentTitle: "Privacy & Audio Safety",
        consentBody: "• Zero Voice Retention: no raw audio or transcripts are stored on servers.\n• Protected by Firebase App Check attestation.\n• Chinese pair strictly enforces Traditional Taiwan Mandarin (繁體中文 zh-TW).\n• Microphone automatically cuts off when app enters background.",
        consentAcceptButton: "I Understand & Agree",
        micReadyBanner: "Microphone Ready • Hardware AEC & Echo Gate Active",
        micNeededBanner: "Microphone permission required for live interpretation",
        grantMicPermission: "Grant Microphone Access",
        modeAutoTitle: "Auto Mode",
        modeAutoSubtitle: "Continuous VAD + Echo Gate",
        modeTwoButtonTitle: "Two-Button (180°)",
        modeTwoButtonSubtitle: "Face-to-Face Tap-to-Talk",
        subtitlesToggleTitle: "Two-Sided Subtitles",
        startLiveSessionCta: "Start Live Interpreter Session",
        transcribeStudioTitle: "Audio Transcription Studio",
        quotaMeterTitle: "Daily Usage Quota",
        encryptedHistoryTitle: "Recent Encrypted History (AES-256-GCM)",
        settingsTitle: "Settings",
        liveModelLabel: "Live Interpreter Model",
        transcribeModelLabel: "Transcribe Model",
        dailyCapLabel: "Daily Audio Safety Cap",
        rpmLimitLabel: "Max Requests Per Minute (RPM)",
        volumeBoostLabel: "Loudspeaker Volume Boost",
        subtitleFontSizeLabel: "Subtitle Font Size",
        echoTailLabel: "Half-Duplex Echo Gating Tail",
        vadSilenceLabel: "End-of-Speech VAD Silence",
        vadSensitivityLabel: "VAD Voice Sensitivity",
        keepScreenOnLabel: "Keep Screen On During Session",
        saveHistoryLabel: "Save Encrypted Local History",
        fixedAbModeLabel: "2-Session Fixed Direction Mode (A/B Test)",
        allowBargeInLabel: "Allow Barge-In While Speaking",
        deleteAllLocalData: "Delete All Local Data",
        signOut: "Sign Out",
        micActiveGateOnBadge: "MIC ACTIVE • LOUDSPEAKER ECHO GATE ON",
        muteMic: "Mute Mic",
        unmuteMic: "Unmute Mic",
        endSession: "End Session",
        tapToRecord: "Tap to Record",
        stopAndTranslate: "Stop & Translate",
        talkAToB: "Talk (A → B)",
        talkBToA: "Talk (B → A)",
        speakTranscript: "Speak Transcript",
        copyTranscript: "Copy Transcript",
        copiedToClipboard: "Copied to clipboard",
        killSwitchBanner: "Service temporarily paused due to budget kill switch."
    )
}
