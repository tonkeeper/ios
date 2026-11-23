@testable import KeeperCore
import TonSwift
import XCTest

final class WalletMigrationV5BetaSigningTests: XCTestCase {
    func test_signsThePreparedW5BetaBodyUnchanged() throws {
        let wallet = Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5Beta)
            ),
            metaData: WalletMetaData(label: "wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
        let transfer = try MessageRelaxed.internal(to: wallet.address, value: 1_000_000_000)
        let preparedBody = try wallet.contract.createTransfer(
            args: WalletTransferData(
                seqno: 387,
                messages: [transfer],
                sendMode: .walletDefault(),
                timeout: 1_794_237_404
            ),
            messageType: .ext
        ).signingMessage.endCell()
        let signer = WalletTransferEmptyKeySigner()

        let signedBOC = try WalletMigrationTransactionSigner.signAndBuildExternalMessageBOC(
            transaction: WalletMigrationPreparedTransaction(
                seqno: 387,
                boc: preparedBody.toBoc().base64EncodedString(),
                messages: [
                    WalletMigrationOutMessage(
                        boc: Builder().store(transfer).endCell().toBoc().base64EncodedString(),
                        mode: 3
                    ),
                ],
                event: AccountEvent(
                    eventId: "387",
                    date: Date(timeIntervalSince1970: 0),
                    account: WalletAccount(address: wallet.address, name: nil, isScam: false, isWallet: true),
                    isScam: false,
                    isInProgress: false,
                    extra: .Fee(0),
                    excess: nil,
                    progress: nil,
                    actions: []
                ),
                totalEquivalent: nil
            ),
            wallet: wallet,
            signer: signer
        )

        let signedBody = try Message.loadFrom(slice: Cell.fromBase64(src: signedBOC).beginParse()).body
        let expectedBody = try Builder()
            .store(slice: preparedBody.beginParse())
            .store(data: signer.signMessage(preparedBody.hash()))
            .endCell()
        XCTAssertEqual(signedBody, expectedBody)
    }
}
