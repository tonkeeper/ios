import BigInt
@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import XCTest

final class SignedInternalMessageTests: XCTestCase {
    private let publicKey = Data(strictHex: "5754865e86d0ade1199301bbb0319a25ed6b129c4b0a57f28f62449b3df9c522")!
    private let secretKey = Data(strictHex: "34aebb9ea454967f16c407c0f8877763e86212116468169d93a3dcbcafe530c95754865e86d0ade1199301bbb0319a25ed6b129c4b0a57f28f62449b3df9c522")!
    private let recipient = "Ef8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAU"

    func testAddressesInternalMessageToWalletItself() async throws {
        let wallet = makeWallet()

        let message = try await signedInternalMessage(wallet: wallet, seqno: 7)

        guard case let .internalInfo(info) = message.info else {
            return XCTFail("Expected an internal message, got \(message.info)")
        }
        XCTAssertEqual(info.dest, try wallet.address)
        XCTAssertFalse(info.bounce)
        XCTAssertEqual(info.value.coins.rawValue, 0)
    }

    func testCarriesInternalSignedRequestWithSendModeThree() async throws {
        let message = try await signedInternalMessage(wallet: makeWallet(), seqno: 7)

        let body = try message.body.beginParse()
        XCTAssertEqual(try body.loadUint(bits: 32), UInt64(UInt32(bitPattern: OpCodes.SIGNED_INTERNAL)))
        try body.skip(32 + 32 + 32)
        XCTAssertEqual(try sendModes(outList: XCTUnwrap(body.loadMaybeRef())), [3, 3])
    }

    func testKeepsSignedBodyOfExternalMessage() async throws {
        let wallet = makeWallet()
        let externalBoc = try await signedExternalBoc(wallet: wallet, seqno: 7)

        let internalMessage = try MessageRelaxed.loadFrom(
            slice: Cell.fromBase64(src: SignedInternalMessage.boc(fromExternalBoc: externalBoc, wallet: wallet)).beginParse()
        )
        let externalMessage = try Message.loadFrom(slice: Cell.fromBase64(src: externalBoc).beginParse())

        XCTAssertEqual(try internalMessage.body.hash(), try externalMessage.body.hash())
    }

    func testAttachesStateInitOnlyForUndeployedWallet() async throws {
        let wallet = makeWallet()

        let deployed = try await signedInternalMessage(wallet: wallet, seqno: 7)
        let undeployed = try await signedInternalMessage(wallet: wallet, seqno: 0)

        XCTAssertNil(deployed.stateInit)
        XCTAssertEqual(
            try undeployed.stateInit.map { try Builder().store($0).endCell().hash() },
            try Builder().store(wallet.contract.stateInit).endCell().hash()
        )
    }

    private func signedInternalMessage(wallet: Wallet, seqno: UInt64) async throws -> MessageRelaxed {
        let externalBoc = try await signedExternalBoc(wallet: wallet, seqno: seqno)
        let internalBoc = try SignedInternalMessage.boc(fromExternalBoc: externalBoc, wallet: wallet)
        return try MessageRelaxed.loadFrom(slice: Cell.fromBase64(src: internalBoc).beginParse())
    }

    private func signedExternalBoc(wallet: Wallet, seqno: UInt64) async throws -> String {
        let payload = try TransferData.TonConnect.Payload(
            value: 50_000_000,
            recipientAddress: .friendlyAddress(FriendlyAddress(string: recipient)),
            stateInit: nil,
            payload: nil
        )
        let transferData = TransferData(
            transfer: .tonConnect(TransferData.TonConnect(payloads: [payload, payload], sender: nil)),
            wallet: wallet,
            messageType: .int,
            seqno: seqno,
            timeout: 1_900_000_000
        )
        let walletTransfer = try await UnsignedTransferBuilder(transferData: transferData)
            .createUnsignedWalletTransfer(wallet: wallet)
        return try TransferSigner.signWalletTransfer(
            walletTransfer,
            wallet: wallet,
            seqno: seqno,
            signer: WalletTransferSecretKeySigner(secretKey: secretKey)
        ).toBoc().base64EncodedString()
    }

    private func sendModes(outList: Cell) throws -> [UInt64] {
        let slice = try outList.beginParse()
        guard slice.remainingBits > 0 else {
            return []
        }
        XCTAssertEqual(try slice.loadUint(bits: 32), UInt64(OpCodes.OUT_ACTION_SEND_MSG_TAG))
        let mode = try slice.loadUint(bits: 8)
        return try sendModes(outList: slice.loadRef()) + [mode]
    }

    private func makeWallet() -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: publicKey), .v5R1)
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: nil
        )
    }
}
