@testable import App
import KeeperCore
import TKUIKit
import XCTest

final class EarnPortfolioSectionMapperTests: XCTestCase {
    func test_portfolioBecomesTheSectionStateInTheDisplayCurrency() {
        let state = mapper(displayCurrency: rub).map(portfolio, isStale: false)

        XCTAssertEqual(state.totalBalance, "1231.54 RUB")
        XCTAssertFalse(state.isStale)
        XCTAssertEqual(state.rows.map(\.id), ["mainnet/0xMorpho", "base/0xAave"])
        XCTAssertEqual(state.rows.first?.title, "USDT")
        XCTAssertEqual(
            state.rows.first?.displayMode,
            .includingMarketData(
                marketCap: "Morpho",
                price: "120.54 RUB",
                change: AssetBalanceRowCellContent.Delta(text: "+0.5 RUB", isPositive: true),
                showsPin: false
            )
        )
    }

    func test_currencyWithoutARateFallsBackToTheDefaultOne() throws {
        let state = try mapper(displayCurrency: XCTUnwrap(Currency(code: "EUR"))).map(portfolio, isStale: false)

        XCTAssertEqual(state.totalBalance, "15.2 USD")
        XCTAssertEqual(
            state.rows.first?.displayMode,
            .includingMarketData(
                marketCap: "Morpho",
                price: "1.5 USD",
                change: AssetBalanceRowCellContent.Delta(text: "+0.01 USD", isPositive: true),
                showsPin: false
            )
        )
    }

    func test_knownNetworkGetsItsBadgeAndChainIcon() throws {
        let state = mapper(displayCurrency: rub).map(portfolio, isStale: false)

        XCTAssertEqual(state.rows.map(\.badge), ["ETHEREUM", "BASE"])
        XCTAssertEqual(
            try XCTUnwrap(state.rows.last).avatarImageSource,
            .url(nil, chainIcon: MultichainChain.base.tokenIcon20)
        )
    }

    func test_negativeEarningsKeepTheirSign() {
        let state = mapper(displayCurrency: rub).map(portfolio, isStale: false)

        XCTAssertEqual(
            state.rows.last?.displayMode,
            .includingMarketData(
                marketCap: "Aave",
                price: "1111 RUB",
                change: AssetBalanceRowCellContent.Delta(text: "-20.4 RUB", isPositive: false),
                showsPin: false
            )
        )
    }

    func test_amountWithoutARateIsUnknownRatherThanZero() throws {
        let portfolio = try EarnPortfolio(
            walletId: "wallet",
            totalFiat: ["RUB": XCTUnwrap(Decimal(string: "120.54"))],
            positions: [
                position(network: "mainnet", vaultId: "0xMorpho", protocolName: "Morpho", balance: ["RUB": XCTUnwrap(Decimal(string: "120.54"))], earned: [:]),
                position(network: "base", vaultId: "0xAave", protocolName: "Aave", balance: ["USD": 2], earned: [:]),
            ]
        )

        let state = mapper(displayCurrency: rub).map(portfolio, isStale: false)

        XCTAssertEqual(state.totalBalance, "120.54 RUB")
        XCTAssertEqual(
            state.rows.map(\.displayMode),
            [
                .includingMarketData(marketCap: "Morpho", price: "120.54 RUB", change: nil, showsPin: false),
                .includingMarketData(marketCap: "Aave", price: "-", change: nil, showsPin: false),
            ]
        )
    }

    func test_totalWithoutTheDisplayOrDefaultCurrencyIsUnknown() {
        let portfolio = EarnPortfolio(
            walletId: "wallet",
            totalFiat: ["EUR": 10],
            positions: [position(network: "mainnet", vaultId: "0xMorpho", protocolName: "Morpho", balance: ["EUR": 10], earned: [:])]
        )

        let state = mapper(displayCurrency: rub).map(portfolio, isStale: false)

        XCTAssertEqual(state.totalBalance, "-")
        XCTAssertEqual(
            state.rows.first?.displayMode,
            .includingMarketData(marketCap: "Morpho", price: "-", change: nil, showsPin: false)
        )
    }

    func test_secureModeHidesEveryAmount() {
        let state = mapper(displayCurrency: rub, isSecureMode: true).map(portfolio, isStale: false)

        XCTAssertEqual(state.totalBalance, "* * *")
        XCTAssertEqual(
            state.rows.map(\.displayMode),
            [
                .includingMarketData(marketCap: "Morpho", price: "* * *", change: nil, showsPin: false),
                .includingMarketData(marketCap: "Aave", price: "* * *", change: nil, showsPin: false),
            ]
        )
    }

    func test_zeroEarningsLeaveTheRowWithoutThem() {
        let portfolio = EarnPortfolio(
            walletId: "wallet",
            totalFiat: ["USD": 1],
            positions: [position(network: "solana", vaultId: "0xSol", protocolName: "Kamino", balance: ["USD": 1], earned: ["USD": 0])]
        )

        let state = mapper(displayCurrency: .USD).map(portfolio, isStale: true)

        XCTAssertEqual(
            state.rows.first?.displayMode,
            .includingMarketData(marketCap: "Kamino", price: "1 USD", change: nil, showsPin: false)
        )
        XCTAssertEqual(state.rows.first?.badge, "SOLANA")
        XCTAssertTrue(state.isStale)
    }
}

private extension EarnPortfolioSectionMapperTests {
    var rub: Currency {
        Currency(code: "RUB")!
    }

    func mapper(displayCurrency: Currency, isSecureMode: Bool = false) -> EarnPortfolioSectionMapper {
        EarnPortfolioSectionMapper(
            displayCurrency: { displayCurrency },
            isSecureMode: { isSecureMode },
            fiatFormatter: { "\($0) \($1.code)" }
        )
    }

    var portfolio: EarnPortfolio {
        EarnPortfolio(
            walletId: "wallet",
            totalFiat: ["RUB": Decimal(string: "1231.54")!, "USD": Decimal(string: "15.2")!],
            positions: [
                position(
                    network: "mainnet",
                    vaultId: "0xMorpho",
                    protocolName: "Morpho",
                    balance: ["RUB": Decimal(string: "120.54")!, "USD": Decimal(string: "1.5")!],
                    earned: ["RUB": Decimal(string: "0.5")!, "USD": Decimal(string: "0.01")!]
                ),
                position(
                    network: "base",
                    vaultId: "0xAave",
                    protocolName: "Aave",
                    balance: ["RUB": 1111, "USD": Decimal(string: "13.7")!],
                    earned: ["RUB": Decimal(string: "-20.4")!, "USD": Decimal(string: "-0.25")!]
                ),
            ]
        )
    }

    func position(
        network: String,
        vaultId: String,
        protocolName: String,
        balance: [String: Decimal],
        earned: [String: Decimal]
    ) -> EarnPosition {
        EarnPosition(
            network: network,
            vaultId: vaultId,
            protocolName: protocolName,
            assetSymbol: "USDT",
            assetIconURL: nil,
            balanceFiat: balance,
            earnedFiat: earned
        )
    }
}
