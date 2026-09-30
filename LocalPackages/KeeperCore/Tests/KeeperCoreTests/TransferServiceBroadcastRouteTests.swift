import BigInt
@testable import KeeperCore
import TonSwift
import XCTest

/// The fee payer and the broadcast endpoint are separate decisions: a relayed transfer can only go
/// through the battery, while an ordinary external message may still be posted there as a transport
/// so the battery attributes it to the wallet id.
final class TransferServiceBroadcastRouteTests: XCTestCase {
    func test_defaultTransferType_goesToTonAPI() throws {
        XCTAssertEqual(
            try TransferService.broadcastRoute(transfer: makeSignRaw(broadcast: .tonAPI), transferType: .default),
            .tonAPI
        )
        XCTAssertEqual(
            TransferService.broadcastRoute(transfer: makeTonTransfer(), transferType: .default),
            .tonAPI
        )
    }

    func test_defaultTransferTypeAskingForBatteryBroadcast_usesBatteryAsTransport() throws {
        XCTAssertEqual(
            try TransferService.broadcastRoute(transfer: makeSignRaw(broadcast: .battery), transferType: .default),
            .batteryTransport
        )
    }

    /// The relayer pays the fee, so the battery is the only endpoint that can deliver the message,
    /// whatever transport the caller asked for.
    func test_relayedTransferTypes_goToBatteryRelayRegardlessOfBroadcast() throws {
        let excessAddress = try Address.parse(Self.rawAddress)
        for broadcast in [Transfer.Broadcast.tonAPI, .battery] {
            let transfer = try makeSignRaw(broadcast: broadcast)
            XCTAssertEqual(
                TransferService.broadcastRoute(transfer: transfer, transferType: .battery(excessAddress: excessAddress)),
                .batteryRelay
            )
            XCTAssertEqual(
                TransferService.broadcastRoute(
                    transfer: transfer,
                    transferType: .gasless(excessAddress: excessAddress, fee: 1)
                ),
                .batteryRelay
            )
        }
    }

    /// Asking for the battery transport must not turn the battery into the fee payer.
    func test_batteryBroadcast_doesNotEnableRelayer() throws {
        let transfer = try makeSignRaw(forceRelayer: false, broadcast: .battery)

        XCTAssertFalse(TransferService.isRelayerEnabled(wallet: makeWallet(), transfer: transfer))
        XCTAssertTrue(transfer.broadcastsThroughBattery)
        XCTAssertFalse(try makeSignRaw(forceRelayer: false, broadcast: .tonAPI).broadcastsThroughBattery)
    }
}

private extension TransferServiceBroadcastRouteTests {
    static let rawAddress = "0:0000000000000000000000000000000000000000000000000000000000000001"

    func makeSignRaw(forceRelayer: Bool = false, broadcast: Transfer.Broadcast) throws -> Transfer {
        try .signRaw(
            SignRawRequest(
                messages: [
                    SignRawRequestMessage(
                        address: AnyAddress(rawAddress: Self.rawAddress),
                        amount: 100_000_000,
                        stateInit: nil,
                        payload: nil
                    ),
                ],
                validUntil: nil,
                from: Address.parse(Self.rawAddress),
                messagesVariants: nil
            ),
            forceRelayer: forceRelayer,
            broadcast: broadcast
        )
    }

    func makeTonTransfer() -> Transfer {
        .ton(
            amount: 1,
            recipient: TonRecipient(
                recipientAddress: .raw(try! Address.parse(Self.rawAddress)),
                isMemoRequired: false,
                isScam: false
            ),
            comment: nil
        )
    }

    func makeWallet() -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}
