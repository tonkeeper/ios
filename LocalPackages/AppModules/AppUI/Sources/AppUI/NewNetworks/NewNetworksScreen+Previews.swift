import SwiftUI
import TKUIKit

// Loads for five seconds, then reveals the result. Tap the button to start over; every other run
// fails to show the error state, whose "Try again" restarts loading.
#Preview("Flow · 4 chains") {
    NewNetworksFlowPreview(count: 4)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Flow · 8 chains") {
    NewNetworksFlowPreview(count: 8)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Loading") {
    NewNetworksScreen(
        state: NewNetworksScreenState(chains: .preview(count: 4), phase: .loading),
        onContinue: {},
        onRetry: {},
        onClose: {}
    )
    .environment(\.newNetworksMotion, false)
    .tkPreviewTheme(.deepBlue)
}

#Preview("Added") {
    let chains: [NewNetworksScreenState.Chain] = .preview(count: 4)
    NewNetworksScreen(
        state: NewNetworksScreenState(chains: chains, phase: .added(Set(chains.map(\.id)))),
        onContinue: {},
        onRetry: {},
        onClose: {}
    )
    .environment(\.newNetworksMotion, false)
    .tkPreviewTheme(.deepBlue)
}

// The first chain failed to register: it stays grey and is left out of the subtitle.
#Preview("Added · 6 chains, first one failed") {
    let chains: [NewNetworksScreenState.Chain] = .preview(count: 6)
    NewNetworksScreen(
        state: NewNetworksScreenState(chains: chains, phase: .added(Set(chains.dropFirst().map(\.id)))),
        onContinue: {},
        onRetry: {},
        onClose: {}
    )
    .environment(\.newNetworksMotion, false)
    .tkPreviewTheme(.deepBlue)
}

#Preview("Error · 8 chains") {
    NewNetworksScreen(
        state: NewNetworksScreenState(chains: .preview(count: 8), phase: .error),
        onContinue: {},
        onRetry: {},
        onClose: {}
    )
    .environment(\.newNetworksMotion, false)
    .tkPreviewTheme(.deepBlue)
}

private struct NewNetworksFlowPreview: View {
    let count: Int

    @State private var phase = NewNetworksScreenState.Phase.loading
    @State private var runs = 0

    var body: some View {
        let chains: [NewNetworksScreenState.Chain] = .preview(count: count)
        NewNetworksScreen(
            state: NewNetworksScreenState(chains: chains, phase: phase),
            onContinue: { runs += 1 },
            onRetry: { runs += 1 },
            onClose: {}
        )
        .task(id: runs) {
            phase = .loading
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            phase = runs.isMultiple(of: 2) ? .added(Set(chains.map(\.id))) : .error
        }
    }
}

private extension [NewNetworksScreenState.Chain] {
    static func preview(count: Int) -> [NewNetworksScreenState.Chain] {
        let all: [(id: String, title: String, icon: UIImage)] = [
            ("sol", "Solana", .TKUIKit.Icons.Size44.solChain),
            ("robinhood", "Robinhood", .TKUIKit.Icons.Size44.robinhoodChain),
            ("polygon", "Polygon", .TKUIKit.Icons.Size44.polygonChain),
            ("avax", "Avalanche", .TKUIKit.Icons.Size44.avalancheChain),
            ("ton", "TON", .TKUIKit.Icons.Size44.tonChain),
            ("eth", "Ethereum", .TKUIKit.Icons.Size44.ethChain),
            ("btc", "Bitcoin", .TKUIKit.Icons.Size44.btcChain),
            ("tron", "TRON", .TKUIKit.Icons.Size44.trxChain),
        ]
        return all.prefix(count).map { NewNetworksScreenState.Chain(id: $0.id, title: $0.title, icon: $0.icon) }
    }
}
