import AITranslatorCore
import SwiftUI

public struct DebugTelemetryOverlay: View {
    @Bindable var viewModel: InterpreterViewModel

    public var body: some View {
        let tracker = viewModel.geminiClient.latencyTracker
        let usedSec = viewModel.userRepo.todayQuota.audioSecondsUsed
        let estCost = LatencyStatsTracker.estimatedCostUsd(audioSecondsUsed: usedSec)

        VStack(alignment: .leading, spacing: 4) {
            Text("Warm: \(viewModel.geminiClient.isSessionWarm ? "YES" : "NO") | Phase: \(viewModel.gatePhase.rawValue)")
            Text("TTFT: \(tracker.lastTtftMs)ms | RTT: \(tracker.lastRttMs)ms | p50: \(tracker.p50Ms)ms | p90: \(tracker.p90Ms)ms")
            Text("Dropped: \(viewModel.droppedChunksCount) | Reconnects: \(viewModel.geminiClient.reconnectCount) | Renewals: \(viewModel.geminiClient.sessionRenewalsCount)")
            Text(String(format: "Route: %@ | RMS: %.1f dBFS | Cost: $%.4f", viewModel.audioSession.currentRouteName, viewModel.currentRmsDb, estCost))
        }
        .font(AppTypography.monoSmall())
        .foregroundStyle(AppColors.amberGold)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppColors.surfaceNavy.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
