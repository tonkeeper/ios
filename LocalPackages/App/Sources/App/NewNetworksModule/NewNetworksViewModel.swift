import AppUI
import Foundation
import KeeperCore

@MainActor
final class NewNetworksViewModel {
    var didUpdateState: ((NewNetworksScreenState) -> Void)?
    /// "Open wallet" or the close button: the screen is done with, whatever the sync is doing.
    var didFinish: (() -> Void)?

    private(set) var state: NewNetworksScreenState

    private let chains: [MultichainChain]
    private let addMissingChains: () async -> [MultichainChain]
    private var isAdding = false

    /// Long enough for the icons to fly out and the orbit to turn before it stops on the result.
    private static let minimumLoadingDuration: TimeInterval = 3

    /// `addMissingChains` adds what the wallets miss and answers with the chains still missing afterwards.
    init(
        chains: [MultichainChain],
        addMissingChains: @escaping () async -> [MultichainChain]
    ) {
        self.chains = chains
        self.addMissingChains = addMissingChains
        state = NewNetworksScreenState(
            chains: chains.map { chain in
                NewNetworksScreenState.Chain(
                    id: chain.rawValue,
                    title: chain.shortDisplayTitle,
                    icon: chain.tokenIcon44
                )
            },
            phase: .loading
        )
    }

    func addChains() {
        guard !isAdding else { return }
        isAdding = true
        update(phase: .loading)
        Task { [weak self, chains, addMissingChains] in
            let started = Date()
            let remaining = Set(await addMissingChains())
            let shortfall = Self.minimumLoadingDuration - Date().timeIntervalSince(started)
            if shortfall > 0 {
                try? await Task.sleep(nanoseconds: UInt64(shortfall * 1_000_000_000))
            }
            guard let self else { return }
            isAdding = false
            let added = chains.filter { !remaining.contains($0) }
            update(phase: added.isEmpty ? .error : .added(Set(added.map(\.rawValue))))
        }
    }

    func finish() {
        didFinish?()
    }
}

private extension NewNetworksViewModel {
    func update(phase: NewNetworksScreenState.Phase) {
        state.phase = phase
        didUpdateState?(state)
    }
}
