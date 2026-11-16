import AVFoundation
import Foundation
import Observation

/// Configures `AVAudioSession` for loudspeaker-first `.playAndRecord` and handles phone call interruptions (Sections 2.2, 3.6, 9.2).
@MainActor
@Observable
public final class AudioSessionManager {
    public private(set) var currentRouteName: String = "Speaker"
    public private(set) var hasMicPermission: Bool = false

    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    public var onAudioFocusLost: (@MainActor () -> Void)?

    public init() {
        refreshPermissionStatus()
        observeNotifications()
    }

    public func refreshPermissionStatus() {
        hasMicPermission = AVAudioApplication.shared.recordPermission == .granted
    }

    public func requestMicPermission() async -> Bool {
        let granted = await AVAudioApplication.requestRecordPermission()
        hasMicPermission = granted
        return granted
    }

    public func configureForLiveSession() throws {
        let session = AVAudioSession.sharedInstance()
        #if compiler(>=6.2)
        let options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP]
        #else
        let options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        #endif
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: options
        )
        try session.setPreferredSampleRate(16_000)
        try session.setPreferredIOBufferDuration(0.030)
        try session.setActive(true)
        updateCurrentRouteName()
    }

    public func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func observeNotifications() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            if type == .began {
                Task { @MainActor [weak self] in
                    self?.onAudioFocusLost?()
                }
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateCurrentRouteName()
            }
        }
    }

    private func updateCurrentRouteName() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        currentRouteName = outputs.first?.portName ?? "Speaker"
    }
}
