@testable import App
import BigInt
import Foundation
import KeeperCore
import TKCore
import XCTest

final class MultichainSwapValidatorTests: XCTestCase {
    /// A TON route's message carries the traded amount plus forwarded gas, so a balance that covers
    /// the quoted `source_amount` can still be short of what the swap actually sends.
    func test_tonRouteMessageValueAboveBalance_isInsufficientEvenWhenSourceAmountFits() {
        let state = validate(
            sendAmount: "0.4",
            balance: 634_354_334,
            route: tonRoute(sourceAmount: "400000000", messageValue: "680000000")
        )

        XCTAssertEqual(state, .insufficientBalance)
    }

    func test_tonRouteMessageValueWithinBalance_isValid() {
        let state = validate(
            sendAmount: "0.3",
            balance: 634_354_334,
            route: tonRoute(sourceAmount: "300000000", messageValue: "580000000")
        )

        XCTAssertEqual(state, .valid)
    }

    func test_routeWithoutInlinePayloads_stillComparesQuotedSourceAmount() {
        let state = validate(
            sendAmount: "0.7",
            balance: 634_354_334,
            route: tonRoute(sourceAmount: "700000000", messageValue: nil)
        )

        XCTAssertEqual(state, .insufficientBalance)
    }
}

private extension MultichainSwapValidatorTests {
    func validate(
        sendAmount: String,
        balance: BigUInt,
        route: MultichainSwapRoute
    ) -> MultichainSwapValidationState {
        let calculator = MultichainSwapAmountCalculator(
            amountFormatter: makeAmountFormatter(),
            displayCurrency: .USD
        )
        let validator = MultichainSwapValidator(
            calculator: calculator,
            multichainState: MultichainWalletState(
                walletId: "wallet",
                addresses: [
                    MultichainWalletAddress(chain: .ton, address: "UQC", type: .tonV4R2),
                ]
            )
        )
        var inputs = MultichainSwapInputs(
            initialAssets: MultichainSwapInitialAssets(
                sendAsset: makeAsset(assetId: "ton/mainnet/coin", balance: balance),
                receiveAsset: makeAsset(assetId: "ton/mainnet/jetton/0:abc", balance: 0),
                catalog: [:],
                slippage: nil
            )
        )
        inputs = inputs.settingSendAmount(sendAmount)
        return validator.validate(inputs, selectedRoute: route, usdFiatRate: nil)
    }

    func tonRoute(sourceAmount: String, messageValue: String?) -> MultichainSwapRoute {
        MultichainSwapRoute(
            routeId: "route",
            aggregator: "swapsxyz",
            routeType: "cross_chain_swap",
            sourceAmount: sourceAmount,
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

    func makeAsset(assetId: String, balance: BigUInt) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: "asset",
                symbol: "AST",
                decimals: 9,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:], diff30d: [:]),
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
