import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class TransactionConfirmationSendResultTests: XCTestCase {
    /// TON's canonical empty-cell representation hash — sha256 of the two descriptor bytes.
    private let emptyCellHash = "96a296d224f285c67bee93c30f8a309157f0daa35dc5b87e410b78630a09cfc7"

    func test_tonMessageHash_matchesRepresentationHashOfTheBocRootCell() throws {
        XCTAssertEqual(try TonMessageHash.hex(signedBocBase64: signedBoc()), emptyCellHash)
    }

    /// `WalletTransferSignCoordinator` emits `toBoc().base64EncodedString()`, so a hex-encoded
    /// BoC — the encoding used for emulation — must not be silently accepted.
    func test_tonMessageHash_rejectsHexEncodedBoc() throws {
        let hexBoc = try Builder().endCell().toBoc().map { String(format: "%02hhx", $0) }.joined()

        XCTAssertThrowsError(try TonMessageHash.hex(signedBocBase64: hexBoc)) { error in
            XCTAssertTrue(error is TonMessageHash.Failure)
        }
    }

    func test_tonMessageHash_rejectsNonBase64Input() {
        XCTAssertThrowsError(try TonMessageHash.hex(signedBocBase64: "z")) { error in
            XCTAssertEqual(
                (error as? TonMessageHash.Failure)?.logDescription,
                "type=TonMessageHash.Failure, case=undecodableBase64"
            )
        }
    }

    func test_tonMessageHash_rejectsBytesThatAreNotABoc() {
        XCTAssertThrowsError(try TonMessageHash.hex(signedBocBase64: "3q2+7w==")) { error in
            XCTAssertEqual(
                (error as? TonMessageHash.Failure)?.logDescription,
                "type=TonMessageHash.Failure, case=undeserializableBoc"
            )
        }
    }

    func test_ton_recordsOnePendingTransactionPerBroadcastBoc() throws {
        let boc = try signedBoc()

        let result = TransactionConfirmationSendResult.ton(
            wallet: makeWallet(isMultichain: true),
            signedTransactions: [boc, boc],
            activityType: .stake
        )

        XCTAssertEqual(
            result.pendingTransactions,
            (0 ..< 2).map { _ in
                MultichainPendingTransaction(
                    walletId: "wallet",
                    chain: .ton,
                    network: .mainnet,
                    txHash: emptyCellHash,
                    activityType: .stake
                )
            }
        )
    }

    func test_ton_skipsBocsWhoseHashCannotBeDerived() throws {
        let boc = try signedBoc()

        let result = TransactionConfirmationSendResult.ton(
            wallet: makeWallet(isMultichain: true),
            signedTransactions: ["3q2+7w==", boc],
            activityType: .send
        )

        XCTAssertEqual(result.pendingTransactions.map(\.txHash), [emptyCellHash])
    }

    func test_record_reportsBroadcastsOfAMultichainWallet() async {
        let service = PendingTransactionsServiceFake()
        let result = TransactionConfirmationSendResult.chain(
            .tron,
            wallet: makeWallet(isMultichain: true),
            txHashes: ["hash"],
            activityType: .send
        )

        await service.record(result, wallet: makeWallet(isMultichain: true))

        let reported = await service.reported
        XCTAssertEqual(reported.map(\.txHash), ["hash"])
    }

    func test_record_reportsNothingForAWalletWithoutMultichainState() async {
        let service = PendingTransactionsServiceFake()
        let result = TransactionConfirmationSendResult.chain(
            .ton,
            wallet: makeWallet(isMultichain: false),
            txHashes: ["hash"],
            activityType: .stake
        )

        await service.record(result, wallet: makeWallet(isMultichain: false))

        let reported = await service.reported
        XCTAssertTrue(result.pendingTransactions.isEmpty)
        XCTAssertTrue(reported.isEmpty)
    }

    func test_chain_usesTestnetForATestnetWallet() {
        let result = TransactionConfirmationSendResult.chain(
            .ton,
            wallet: makeWallet(isMultichain: true, network: .testnet),
            txHashes: ["hash"],
            activityType: .send
        )

        XCTAssertEqual(result.pendingTransactions.map(\.network), [.testnet])
    }
}

private extension TransactionConfirmationSendResultTests {
    /// Matches what `WalletTransferSignCoordinator` hands to the confirmation controllers.
    func signedBoc() throws -> String {
        try Builder().endCell().toBoc().base64EncodedString()
    }

    func makeWallet(isMultichain: Bool, network: Network = .mainnet) -> Wallet {
        let publicKey = TonSwift.PublicKey(data: Data(repeating: 1, count: 32))
        return Wallet(
            id: "wallet",
            identity: WalletIdentity(network: network, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: isMultichain
                ? .multichain(
                    MultichainWalletState(
                        walletId: "wallet",
                        addresses: [
                            MultichainWalletAddress(chain: .ton, address: "ton-address"),
                        ]
                    )
                )
                : .unavailable
        )
    }
}
