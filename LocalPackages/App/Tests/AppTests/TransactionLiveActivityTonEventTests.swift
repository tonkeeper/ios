@testable import App
import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

@available(iOS 16.2, *)
final class TransactionLiveActivityTonEventTests: XCTestCase {
    func test_jettonSendNamesTheRecipientsOwnWalletInFriendlyForm() throws {
        let own = try account(fill: "1")
        let recipient = try account(fill: "2")
        let recipientJettonWallet = try Address.parse("0:" + String(repeating: "3", count: 64))
        let transfer = try AccountEventAction(
            type: .jettonTransfer(AccountEventAction.JettonTransfer(
                sender: own,
                recipient: recipient,
                senderAddress: Address.parse("0:" + String(repeating: "4", count: 64)),
                recipientAddress: recipientJettonWallet,
                amount: 5_000_000,
                jettonInfo: JettonInfo(
                    isTransferable: true,
                    hasCustomPayload: false,
                    address: Address.parse("0:" + String(repeating: "5", count: 64)),
                    fractionDigits: 6,
                    name: "Tether USD",
                    symbol: "USDT",
                    verification: .whitelist,
                    imageURL: nil
                ),
                comment: nil,
                encryptedComment: nil
            )),
            status: .ok,
            preview: AccountEventAction.SimplePreview(
                name: "USDT",
                description: "",
                image: nil,
                value: nil,
                fiatValue: nil,
                valueImage: nil,
                accounts: [recipient]
            )
        )
        let event = AccountEvent(
            eventId: "ABC",
            date: Date(),
            account: own,
            isScam: false,
            isInProgress: true,
            extra: .Fee(0),
            excess: nil,
            progress: nil,
            actions: [transfer]
        )

        let snapshot = TransactionLiveActivitySnapshot(event: event, wallet: makeWallet())

        XCTAssertEqual(snapshot.kind, .send)
        XCTAssertEqual(snapshot.status, .pending)
        XCTAssertEqual(
            snapshot.counterpartyAddress,
            recipient.address.toFriendly(testOnly: false, bounceable: false).toString()
        )
        XCTAssertNotEqual(
            snapshot.counterpartyAddress,
            recipientJettonWallet.toFriendly(testOnly: false, bounceable: false).toString()
        )
        XCTAssertEqual(snapshot.source?.currency, "USDT")
        XCTAssertNotNil(snapshot.source?.amount)
    }

    private func account(fill: Character) throws -> WalletAccount {
        try WalletAccount(
            address: Address.parse("0:" + String(repeating: fill, count: 64)),
            name: nil,
            isScam: false,
            isWallet: true
        )
    }

    private func makeWallet() -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(PublicKey(data: Data(repeating: 0x01, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: nil
        )
    }
}
