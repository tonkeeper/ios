@testable import App
import BigInt
import KeeperCore
import XCTest

final class MultichainSwapFeeSummaryTests: XCTestCase {
    func test_aPlanOnItsWayHasNoSummary() {
        XCTAssertNil(MultichainSwapFeeSummary(plan: .preparing, picked: nil))
    }

    /// Battery holds charges for the whole message and gives the change back: the row names what the
    /// swap costs, not what it holds.
    func test_aBatteryThatCanPayNamesItsCharges() {
        XCTAssertEqual(summary([battery(charges: 7, available: 771), native(fee: 300)]), .charges(7))
        XCTAssertEqual(
            summary([MultichainSwapFeeOption(cost: .batteryCharges(count: 28, excess: 21, isInsufficient: false))]),
            .charges(7)
        )
    }

    /// The selection goes on to the chain's coin when the battery cannot pay, and the row with it.
    func test_aBatteryThatCannotPayLeavesTheFeeToTheCoin() {
        XCTAssertEqual(
            summary([battery(charges: 7, available: 3, isInsufficient: true), native(fee: 300)]),
            .amounts([.init(amount: 300, asset: trx)])
        )
    }

    /// Nothing can pay: the row names the battery while the choice was left to it, empty or low by the
    /// charges it has, and the picked method otherwise.
    func test_nothingThatCanPayNamesWhatTheSelectionLandedOn() {
        let insufficientNative = native(fee: 300, isInsufficient: true)

        XCTAssertEqual(summary([battery(charges: 7, available: 0, isInsufficient: true), insufficientNative]), .batteryEmpty)
        XCTAssertEqual(summary([battery(charges: 7, available: 3, isInsufficient: true), insufficientNative]), .lowBattery)
        XCTAssertEqual(summary([battery(charges: 7, available: nil, isInsufficient: true), insufficientNative]), .batteryEmpty)
        XCTAssertEqual(summary([MultichainSwapFeeOption(cost: .batteryUnpriced), insufficientNative]), .batteryEmpty)
        XCTAssertEqual(
            summary([battery(charges: 7, available: 3, isInsufficient: true), insufficientNative], picked: .native),
            .noFunds(symbol: "TRX")
        )
        XCTAssertEqual(summary([insufficientNative]), .noFunds(symbol: "TRX"))
    }

    func test_relayedMethodsNameTheirAmount() {
        XCTAssertEqual(
            summary([MultichainSwapFeeOption(cost: .gram(amountNano: 50, isInsufficient: false))]),
            .amounts([.init(amount: 50, asset: .gram)])
        )
        XCTAssertEqual(
            summary([MultichainSwapFeeOption(cost: .token(usdt, amount: 20, isInsufficient: false))]),
            .amounts([.init(amount: 20, asset: usdt)])
        )
    }

    /// A route that approves first is charged twice on its chain.
    func test_feesInOneAssetAddUp() {
        let fees = [
            MultichainTransactionEmulationResult(fee: 100, asset: trx),
            MultichainTransactionEmulationResult(fee: 200, asset: trx),
        ]
        XCTAssertEqual(
            summary([MultichainSwapFeeOption(cost: .native(fees, isInsufficient: false))]),
            .amounts([.init(amount: 300, asset: trx)])
        )
        XCTAssertEqual(
            MultichainSwapFeeSummary(plan: .ready(feeOptions: [], networkFees: fees), picked: nil),
            .amounts([.init(amount: 300, asset: trx)])
        )
    }

    func test_aRouteWithoutAPricedFeeHasAnUnknownOne() {
        XCTAssertEqual(MultichainSwapFeeSummary(plan: .failed, picked: nil), .unknown)
        XCTAssertEqual(MultichainSwapFeeSummary(plan: .ready(feeOptions: [], networkFees: []), picked: nil), .unknown)
        XCTAssertEqual(summary([MultichainSwapFeeOption(cost: .native([], isInsufficient: false))]), .unknown)
        XCTAssertEqual(summary([native(fee: 0)]), .amounts([.init(amount: 0, asset: trx)]))
    }

    func test_aShortageOfTheCoinNamesIt() {
        XCTAssertEqual(
            MultichainSwapFeeSummary(
                plan: .nativeFeeShortage(MultichainNativeFeeShortage(asset: bnb, requiredAmount: 1)),
                picked: nil
            ),
            .noFunds(symbol: "BNB")
        )
    }

    /// An amount below the minimum names the fee the asset it sells pays once the amount fits, as the battery that
    /// cannot pay gives way to it then, whichever way that asset's id is spelled. A shortage of anything else stays one.
    func test_anAmountBelowTheMinimumNamesTheFeeOfTheAssetItSells() {
        let shortage = MultichainNativeFeeShortage(asset: bnb, requiredAmount: 1)
        XCTAssertEqual(
            MultichainSwapFeeSummary(plan: .nativeFeeShortage(shortage), picked: nil, amountBlockedAssetId: bnb.assetId),
            .amounts([.init(amount: 1, asset: bnb)])
        )
        XCTAssertEqual(
            MultichainSwapFeeSummary(plan: .nativeFeeShortage(shortage), picked: nil, amountBlockedAssetId: usdt.assetId),
            .noFunds(symbol: "BNB")
        )
        let insufficientNative = native(fee: 300, isInsufficient: true)
        let trxFee = MultichainSwapFeeSummary.amounts([.init(amount: 300, asset: trx)])
        XCTAssertEqual(summary([insufficientNative], amountBlockedAssetId: trx.assetId), trxFee)
        XCTAssertEqual(summary([insufficientNative], amountBlockedAssetId: "trx/mainnet/coin"), trxFee)
        XCTAssertEqual(summary([insufficientNative], amountBlockedAssetId: usdt.assetId), .noFunds(symbol: "TRX"))
        XCTAssertEqual(
            summary([battery(charges: 7, available: 0, isInsufficient: true), insufficientNative], amountBlockedAssetId: trx.assetId),
            trxFee
        )
    }
}

private extension MultichainSwapFeeSummaryTests {
    var trx: MultichainAssetDetails {
        MultichainAssetDetails(assetId: "tron/mainnet/coin", name: "TRON", symbol: "TRX", decimals: 6, image: "")
    }

    var bnb: MultichainAssetDetails {
        MultichainAssetDetails(assetId: "bsc/mainnet/coin", name: "BNB", symbol: "BNB", decimals: 18, image: "")
    }

    var usdt: MultichainAssetDetails {
        MultichainAssetDetails(assetId: "tron/mainnet/trc20/usdt", name: "Tether", symbol: "USD₮", decimals: 6, image: "")
    }

    func summary(
        _ feeOptions: [MultichainSwapFeeOption],
        picked: MultichainSwapFeeMethod? = nil,
        amountBlockedAssetId: String? = nil
    ) -> MultichainSwapFeeSummary? {
        MultichainSwapFeeSummary(
            plan: .ready(feeOptions: feeOptions, networkFees: []),
            picked: picked,
            amountBlockedAssetId: amountBlockedAssetId
        )
    }

    func battery(charges: Int, available: Int?, isInsufficient: Bool = false) -> MultichainSwapFeeOption {
        MultichainSwapFeeOption(
            cost: .batteryCharges(count: charges, excess: nil, isInsufficient: isInsufficient),
            availableCharges: available
        )
    }

    func native(fee: BigUInt, isInsufficient: Bool = false) -> MultichainSwapFeeOption {
        MultichainSwapFeeOption(
            cost: .native([MultichainTransactionEmulationResult(fee: fee, asset: trx)], isInsufficient: isInsufficient)
        )
    }
}
