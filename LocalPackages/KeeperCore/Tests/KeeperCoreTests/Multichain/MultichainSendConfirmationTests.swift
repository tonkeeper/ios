import BigInt
@testable import KeeperCore
import XCTest

final class MultichainSendConfirmationTests: XCTestCase {
    func test_exactInsufficientBalanceProducesBlockingFeeOption() throws {
        let emulation = MultichainTransactionEmulationResult(
            fee: 21,
            asset: feeAsset,
            isInsufficientBalance: true
        )

        let option = try XCTUnwrap(
            MultichainTransactionConfirmationController.chainKitExtraOptions(
                emulation: emulation
            )?.first
        )

        XCTAssertTrue(option.isInsufficient)
        XCTAssertEqual(
            MultichainTransactionConfirmationController.chainKitAmount(
                requestedAmount: 100,
                emulation: emulation
            ),
            100
        )
        XCTAssertFalse(
            MultichainTransactionConfirmationController.chainKitIsMax(
                requestedIsMax: false,
                emulation: emulation
            )
        )
    }

    func test_maxAdjustedAmountIsDisplayedAndRemainsMax() {
        let emulation = MultichainTransactionEmulationResult(
            fee: 21,
            asset: feeAsset,
            adjustedAmount: 79,
            isMaxAmount: true
        )

        XCTAssertEqual(
            MultichainTransactionConfirmationController.chainKitAmount(
                requestedAmount: 100,
                emulation: emulation
            ),
            79
        )
        XCTAssertTrue(
            MultichainTransactionConfirmationController.chainKitIsMax(
                requestedIsMax: true,
                emulation: emulation
            )
        )
        XCTAssertNil(
            MultichainTransactionConfirmationController.chainKitExtraOptions(
                emulation: emulation
            )
        )
    }

    private var feeAsset: MultichainAssetDetails {
        MultichainAssetDetails(
            assetId: "eth/mainnet/coin",
            name: "Ethereum",
            symbol: "ETH",
            decimals: 18,
            image: ""
        )
    }
}
