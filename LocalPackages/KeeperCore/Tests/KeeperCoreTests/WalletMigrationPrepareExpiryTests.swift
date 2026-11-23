@testable import KeeperCore
import TonSwift
import XCTest

final class WalletMigrationPrepareExpiryTests: XCTestCase {
    func test_validUntilReadsPreparedBodiesOfEveryLayout() throws {
        let w5Body = try Builder()
            .store(uint: 0x7369_676E, bits: 32)
            .store(uint: 0x7FFF_FF11, bits: 32)
            .store(uint: 1_794_237_404, bits: 32)
            .store(uint: 387, bits: 32)
            .endCell()
        let w5BetaBody = try Builder()
            .store(uint: 0x7369_676E, bits: 32)
            .store(int: -239, bits: 32)
            .store(int: 0, bits: 8)
            .store(uint: 0, bits: 8)
            .store(uint: 0, bits: 32)
            .store(uint: 1_794_237_404, bits: 32)
            .store(uint: 387, bits: 32)
            .endCell()
        let v4Body = try Builder()
            .store(uint: 698_983_191, bits: 32)
            .store(uint: 1_794_237_404, bits: 32)
            .store(uint: 12, bits: 32)
            .store(uint: 0, bits: 8)
            .endCell()

        XCTAssertEqual(try validUntil(of: w5Body, version: .v5R1), 1_794_237_404)
        XCTAssertEqual(try validUntil(of: w5BetaBody, version: .v5Beta), 1_794_237_404)
        XCTAssertEqual(try validUntil(of: v4Body, version: .v4R2), 1_794_237_404)
    }

    func test_preparationAboutToExpireIsPreparedAgain() async throws {
        let now = Date()
        let prepared = makeResult(seqno: 1, validUntil: now.addingTimeInterval(59))

        let signable = try await prepared.refreshedIfExpiring(at: now) {
            makeResult(seqno: 2, validUntil: now.addingTimeInterval(300))
        }

        XCTAssertEqual(signable.transactions.map(\.seqno), [2])
    }

    func test_preparationWithTimeLeftIsSignedAsPrepared() async throws {
        let now = Date()
        let prepared = makeResult(seqno: 1, validUntil: now.addingTimeInterval(61))
        var preparedAgain = false

        let signable = try await prepared.refreshedIfExpiring(at: now) {
            preparedAgain = true
            return makeResult(seqno: 2, validUntil: now.addingTimeInterval(300))
        }

        XCTAssertFalse(preparedAgain)
        XCTAssertEqual(signable.transactions.map(\.seqno), [1])
    }

    func test_preparationWithUnreadableExpiryIsPreparedAgain() async throws {
        let now = Date()
        let prepared = makeResult(seqno: 1, validUntil: nil)

        let signable = try await prepared.refreshedIfExpiring(at: now) {
            makeResult(seqno: 2, validUntil: now.addingTimeInterval(300))
        }

        XCTAssertEqual(signable.transactions.map(\.seqno), [2])
    }
}

private func validUntil(of body: Cell, version: WalletContractVersion) throws -> UInt64 {
    try WalletMigrationTransactionSigner.validUntil(
        preparedBodyBOC: body.toBoc().base64EncodedString(),
        wallet: Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), version)
            ),
            metaData: WalletMetaData(label: "wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    )
}

private func makeResult(seqno: Int, validUntil: Date?) -> WalletMigrationPrepareResult {
    let account = WalletAccount(
        address: try! Address.parse("EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"),
        name: nil,
        isScam: false,
        isWallet: true
    )
    return WalletMigrationPrepareResult(
        from: "from",
        to: "to",
        walletVersion: "v5R1",
        transactions: [
            WalletMigrationPreparedTransaction(
                seqno: seqno,
                boc: "te6cckEBAQEAAgAAAA==",
                event: AccountEvent(
                    eventId: "\(seqno)",
                    date: Date(timeIntervalSince1970: 0),
                    account: account,
                    isScam: false,
                    isInProgress: false,
                    extra: .Fee(0),
                    excess: nil,
                    progress: nil,
                    actions: []
                ),
                totalEquivalent: nil,
                validUntil: validUntil
            ),
        ]
    )
}
