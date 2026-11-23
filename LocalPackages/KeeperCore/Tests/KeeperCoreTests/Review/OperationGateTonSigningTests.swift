import ChainKit
import Foundation
@testable import KeeperCore
import OperationReviewModels
import TonSwift
import XCTest

/// The gate a TON engine's signature goes through: the request built from what the App is handed to
/// sign is read beside the signature, which does not wait for it, and only logged.
final class OperationGateTonSigningTests: XCTestCase {
    private static let intent = OperationIntent.wallet(
        spending: [OperationIntent.Spend(assetId: "ton/mainnet/coin", symbol: "GRAM", decimals: 9, amount: 1_000_000_000)],
        to: "0:0000000000000000000000000000000000000000000000000000000000000001"
    )

    /// chain-kit may look a jetton's wallet up on the network to read the request, and nothing
    /// cancels that: the check here reads only once the request is signed. What it finds is logged
    /// as the flow's, and stops nothing.
    func test_theRequestIsReadWithoutHoldingItsSignatureUpAndAFindingNeverStopsIt() async throws {
        let events = Events()
        let log = RecordedLog()
        defer { log.stop() }
        let wallet = legacyWallet()
        let transferData = try transfer(from: wallet)
        let sign = OperationGate { [RequestCheck(events: events)] }.clearing(
            signing(into: events),
            account: ChainKitOperationSender.tonAccount,
            intent: Self.intent
        )

        let signed = try await sign(transferData, wallet)
        let logged = try await log.record("Operation review found what would ask in a flow it only logs")

        let request = try await UnsignedTransferBuilder(transferData: transferData).createUnsignedWalletTransfer(wallet: wallet)
        let read = try RequestCheck.Read(
            operationId: SignableOperation.TonRequest(signing: request).hash,
            isExtMsg: true,
            fidelity: .converted,
            address: ChainKitOperationSender.tonAccount(of: wallet).addressDisplay,
            intent: Self.intent
        )
        let recorded = await events.all
        XCTAssertEqual(recorded, [.signed, .read(read)])
        XCTAssertEqual(signed, ["signed"])
        XCTAssertEqual(logged?.file, "KeeperCoreTests/OperationGateTonSigningTests.swift")
    }

    func test_withoutChecksNothingIsBuiltAndTheTransferIsSigned() async throws {
        let events = Events()
        let wallet = legacyWallet()
        let sign = OperationGate { [] }.clearing(
            signing(into: events),
            account: { _ in
                XCTFail("built an account no check reads")
                throw UnusedStub()
            },
            intent: Self.intent
        )

        _ = try await sign(transfer(from: wallet), wallet)

        let recorded = await events.all
        XCTAssertEqual(recorded, [.signed])
    }

    func test_aRequestNoCheckCouldReadIsStillSigned() async throws {
        let events = Events()
        let log = RecordedLog()
        defer { log.stop() }
        let wallet = legacyWallet()
        let sign = OperationGate { [FailingCheck()] }.clearing(signing(into: events), account: ChainKitOperationSender.tonAccount, intent: Self.intent)

        _ = try await sign(transfer(from: wallet), wallet)
        let failure = try await log.record("Operation review could not check what is signed")

        let recorded = await events.all
        XCTAssertEqual(recorded, [.signed])
        XCTAssertNotNil(failure)
    }
}

private extension OperationGateTonSigningTests {
    func signing(into events: Events) -> OperationGate.TonSigning {
        { _, _ in
            await events.append(.signed)
            return ["signed"]
        }
    }

    func transfer(from wallet: Wallet) throws -> TransferData {
        try TransferData(
            transfer: .ton(TransferData.Ton(
                amount: 1_000_000_000,
                isMax: false,
                recipient: Address.parse("0:0000000000000000000000000000000000000000000000000000000000000001"),
                comment: "Tron gas fee"
            )),
            wallet: wallet,
            messageType: .ext,
            seqno: 7,
            timeout: 1_790_000_600
        )
    }
}

/// What was read and signed, in order.
private actor Events {
    enum Event: Equatable {
        case read(RequestCheck.Read)
        case signed
    }

    private(set) var all = [Event]()

    func append(_ event: Event) {
        all.append(event)
    }

    /// Waits up to five seconds for `event`.
    func wait(for event: Event) async throws {
        for _ in 0 ..< 500 where !all.contains(event) {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

/// Reads a request only once it is signed, or after five seconds, as a lookup on the network would
/// outlast the signature; finds a warning in every request it reads, and keeps what it read.
private struct RequestCheck: OperationCheck {
    struct Read: Equatable {
        let operationId: String
        let isExtMsg: Bool
        let fidelity: SignableOperation.Fidelity
        let address: String
        let intent: OperationIntent
    }

    let events: Events

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        try await events.wait(for: .signed)
        let prebuild = signable.operation.payloads.first?.meta as? PayloadMetaTonPrebuild
        await events.append(.read(Read(
            operationId: signable.operation.id,
            isExtMsg: prebuild?.format == .extmsg,
            fidelity: signable.fidelity,
            address: signable.account.addressDisplay,
            intent: signable.intent
        )))
        return [OperationFinding(id: signable.operation.id, kind: "StubWarning", severity: .warning, title: "Finding")]
    }
}
