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

    func test_aRelayedFeeSendsTheWholeMaxAmount() {
        let relayedFees = [
            EVMGaslessFeeOption(payer: .battery(charges: 1), relayerAssetId: "battery/mainnet"),
            EVMGaslessFeeOption(payer: .token(usdc, fee: 115_304), relayerAssetId: usdc.assetId),
        ]

        for fee in relayedFees {
            XCTAssertEqual(
                MultichainTransactionConfirmationController.sentAmount(
                    requestedAmount: 100,
                    emulation: maxEmulation,
                    selectedEVMFee: fee
                ),
                100
            )
        }
    }

    func test_theCoinPayingItsOwnFeeSendsTheMaxAmountLessTheGas() {
        XCTAssertEqual(
            MultichainTransactionConfirmationController.sentAmount(
                requestedAmount: 100,
                emulation: maxEmulation,
                selectedEVMFee: EVMGaslessFeeOption(payer: .native(feeAsset, fee: 21), relayerAssetId: nil)
            ),
            79
        )
    }

    func test_withoutARelayedFeeTheMaxAmountLeavesTheGas() {
        XCTAssertEqual(
            MultichainTransactionConfirmationController.sentAmount(
                requestedAmount: 100,
                emulation: maxEmulation,
                selectedEVMFee: nil
            ),
            79
        )
    }

    private var maxEmulation: MultichainTransactionEmulationResult {
        MultichainTransactionEmulationResult(
            fee: 21,
            asset: feeAsset,
            adjustedAmount: 79,
            isMaxAmount: true
        )
    }

    private var usdc: MultichainAssetDetails {
        MultichainAssetDetails(
            assetId: "eth/mainnet/erc20/0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
            name: "USD Coin",
            symbol: "USDC",
            decimals: 6,
            image: ""
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
