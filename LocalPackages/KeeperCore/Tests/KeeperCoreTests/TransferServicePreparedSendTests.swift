import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

/// `sendTransaction` is `prepare`, the signature, then `broadcast`: what is signed is the transfer
/// prepared, and it goes out the way it was prepared for — through the battery for a relayed one.
final class TransferServicePreparedSendTests: XCTestCase {
    private struct Refused: Error {}

    func test_deviceSessionFailureKeepsTheTonAPITransportFallback() async throws {
        for failure: DeviceAuthError in [.connectionError, .failed(message: "503"), .cancelled] {
            let fixture = try TonBatteryRelayFixture()
            fixture.calls.relayError = BatteryAuthorizationError.deviceSessionFailure(failure)
            fixture.calls.allowsTonAPISend = true
            let wallet = makeWallet()
            let address = try wallet.address
            let transfer = try Transfer.signRaw(SignRawRequest(
                messages: [.init(address: AnyAddress(rawAddress: address.toRaw()), amount: 1, stateInit: nil, payload: nil)],
                validUntil: nil, from: address, messagesVariants: nil
            ), forceRelayer: false, broadcast: .battery)
            let service = fixture.transferService()
            let prepared = try await service.prepare(wallet: wallet, transfer: transfer, transferType: .default)

            do {
                try await service.broadcast(SignedTransactions(boc: "signed"), wallet: wallet, prepared: prepared)
            } catch {
                XCTFail("Expected TONAPI fallback: \(error)")
            }

            XCTAssertTrue(fixture.calls.recorded.contains("tonapi"))
            XCTAssertTrue(fixture.calls.relayed.isEmpty)
        }
    }

    func test_deviceSessionFailuresDoNotTurnUnknownChargesIntoZero() async throws {
        let fixture = try TonBatteryRelayFixture()
        let reader = BatteryChargesReader(batteryService: fixture.batteryService, batteryCalculation: BatteryCalculation(configuration: fixture.configuration))
        for failure: DeviceAuthError in [.connectionError, .failed(message: "503"), .cancelled] {
            fixture.calls.balanceError = BatteryAuthorizationError.deviceSessionFailure(failure)
            let availability = await reader.currentCharges(wallet: makeWallet())
            XCTAssertEqual(availability, .unknown)
            XCTAssertNil(availability.count)
        }
        fixture.calls.balanceError = BatteryAuthorizationError.unavailable
        let unavailable = await reader.currentCharges(wallet: makeWallet())
        XCTAssertEqual(unavailable, .unavailable)
        XCTAssertEqual(unavailable.count, 0)
    }

    func test_cancelledCallerDoesNotUseTheTonAPIFallback() async throws {
        let fixture = try TonBatteryRelayFixture()
        fixture.calls.relayError = BatteryAuthorizationError.deviceSessionFailure(.cancelled)
        fixture.calls.allowsTonAPISend = true
        let wallet = makeWallet()
        let address = try wallet.address
        let transfer = try Transfer.signRaw(SignRawRequest(
            messages: [.init(address: AnyAddress(rawAddress: address.toRaw()), amount: 1, stateInit: nil, payload: nil)],
            validUntil: nil, from: address, messagesVariants: nil
        ), forceRelayer: false, broadcast: .battery)
        let service = fixture.transferService()
        let prepared = try await service.prepare(wallet: wallet, transfer: transfer, transferType: .default)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                try await service.broadcast(SignedTransactions(boc: "signed"), wallet: wallet, prepared: prepared)
                XCTFail("Expected caller cancellation")
            } catch {}
        }
        await task.value
        XCTAssertFalse(fixture.calls.recorded.contains("tonapi"))
        XCTAssertTrue(fixture.calls.relayed.isEmpty)
    }

    func test_aTransferIsSignedAsPreparedAndSentTheWayItWasPreparedFor() async throws {
        let fixture = try TonBatteryRelayFixture()
        let service = fixture.transferService()
        let wallet = makeWallet()
        var signed = [TransferData]()

        let sent = try await service.sendTransaction(
            wallet: wallet,
            transfer: makeTransfer(),
            transferType: .battery(excessAddress: wallet.address),
            signClosure: { transferData -> Result<SignedTransactions, Refused> in
                signed.append(transferData)
                return .success(SignedTransactions(boc: "signed"))
            }
        )
        let prepared = try await service.prepare(
            wallet: wallet,
            transfer: makeTransfer(),
            transferType: .battery(excessAddress: wallet.address)
        )
        try await service.broadcast(SignedTransactions(boc: "prepared"), wallet: wallet, prepared: prepared)

        XCTAssertEqual(sent.bocs, ["signed"])
        XCTAssertEqual(signed.map(\.seqno), [7])
        XCTAssertEqual(signed.map(\.timeout), [TonBatteryRelayFixture.timeout])
        XCTAssertEqual(prepared.transferData.seqno, 8)
        XCTAssertEqual(fixture.calls.recorded, ["seqno", "relay", "seqno", "relay"])
        XCTAssertEqual(fixture.calls.relayed, ["signed", "prepared"])
    }

    /// A W5 wallet signs an internal message, and the chain gets it inside the relayer's own message,
    /// so the send is known by that message's hash. Another wallet signs an external message, and
    /// the relayer's message only tops the wallet up.
    func test_aRelayedInternalMessageIsKnownByTheRelayersMessage() async throws {
        let fixture = try TonBatteryRelayFixture()
        fixture.calls.relayerMessageHash = "relayer"
        let service = fixture.transferService()

        var hashes = [String?]()
        for contract in [WalletContractVersion.v5R1, .v4R2] {
            let wallet = makeWallet(contract: contract)
            let sent = try await service.sendTransaction(
                wallet: wallet,
                transfer: makeTransfer(),
                transferType: .battery(excessAddress: wallet.address),
                signClosure: { _ -> Result<SignedTransactions, Refused> in .success(SignedTransactions(boc: "signed")) }
            )
            hashes.append(sent.relayerMessageHash(for: "signed"))
        }

        XCTAssertEqual(hashes, ["relayer", nil])
    }

    /// The excess address a caller hands over is a fallback: a relayed jetton returns its spare TON
    /// to the battery's own account, which the relay was priced against.
    func test_aRelayedJettonReturnsItsExcessToTheBattery() async throws {
        let fixture = try TonBatteryRelayFixture()
        let wallet = makeWallet()

        let prepared = try await fixture.transferService().prepare(
            wallet: wallet,
            transfer: makeJettonTransfer(),
            transferType: .battery(excessAddress: wallet.address)
        )

        guard case let .jetton(jetton) = prepared.transferData.transfer else {
            return XCTFail("expected a jetton transfer, got \(prepared.transferData.transfer)")
        }
        XCTAssertEqual(jetton.responseAddress, try Address.parse(TonBatteryRelayFixture.excessAccount))
    }

    func test_nothingSignedIsNothingSent() async throws {
        let fixture = try TonBatteryRelayFixture()
        let wallet = makeWallet()
        let transfer = try makeTransfer()
        let excessAddress = try wallet.address

        do {
            _ = try await fixture.transferService().sendTransaction(
                wallet: wallet,
                transfer: transfer,
                transferType: .battery(excessAddress: excessAddress),
                signClosure: { _ -> Result<SignedTransactions, Refused> in .success([]) }
            )
            XCTFail("expected an empty signature to fail")
        } catch {
            guard case .firstOption(.nothingToSend) = error else {
                return XCTFail("expected nothing to send, got \(error)")
            }
        }
        XCTAssertTrue(fixture.calls.relayed.isEmpty)
    }

    func test_aRefusedSignatureIsTheSignersErrorAndNothingIsSent() async throws {
        let fixture = try TonBatteryRelayFixture()
        let wallet = makeWallet()
        let transfer = try makeTransfer()
        let excessAddress = try wallet.address

        do {
            _ = try await fixture.transferService().sendTransaction(
                wallet: wallet,
                transfer: transfer,
                transferType: .battery(excessAddress: excessAddress),
                signClosure: { _ -> Result<SignedTransactions, Refused> in .failure(Refused()) }
            )
            XCTFail("expected the refusal to fail the send")
        } catch {
            guard case .secondOption = error else {
                return XCTFail("expected the signer's error, got \(error)")
            }
        }
        XCTAssertEqual(fixture.calls.recorded, ["seqno"])
    }
}

private extension TransferServicePreparedSendTests {
    func makeWallet(contract: WalletContractVersion = .v4R2) -> Wallet {
        Wallet(
            id: "prepared-send",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 3, count: 32)), contract)),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings()
        )
    }

    func makeJettonTransfer() throws -> Transfer {
        let address = try Address.parse("0:0000000000000000000000000000000000000000000000000000000000000002")
        return .jetton(
            JettonItem(
                jettonInfo: JettonInfo(
                    isTransferable: true,
                    hasCustomPayload: false,
                    address: address,
                    fractionDigits: 6,
                    name: "Tether USD",
                    symbol: "USD₮",
                    verification: .whitelist,
                    imageURL: nil
                ),
                walletAddress: address
            ),
            transferAmount: 50_000_000,
            amount: 1_000_000,
            recipient: TonRecipient(recipientAddress: .raw(address), isMemoRequired: false, isScam: false),
            comment: nil
        )
    }

    func makeTransfer() throws -> Transfer {
        try .multichainSwap(
            SignRawRequest(
                messages: [
                    SignRawRequestMessage(
                        address: AnyAddress(rawAddress: "0:0000000000000000000000000000000000000000000000000000000000000002"),
                        amount: 300_000_000,
                        stateInit: nil,
                        payload: nil
                    ),
                ],
                validUntil: nil,
                from: Address.parse("0:0000000000000000000000000000000000000000000000000000000000000001"),
                messagesVariants: nil
            )
        )
    }
}
