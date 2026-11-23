@testable import App
@testable import KeeperCore
import XCTest

@MainActor
final class LedgerNetworksViewModelTests: XCTestCase {
    func testPairingUsesTheClientDefaultsAndKeepsTonSelected() {
        let chains = MultichainChain.displayOrder
        let viewModel = LedgerNetworksViewModel(
            title: "Networks",
            description: "Choose networks",
            chains: chains,
            preselectedChains: LedgerNetworkSelectionConfiguration.client.pairingSelection(among: chains),
            requiredChains: [.ton]
        )

        XCTAssertEqual(viewModel.state.apps.filter(\.isSelected).map(\.id), ["TON", "Solana", "Ethereum", "Bitcoin", "Tron"])
        XCTAssertEqual(viewModel.state.apps.filter(\.isRequired).map(\.id), ["TON"])

        viewModel.toggle(id: "TON")

        XCTAssertTrue(viewModel.state.apps.first { $0.id == "TON" }?.isSelected == true)
    }

    func testSettingsStartWithNoAppSelectedAndReturnAllNetworksBackedByTheChosenApp() {
        let chains: [MultichainChain] = [.eth, .bsc, .tron]
        let viewModel = LedgerNetworksViewModel(
            title: "Networks",
            description: "Choose networks",
            chains: chains,
            preselectedChains: []
        )
        var continuedWith: [MultichainChain]?
        viewModel.didContinue = { continuedWith = $0 }

        XCTAssertFalse(viewModel.state.isContinueEnabled)
        viewModel.continue()
        XCTAssertNil(continuedWith)

        XCTAssertEqual(viewModel.state.apps.map(\.id), ["Ethereum", "Tron"])

        viewModel.toggle(id: "Ethereum")
        viewModel.continue()

        XCTAssertFalse(viewModel.state.isContinueEnabled)
        XCTAssertEqual(continuedWith, [.eth, .bsc])
    }

    func testPreselectingOneEVMNetworkSelectsTheEthereumApp() {
        let viewModel = LedgerNetworksViewModel(
            title: "Networks",
            description: "Choose networks",
            chains: [.eth, .bsc, .tron],
            preselectedChains: [.eth]
        )
        var continuedWith: [MultichainChain]?
        viewModel.didContinue = { continuedWith = $0 }

        XCTAssertEqual(viewModel.state.apps.filter(\.isSelected).map(\.id), ["Ethereum"])

        viewModel.continue()

        XCTAssertEqual(continuedWith, [.eth, .bsc])
    }

    func testContinueRunsOnceAndDisablesFurtherChanges() {
        let viewModel = LedgerNetworksViewModel(
            title: "Networks",
            description: "Choose networks",
            chains: [.eth, .bsc, .tron],
            preselectedChains: [.eth]
        )
        var selections: [[MultichainChain]] = []
        viewModel.didContinue = { selections.append($0) }

        viewModel.continue()
        viewModel.continue()
        viewModel.toggle(id: "Tron")

        XCTAssertEqual(selections, [[.eth, .bsc]])
        XCTAssertFalse(viewModel.state.isContinueEnabled)
        XCTAssertFalse(viewModel.state.apps.first { $0.id == "Tron" }?.isSelected == true)
    }

    func testPairingConfigurationAlwaysIncludesTonWhenItIsAvailable() {
        let configuration = LedgerNetworkSelectionConfiguration(pairingDefaultChains: [.eth])

        XCTAssertEqual(configuration.pairingSelection(among: [.ton, .eth, .tron]), [.ton, .eth])
    }
}
