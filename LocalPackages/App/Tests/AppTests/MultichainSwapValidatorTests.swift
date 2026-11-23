@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import TKCore
import TonSwift
import XCTest

final class MultichainSwapValidatorTests: XCTestCase {
    /// A TON route's message carries the traded amount plus forwarded gas, so a balance that covers
    /// the quoted `source_amount` can still be short of what the swap actually sends.
    func test_tonRouteMessageValueAboveBalance_isInsufficientEvenWhenSourceAmountFits() {
        let state = validate(
            sendAmount: "1.4",
            balance: 1_634_354_334,
            route: tonRoute(sourceAmount: "1400000000", messageValue: "1680000000")
        )

        XCTAssertEqual(state, .insufficientBalance)
    }

    func test_tonRouteMessageValueWithinBalance_isValid() {
        let state = validate(
            sendAmount: "1.3",
            balance: 1_634_354_334,
            route: tonRoute(sourceAmount: "1300000000", messageValue: "1580000000")
        )

        XCTAssertEqual(state, .valid)
    }

    func test_tonRouteTradeAmountExcludesMessageGas() {
        let route = tonRoute(sourceAmount: "300000000", messageValue: "580000000")

        XCTAssertEqual(
            MultichainSwapSourceCharge.tradeAmount(requested: 300_000_000, route: route),
            300_000_000
        )
    }

    func test_routeWithoutInlinePayloads_stillComparesQuotedSourceAmount() {
        let state = validate(
            sendAmount: "1.7",
            balance: 1_634_354_334,
            route: tonRoute(sourceAmount: "1700000000", messageValue: nil)
        )

        XCTAssertEqual(state, .insufficientBalance)
    }

    func test_gramBelowTheMinimumWithSufficientBalance() {
        let route = tonRoute(sourceAmount: "500000000", messageValue: "780000000")

        XCTAssertEqual(
            validate(sendAmount: "0.5", balance: 2_000_000_000, route: route),
            .belowMinimum(1_000_000_000)
        )
    }

    func test_gramBelowTheMinimumStillRequiresBalanceForTheAmountAndGas() {
        let route = tonRoute(sourceAmount: "500000000", messageValue: "780000000")

        for balance: BigUInt in [0, 300_000_000, 600_000_000] {
            XCTAssertEqual(validate(sendAmount: "0.5", balance: balance, route: route), .insufficientBalance)
        }
    }

    func test_gramAtTheMinimumIsValid() {
        let state = validate(
            sendAmount: "1",
            balance: 2_000_000_000,
            route: tonRoute(sourceAmount: "1000000000", messageValue: "1280000000")
        )

        XCTAssertEqual(state, .valid)
    }

    /// Only GRAM has a minimum known before quoting; other assets learn theirs from the provider.
    func test_tokensHaveNoMinimumBeforeQuoting() {
        let state = validate(
            sendAmount: "0.001",
            balance: BigUInt(10).power(18),
            route: tokenRoute(sourceAmount: "1000000000000000"),
            assetId: "bsc/mainnet/bep20/0x55d398326f99059ff775485246999027b3197955",
            decimals: 18
        )

        XCTAssertEqual(state, .valid)
    }

    /// Captured from a max USDT (BEP20) quote: SwapsXYZ echoes `source_amount` through
    /// floating point, 596 base units above the balance that was sent.
    func test_roundedQuoteEchoAboveBalance_keepsMaxSendValid() throws {
        let balance = try XCTUnwrap(BigUInt("4181445029473734404"))
        let state = validate(
            sendAmount: "1",
            balance: balance,
            route: tokenRoute(sourceAmount: (balance + 596).description),
            assetId: "bsc/mainnet/bep20/0x55d398326f99059ff775485246999027b3197955",
            decimals: 18,
            isMax: true
        )

        XCTAssertEqual(state, .valid)
    }

    /// Preparing an exact-output swap quotes it again, and the amount it then sends may reach the cap.
    /// Captured from a swaps.xyz quote for 5 USDT (BEP20) paid in BNB.
    func test_exactOutputCapAboveBalance_isInsufficientEvenWhenTheExpectedAmountFits() {
        let route = tokenRoute(sourceAmount: "6872133194057689", maximumSourceAmount: "6940309118601912")
        func state(balance: BigUInt) -> MultichainSwapValidationState {
            validate(receiveAmount: "5", balance: balance, route: route, assetId: "bsc/mainnet/coin", decimals: 18)
        }

        XCTAssertEqual(state(balance: 6_900_000_000_000_000), .insufficientBalance)
        XCTAssertEqual(state(balance: 6_940_309_118_601_912), .valid)
    }

    /// A route that sells nothing for the amount to receive is no route, as the Swap button would do
    /// nothing with it.
    func test_exactOutputRouteSellingNothing_isUnavailable() {
        let state = validate(
            receiveAmount: "5",
            balance: BigUInt(10).power(18),
            route: tokenRoute(sourceAmount: "0"),
            assetId: "bsc/mainnet/coin",
            decimals: 18
        )

        XCTAssertEqual(state, .routeUnavailable)
    }

    /// A TON route forwards its gas in the same message as the amount sold, so the cap, which leaves the
    /// gas out, needs that gas on top.
    func test_tonExactOutputCap_isCoveredTogetherWithTheForwardedGas() {
        let route = tonRoute(sourceAmount: "1000000000", messageValue: "1280000000", maximumSourceAmount: "1010000000")
        func state(balance: BigUInt) -> MultichainSwapValidationState {
            validate(receiveAmount: "1", balance: balance, route: route)
        }

        XCTAssertEqual(state(balance: 1_285_000_000), .insufficientBalance)
        XCTAssertEqual(state(balance: 1_290_000_000), .valid)
    }
}

private extension MultichainSwapValidatorTests {
    func validate(
        sendAmount: String = "",
        receiveAmount: String? = nil,
        balance: BigUInt,
        route: MultichainSwapRoute,
        assetId: String = "ton/mainnet/coin",
        decimals: Int = 9,
        isMax: Bool = false
    ) -> MultichainSwapValidationState {
        let calculator = MultichainSwapAmountCalculator(
            amountFormatter: makeAmountFormatter(),
            displayCurrency: .USD
        )
        let multichainState = MultichainWalletState(
            walletId: "wallet",
            addresses: [
                MultichainWalletAddress(chain: .ton, address: "UQC", type: .tonV4R2),
                MultichainWalletAddress(chain: .bsc, address: "0xwallet"),
            ]
        )
        let validator = MultichainSwapValidator(
            calculator: calculator,
            swapWallet: MultichainSwapWallet(
                wallet: makeWallet(multichainState: multichainState),
                registeredState: multichainState
            )
        )
        var inputs = MultichainSwapInputs(
            initialAssets: MultichainSwapInitialAssets(
                sendAsset: makeAsset(assetId: assetId, balance: balance, decimals: decimals),
                receiveAsset: makeAsset(assetId: "ton/mainnet/jetton/0:abc", balance: 0, decimals: 6),
                slippage: nil
            )
        )
        inputs = if let receiveAmount {
            inputs.settingReceiveAmount(receiveAmount)
        } else {
            inputs.settingSendAmount(sendAmount, isMax: isMax)
        }
        return validator.validate(inputs, selectedRoute: route, usdFiatRate: nil)
    }

    func makeWallet(multichainState: MultichainWalletState) -> KeeperCore.Wallet {
        let publicKey = PublicKey(data: Data(repeating: 0x01, count: 32))
        return KeeperCore.Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(multichainState)
        )
    }

    func tokenRoute(sourceAmount: String, maximumSourceAmount: String? = nil) -> MultichainSwapRoute {
        MultichainSwapRoute(
            routeId: "route",
            aggregator: "swapsxyz",
            routeType: "cross_chain_swap",
            sourceAmount: sourceAmount,
            maximumSourceAmount: maximumSourceAmount,
            estimatedDestinationAmount: "3976271",
            minimumDestinationAmount: "3976271",
            legs: [],
            dateExpire: Date(timeIntervalSinceNow: 60),
            riskLevel: "low",
            payloads: nil
        )
    }

    func tonRoute(
        sourceAmount: String,
        messageValue: String?,
        maximumSourceAmount: String? = nil
    ) -> MultichainSwapRoute {
        MultichainSwapRoute(
            routeId: "route",
            aggregator: "swapsxyz",
            routeType: "cross_chain_swap",
            sourceAmount: sourceAmount,
            maximumSourceAmount: maximumSourceAmount,
            estimatedDestinationAmount: "1",
            minimumDestinationAmount: "1",
            legs: [],
            dateExpire: Date(timeIntervalSinceNow: 60),
            riskLevel: "low",
            payloads: messageValue.map { value in
                [
                    MultichainSwapPreparedPayload(
                        payloadId: "payload",
                        kind: "main",
                        chainId: "ton/mainnet",
                        chainFamily: "TON",
                        payloadType: "ton_boc",
                        payload: #"[{"address":"EQC","amount":"\#(value)","payload":"te6"}]"#,
                        humanSummary: MultichainSwapHumanSummary(
                            action: "swap",
                            spendAsset: "ton/mainnet/coin",
                            spendAmount: sourceAmount,
                            receiveAsset: "ton/mainnet/jetton/0:abc",
                            depositAddress: nil
                        ),
                        validationStatus: "validated",
                        dateExpire: Date(timeIntervalSinceNow: 60),
                        calldataPayloadType: .exact
                    ),
                ]
            }
        )
    }

    func makeAsset(assetId: String, balance: BigUInt, decimals: Int = 9) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: "asset",
                symbol: "AST",
                decimals: decimals,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
            balance: balance
        )
    }

    func makeAmountFormatter() -> AmountFormatter {
        var configuration = AmountFormatter.Configuration()
        configuration.locale = Locale(identifier: "en_US_POSIX")
        configuration.space = " "
        return AmountFormatter(configuration: configuration)
    }
}
