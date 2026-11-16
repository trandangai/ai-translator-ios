import AITranslatorCore
import SwiftUI

public enum AppRoute: Hashable {
    case conversation
    case transcribe
}

public struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @Bindable var prefsManager: LocalPreferencesManager
    @Bindable var authService: AuthService
    @Bindable var userRepo: UserSettingsRepository
    @Bindable var remoteConfig: RemoteInterpreterConfig

    @State private var audioSession = AudioSessionManager()
    @State private var historyStore = EncryptedHistoryStore()
    @State private var path: [AppRoute] = []
    @State private var interpreterVM: InterpreterViewModel?

    public var body: some View {
        Group {
            if authService.currentUser == nil {
                AuthScreen(authService: authService, prefsManager: prefsManager)
            } else {
                NavigationStack(path: $path) {
                    HomeScreen(
                        prefsManager: prefsManager,
                        userRepo: userRepo,
                        audioSession: audioSession,
                        remoteConfig: remoteConfig,
                        authService: authService,
                        historyStore: historyStore,
                        onStartConversation: {
                            path.append(.conversation)
                        },
                        onOpenTranscribe: {
                            path.append(.transcribe)
                        }
                    )
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .conversation:
                            if let vm = interpreterVM {
                                ConversationScreen(viewModel: vm)
                            }
                        case .transcribe:
                            TranscribeStudioScreen(
                                viewModel: TranscribeViewModel(
                                    audioSession: audioSession,
                                    prefsManager: prefsManager,
                                    userRepo: userRepo,
                                    authService: authService
                                )
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            if interpreterVM == nil {
                interpreterVM = InterpreterViewModel(
                    audioSession: audioSession,
                    historyStore: historyStore,
                    userRepo: userRepo,
                    prefsManager: prefsManager,
                    authService: authService
                )
            }
        }
        .task(id: authService.currentUser?.uid) {
            await remoteConfig.fetchAndActivate()
            if let uid = authService.currentUser?.uid {
                await userRepo.loadOrCreateUser(uid: uid, defaults: prefsManager.preferences)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Immediate background microphone & TTS cutoff (Section 2.2, 7.3)
            if newPhase == .background {
                interpreterVM?.stopSession()
            }
        }
    }
}
