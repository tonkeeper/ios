@testable import App
import KeeperCore
import TKUIKit
import XCTest

final class EarnPortfolioSectionMapperTests: XCTestCase {
    func test_positionsBecomeTheSectionState() {
        let state = mapper.map(positions, isStale: false)

        XCTAssertEqual(state.totalBalance, "$1231.54")
        XCTAssertFalse(state.isStale)
        XCTAssertEqual(state.rows.map(\.id), ["mainnet/0xMorpho", "base/0xAave"])
        XCTAssertEqual(state.rows.first?.title, "USDT")
        XCTAssertEqual(
            state.rows.first?.displayMode,
            .includingMarketData(
                marketCap: "Morpho",
                price: "$120.54",
                change: AssetBalanceRowCellContent.Delta(text: "+$0.5", isPositive: true),
                showsPin: false
            )
        )
    }

    func test_knownNetworkGetsItsBadgeAndChainIcon() throws {
        let state = mapper.map(positions, isStale: false)

        XCTAssertEqual(state.rows.map(\.badge), ["ETHEREUM", "BASE"])
        XCTAssertEqual(
            try XCTUnwrap(state.rows.last).avatarImageSource,
            .url(nil, chainIcon: MultichainChain.base.tokenIcon20)
        )
    }

    func test_negativeEarningsKeepTheirSign() {
        let state = mapper.map(positions, isStale: false)

        XCTAssertEqual(
            state.rows.last?.displayMode,
            .includingMarketData(
                marketCap: "Aave",
                price: "$1111",
                change: AssetBalanceRowCellContent.Delta(text: "$-20.4", isPositive: false),
                showsPin: false
            )
        )
    }

    func test_missingEarningsLeaveTheRowWithoutThem() {
        let state = mapper.map(
            [position(network: "solana", vaultId: "0xSol", protocolName: "Kamino", balanceUsd: 1, earnedUsd: nil)],
            isStale: true
        )

        XCTAssertEqual(
            state.rows.first?.displayMode,
            .includingMarketData(marketCap: "Kamino", price: "$1", change: nil, showsPin: false)
        )
        XCTAssertEqual(state.rows.first?.badge, "SOLANA")
        XCTAssertTrue(state.isStale)
    }
}

private extension EarnPortfolioSectionMapperTests {
    var mapper: EarnPortfolioSectionMapper {
        EarnPortfolioSectionMapper(fiatFormatter: { "$\($0)" })
    }

    var positions: [EarnPosition] {
        [
            position(network: "mainnet", vaultId: "0xMorpho", protocolName: "Morpho", balanceUsd: Decimal(string: "120.54")!, earnedUsd: Decimal(string: "0.5")!),
            position(network: "base", vaultId: "0xAave", protocolName: "Aave", balanceUsd: 1111, earnedUsd: Decimal(string: "-20.4")!),
        ]
    }

    func position(network: String, vaultId: String, protocolName: String, balanceUsd: Decimal, earnedUsd: Decimal?) -> EarnPosition {
        EarnPosition(
            network: network,
            vaultId: vaultId,
            protocolName: protocolName,
            assetSymbol: "USDT",
            assetIconURL: nil,
            balanceUsd: balanceUsd,
            earnedUsd: earnedUsd
        )
    }
}
