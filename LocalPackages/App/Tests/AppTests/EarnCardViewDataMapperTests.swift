@testable import App
import KeeperCore
import XCTest

final class EarnCardViewDataMapperTests: XCTestCase {
    func test_vaultsBecomeCardsWithTheirDesignFields() {
        let cards = EarnCardViewDataMapper.cards(
            [vault(network: "base", symbol: "USDC", protocolName: "Moonwell", apy: 6.74)]
        ) { "\($0)%" }

        XCTAssertEqual(cards.map(\.id), ["base/0xVault"])
        XCTAssertEqual(cards.first?.title, "USDC")
        XCTAssertEqual(cards.first?.apy, "6.74%")
        XCTAssertEqual(cards.first?.protocolName, "Moonwell")
    }

    func test_knownNetworkGetsItsChainBadge() throws {
        let cards = EarnCardViewDataMapper.cards([vault(network: "base")]) { _ in "" }
        let card = try XCTUnwrap(cards.first)

        XCTAssertEqual(
            card.imageSource,
            .url(URL(string: "https://example.com/icon.png"), chainIcon: MultichainChain.base.tokenIcon20)
        )
    }

    func test_networkOutsideTheWalletLeavesTheCardWithoutABadge() throws {
        let cards = EarnCardViewDataMapper.cards([vault(network: "solana")]) { _ in "" }
        let card = try XCTUnwrap(cards.first)

        XCTAssertEqual(card.imageSource, .url(URL(string: "https://example.com/icon.png"), chainIcon: nil))
    }

    func test_walletNetworkNames() {
        XCTAssertEqual(MultichainChain(earnNetwork: "mainnet"), .eth)
        XCTAssertEqual(MultichainChain(earnNetwork: "base"), .base)
        XCTAssertEqual(MultichainChain(earnNetwork: "arbitrum"), .arb)
        XCTAssertEqual(MultichainChain(earnNetwork: "BSC"), .bsc)
        XCTAssertNil(MultichainChain(earnNetwork: "solana"))
    }
}

private extension EarnCardViewDataMapperTests {
    func vault(
        network: String,
        symbol: String = "USDC",
        protocolName: String = "Aave",
        apy: Decimal = 1
    ) -> EarnVault {
        EarnVault(
            network: network,
            vaultId: "0xVault",
            assetSymbol: symbol,
            protocolName: protocolName,
            apy: apy,
            iconURL: URL(string: "https://example.com/icon.png")
        )
    }
}
