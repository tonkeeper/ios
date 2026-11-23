import AppUI
import Foundation
import KeeperCore
import LedgerKit

@MainActor
final class LedgerNetworksViewModel {
    var didUpdateState: ((LedgerNetworksScreenState) -> Void)?
    var didContinue: (([MultichainChain]) -> Void)?

    private(set) var state: LedgerNetworksScreenState

    private let apps: [LedgerNetworkApp]
    private let requiredAppIds: Set<String>
    private var selectedAppIds: Set<String>
    private var isContinuing = false

    init(
        title: String,
        description: String,
        chains: [MultichainChain],
        preselectedChains: [MultichainChain],
        requiredChains: Set<MultichainChain> = []
    ) {
        let availableChains = MultichainChain.orderedByDisplayOrder(chains)
        let apps = Self.apps(among: availableChains)
        self.apps = apps
        let requiredChains = requiredChains.intersection(Set(availableChains))
        requiredAppIds = Set(apps.filter { app in
            app.chains.contains { requiredChains.contains($0) }
        }.map(\.id))
        let preselectedChains = Set(preselectedChains)
        selectedAppIds = Set(apps.filter { app in
            app.chains.contains { preselectedChains.contains($0) }
        }.map(\.id)).union(requiredAppIds)
        state = LedgerNetworksScreenState(
            title: title,
            description: description,
            apps: [],
            isContinueEnabled: false
        )
        update()
    }

    func toggle(id: String) {
        guard !isContinuing, apps.contains(where: { $0.id == id }), !requiredAppIds.contains(id) else {
            return
        }
        if selectedAppIds.contains(id) {
            selectedAppIds.remove(id)
        } else {
            selectedAppIds.insert(id)
        }
        update()
    }

    func `continue`() {
        guard !isContinuing else {
            return
        }
        let selected = MultichainChain.orderedByDisplayOrder(
            apps.filter { selectedAppIds.contains($0.id) }.flatMap(\.chains)
        )
        guard !selected.isEmpty else {
            return
        }
        isContinuing = true
        update()
        didContinue?(selected)
    }
}

private extension LedgerNetworksViewModel {
    func update() {
        state = LedgerNetworksScreenState(
            title: state.title,
            description: state.description,
            apps: apps.map { app in
                LedgerNetworksScreenState.App(
                    id: app.id,
                    title: app.ledgerApp.name,
                    icon: app.iconChain.tokenIcon44,
                    isRequired: requiredAppIds.contains(app.id),
                    isSelected: selectedAppIds.contains(app.id)
                )
            },
            isContinueEnabled: !selectedAppIds.isEmpty && !isContinuing
        )
        didUpdateState?(state)
    }

    static func apps(among chains: [MultichainChain]) -> [LedgerNetworkApp] {
        [
            (LedgerApp.ton, MultichainChain.ton),
            (.solana, .sol),
            (.ethereum, .eth),
            (.bitcoin, .btc),
            (.tron, .tron),
        ].compactMap { ledgerApp, iconChain in
            let appChains = chains.filter { $0.ledgerApp == ledgerApp }
            guard !appChains.isEmpty else {
                return nil
            }
            return LedgerNetworkApp(ledgerApp: ledgerApp, iconChain: iconChain, chains: appChains)
        }
    }
}

private struct LedgerNetworkApp {
    let ledgerApp: LedgerApp
    let iconChain: MultichainChain
    let chains: [MultichainChain]

    var id: String {
        ledgerApp.name
    }
}
