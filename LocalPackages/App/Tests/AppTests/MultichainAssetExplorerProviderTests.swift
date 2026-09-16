@testable import App
@testable import KeeperCore
import XCTest

final class MultichainAssetExplorerProviderTests: XCTestCase {
    func test_tokenAssetResolvesToTheChainTokenPage() throws {
        let explorer = makeProvider().assetExplorer(for: "eth/mainnet/erc20/0xdAC17F95")

        XCTAssertEqual(
            explorer?.destination,
            try .url(XCTUnwrap(URL(string: "https://eth.blockscout.com/token/0xdAC17F95")))
        )
        XCTAssertEqual(explorer?.browserTitle, "Blockscout")
    }

    func test_tonJettonResolvesToTheChainTokenPage() throws {
        let explorer = makeProvider().assetExplorer(for: "ton/mainnet/jetton/EQCxE6mU")

        XCTAssertEqual(
            explorer?.destination,
            try .url(XCTUnwrap(URL(string: "https://tonviewer.com/EQCxE6mU")))
        )
        XCTAssertEqual(explorer?.browserTitle, "Tonviewer")
    }

    func test_chainWithoutTokenTemplateHasNoExplorer() {
        let explorer = makeProvider().assetExplorer(for: "btc/mainnet/brc20/ordi")

        XCTAssertNil(explorer)
    }

    func test_chainMissingFromTheConfigurationHasNoExplorer() {
        let explorer = makeProvider(explorers: []).assetExplorer(for: "eth/mainnet/erc20/0xdAC17F95")

        XCTAssertNil(explorer)
    }

    /// A native coin carries no contract address to substitute into the token template.
    func test_nativeCoinOfAnEvmChainHasNoExplorer() {
        let explorer = makeProvider().assetExplorer(for: "eth/mainnet/coin")

        XCTAssertNil(explorer)
    }

    func test_tonCoinFallsBackToTheWalletScopedTonviewerPage() {
        let explorer = makeProvider().assetExplorer(for: "ton/mainnet/coin")

        XCTAssertEqual(explorer?.destination, .tonviewerDetails)
        XCTAssertEqual(explorer?.browserTitle, "Tonviewer")
    }

    func test_tonCoinHasNoExplorerWhenTheConfigurationCarriesNoTonExplorer() {
        let explorer = makeProvider(explorers: []).assetExplorer(for: "ton/mainnet/coin")

        XCTAssertNil(explorer)
    }

    func test_malformedAssetIdentifierHasNoExplorer() {
        XCTAssertNil(makeProvider().assetExplorer(for: "not-an-asset-id"))
    }
}

private extension MultichainAssetExplorerProviderTests {
    func makeProvider(
        explorers: [BootConfiguration.ChainExplorer]? = nil
    ) -> MultichainAssetExplorerProvider {
        let explorers = explorers ?? [
            BootConfiguration.ChainExplorer(
                chain: "ton",
                name: "Tonviewer",
                url: "https://tonviewer.com/transaction/{tx_hash}",
                tokenURL: "https://tonviewer.com/{token_address}"
            ),
            BootConfiguration.ChainExplorer(
                chain: "eth",
                name: "Blockscout",
                url: "https://eth.blockscout.com/tx/{tx_hash}",
                tokenURL: "https://eth.blockscout.com/token/{token_address}"
            ),
            BootConfiguration.ChainExplorer(
                chain: "btc",
                name: "Mempool",
                url: "https://mempool.space/tx/{tx_hash}",
                tokenURL: nil
            ),
        ]
        return MultichainAssetExplorerProvider(explorersProvider: { explorers })
    }
}
