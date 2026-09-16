@testable import KeeperCore
import TonSwift
import XCTest

final class TransactionConfirmationHistoryFeedTests: XCTestCase {
    /// The legacy TRON feed carries USDT transfers only, so sending TRX from such a wallet has no
    /// history to land on.
    func test_trxFromLegacyWallet_hasNoFeed() {
        let model = makeModel(transfer: .tronTRX, isMultichain: false)

        XCTAssertFalse(model.hasHistoryFeed)
    }

    func test_trxFromMultichainWallet_hasFeed() {
        let model = makeModel(transfer: .tronTRX, isMultichain: true)

        XCTAssertTrue(model.hasHistoryFeed)
    }

    func test_tronUsdtFromLegacyWallet_hasFeed() {
        let model = makeModel(transfer: .tronUSDT, isMultichain: false)

        XCTAssertTrue(model.hasHistoryFeed)
    }

    func test_tonFromLegacyWallet_hasFeed() {
        let model = makeModel(transfer: .ton(false), isMultichain: false)

        XCTAssertTrue(model.hasHistoryFeed)
    }
}

private extension TransactionConfirmationHistoryFeedTests {
    func makeModel(
        transfer: TransactionConfirmationModel.Transaction.Transfer,
        isMultichain: Bool
    ) -> TransactionConfirmationModel {
        TransactionConfirmationModel(
            wallet: makeWallet(isMultichain: isMultichain),
            recipient: nil,
            recipientAddress: nil,
            transaction: .transfer(transfer),
            amount: nil,
            extraState: .none,
            availableExtraTypes: [],
            totalFee: 0
        )
    }

    func makeWallet(isMultichain: Bool) -> Wallet {
        Wallet(
            id: "transaction-confirmation-history-feed-tests",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(PublicKey(data: Data(repeating: 0x01, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: "Test", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: isMultichain
                ? .multichain(
                    MultichainWalletState(
                        walletId: "multichain",
                        addresses: [
                            MultichainWalletAddress(chain: .tron, address: "TWS1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"),
                        ]
                    )
                )
                : nil
        )
    }
}
