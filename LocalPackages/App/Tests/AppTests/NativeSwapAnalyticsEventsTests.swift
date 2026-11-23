@testable import App
import BigInt
@testable import KeeperCore
import TKCore
import TonSwift
import XCTest

final class NativeSwapAnalyticsEventsTests: XCTestCase {
    func test_failedEvent_carriesTheReasonCodeAmountAndProvider() {
        let model = makeModel(fromAmount: 1_500_000_000, resolverName: "DeDust")
        let reason = "failed to single default send due to error: 500 cannot apply external message"

        let event = model.failedEvent(
            feePaidIn: "battery",
            error: TransactionConfirmationError.failedToSendTransaction(message: reason)
        )

        XCTAssertEqual(event.name, "swap_failed")
        XCTAssertEqual(event.params["error_message"] as? String, reason)
        XCTAssertEqual(event.params["error_code"] as? Int, 2)
        XCTAssertEqual(event.params["amount"] as? Double, 1.5)
        XCTAssertEqual(event.params["provider_name"] as? String, "DeDust")
        XCTAssertEqual(event.params["jetton_symbol_from"] as? String, "ton_ton")
        XCTAssertEqual(event.params["jetton_symbol_to"] as? String, "usdt_trc20")
        XCTAssertEqual(event.params["fee_paid_in"] as? String, "battery")
    }

    func test_failedEvent_tellsSigningApartFromSending() {
        let model = makeModel(fromAmount: 1_000_000_000, resolverName: "STON.fi")

        let event = model.failedEvent(
            feePaidIn: "ton",
            error: TransactionConfirmationError.failedToSign(message: "Unsupported wallet kind for transaction signing")
        )

        XCTAssertEqual(event.params["error_code"] as? Int, 3)
        XCTAssertEqual(event.params["error_message"] as? String, "Unsupported wallet kind for transaction signing")
    }

    func test_failedEvent_reportsAFundsShortageByItsOwnCodeAndMessage() {
        let model = makeModel(fromAmount: 1_000_000_000, resolverName: "STON.fi")
        let shortage = InsufficientFundsError.blockchainFee(wallet: makeWallet(), balance: 100_000_000, amount: 330_000_000)

        let event = model.failedEvent(feePaidIn: "ton", error: shortage)

        XCTAssertEqual(event.params["error_code"] as? Int, 8)
        XCTAssertEqual(event.params["error_message"] as? String, "Insufficient balance to cover blockchain fee")
    }

    /// `send_failed` reports a shortage beside a confirmation's failures and a transfer's errors, and `swap_failed`
    /// beside the first, with no error type to tell them apart.
    func test_shortageCodes_differFromTheOtherFailureCodesOfTheSameEvents() {
        let wallet = makeWallet()
        let shortages: [InsufficientFundsError] = [
            .unknownJetton,
            .blockchainFee(wallet: wallet, balance: 0, amount: 1),
            .insufficientFunds(jettonInfo: nil, balance: 0, requiredAmount: 1, wallet: wallet, isInternalPurchasing: false),
            .tronFee(wallet: wallet, balance: 0, requiredAmount: 1),
        ]
        let otherFailures: [any AnalyticsError] = [
            TransactionConfirmationError.failedToCalculateFee(),
            TransactionConfirmationError.failedToSendTransaction(),
            TransactionConfirmationError.failedToSign(),
            TransactionConfirmationError.cancelledByUser,
            TransferError.nothingToSend,
            TransferError.unsupportedTransfer,
            TransferError.failedToCreateTransferData(message: nil),
            TransferError.noExcessesAddress,
            TransferError.noJettonWalletAddress,
            TransferError.sendFailed(message: nil),
        ]

        XCTAssertTrue(Set(shortages.map(\.code)).isDisjoint(with: otherFailures.map(\.code)))
    }

    func test_confirmAndSuccess_carryTheSameAmountAndProviderAsFailure() {
        let model = makeModel(fromAmount: 2_500_000_000, resolverName: "Tonco")

        for event in [model.confirmEvent(feePaidIn: "ton"), model.successEvent(feePaidIn: "ton")] {
            XCTAssertEqual(event.params["amount"] as? Double, 2.5, event.name)
            XCTAssertEqual(event.params["provider_name"] as? String, "Tonco", event.name)
        }
    }
}

private extension NativeSwapAnalyticsEventsTests {
    func makeWallet() -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(PublicKey(data: Data(repeating: 0x01, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings()
        )
    }

    func makeModel(fromAmount: BigUInt, resolverName: String) -> NativeSwapTransactionConfirmationModel {
        NativeSwapTransactionConfirmationModel(
            fromToken: .ton(.ton),
            toToken: .tron(.usdt),
            fromAmount: fromAmount,
            toAmount: 3_000_000,
            confirmation: SwapConfirmation(
                messages: [],
                quoteId: "quote",
                resolverName: resolverName,
                askUnits: "3000000",
                bidUnits: "\(fromAmount)",
                protocolFeeUnits: "0",
                tradeStartDeadline: "0",
                gasBudget: "0",
                estimatedGasConsumption: "0",
                slippage: 100,
                valueDifferenceBps: nil
            ),
            transactionSentNotificationPatch: { _ in },
            utm: .empty
        )
    }
}
