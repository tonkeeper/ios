@testable import KeeperCore
import TKBatteryAPI
import TonSwift
import XCTest

/// What a failed `/gasless/send` tells the engines: a refusal the relayer answered with, or an
/// operation that may already be on its way.
final class BatteryEVMGaslessRelayerSendTests: XCTestCase {
    private let service = FakeGaslessService()
    private lazy var relayer = BatteryEVMGaslessRelayer(service: service)

    func test_unknownFeeIsSkippedWithoutLosingKnownEstimations() async throws {
        let original = GaslessFixtures.estimate
        let pattern = "\"type\": \"value\""
        let json = original.replacingOccurrences(of: pattern, with: "\"type\": \"future-fee\"", range: original.range(of: pattern))
        service.estimateResponse = try decode(Components.Schemas.GaslessV2EstimateResponse.self, json: json)

        let estimations = try await relayer.estimate(wallet: wallet, call: call)

        XCTAssertEqual(estimations.map(\.asset.id), [GaslessFixtures.usdcId, GaslessFixtures.usdtId])
        XCTAssertEqual(estimations.map { $0.fee.description }, ["115304", "115304"])
    }

    func test_unknownEmulationFeeIsRejected() async throws {
        let json = GaslessFixtures.emulateBattery.replacingOccurrences(of: "\"type\": \"value\"", with: "\"type\": \"future-fee\"")
        service.emulateResponse = try decode(Components.Schemas.GaslessV2EmulateResponse.self, json: json)

        do {
            _ = try await relayer.emulate(wallet: wallet, call: call, assetId: "battery/mainnet")
            XCTFail("expected an unsupported fee rejection")
        } catch {
            XCTAssertEqual(error as? EVMGaslessRelayerError, .rejected(reason: "unsupported emulation fee type: unknown"))
        }
    }

    func test_aBatchIsEmulatedAsOneRequestOfItsCallsInOrder() async throws {
        service.emulateResponse = try decode(Components.Schemas.GaslessV2EmulateResponse.self, json: GaslessFixtures.emulateBattery)
        let router = EVMGaslessCall(kind: .transfer, chainId: "eth/mainnet", sender: GaslessFixtures.sender, to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", value: 0, data: "0x38ed1739")

        _ = try await relayer.emulate(wallet: wallet, calls: [call, router], assetId: "battery/mainnet")

        XCTAssertEqual(service.emulateRequests.count, 1)
        let request = try XCTUnwrap(service.emulateRequests.first)
        XCTAssertEqual(request.payloads.map(\.id), ["p_01", "p_02"])
        XCTAssertEqual(request.payloads.map { $0.meta.additionalProperties.value["to"] as? String }, [call.to, router.to])
        XCTAssertEqual(request.sender_address, GaslessFixtures.sender)
    }

    func test_aSolanaTransactionIsRelayedOnlyWhenTheRelayerPaysItsFee() async throws {
        let sender = String(repeating: "1", count: 32)
        let solanaCall = EVMGaslessCall.solanaSwap(sender: sender, transaction: "AA==")

        service.emulateResponse = try decode(Components.Schemas.GaslessV2EmulateResponse.self, json: Self.solanaEmulation(feePayer: Data(repeating: 1, count: 32)))
        let relayed = try await relayer.emulate(wallet: wallet, call: solanaCall, assetId: "battery/mainnet")
        XCTAssertEqual(relayed.operation.payloadIds, ["p_01"])

        service.emulateResponse = try decode(Components.Schemas.GaslessV2EmulateResponse.self, json: Self.solanaEmulation(feePayer: Data(count: 32)))
        do {
            _ = try await relayer.emulate(wallet: wallet, call: solanaCall, assetId: "battery/mainnet")
            XCTFail("expected a rejection of a transaction the sender pays for")
        } catch {
            XCTAssertEqual(error as? EVMGaslessRelayerError, .rejected(reason: "payload p_01 is not a transaction the relayer pays the fee of"))
        }

        service.emulateResponse = try decode(Components.Schemas.GaslessV2EmulateResponse.self, json: Self.solanaEmulation(transaction: "invalid"))
        do {
            _ = try await relayer.emulate(wallet: wallet, call: solanaCall, assetId: "battery/mainnet")
            XCTFail("expected a rejection of a transaction with no fee payer to read")
        } catch {
            XCTAssertNotNil(error as? EVMGaslessRelayerError)
        }
    }

    func test_callsOfAnotherSenderAreNoBatch() async {
        let other = EVMGaslessCall(kind: .transfer, chainId: "eth/mainnet", sender: GaslessFixtures.usdtContract, to: GaslessFixtures.usdtContract, value: 0, data: "0x")

        do {
            _ = try await relayer.emulate(wallet: wallet, calls: [call, other], assetId: "battery/mainnet")
            XCTFail("expected a rejection")
        } catch {
            XCTAssertNotNil(error as? EVMGaslessRelayerError)
        }
        XCTAssertTrue(service.emulateRequests.isEmpty)
    }

    func test_aSentOperationNamesItsTransaction() async throws {
        service.sendHash = "0xabc"

        let hash = try await relayer.send(wallet: wallet, signedOperation: Data(GaslessFixtures.signedEnvelope.utf8))

        XCTAssertEqual(hash, "0xabc")
    }

    func test_anEmptyHashNamesNoTransaction() async throws {
        service.sendHash = ""

        let hash = try await relayer.send(wallet: wallet, signedOperation: Data(GaslessFixtures.signedEnvelope.utf8))

        XCTAssertNil(hash)
    }

    func test_aFailedSendIsARejection() async {
        service.sendStatus = .failed

        let error = await sendError()

        guard case .rejected(_, true) = error as? EVMGaslessRelayerError else {
            return XCTFail("expected a failed status with an uncertain broadcast")
        }
    }

    /// The relayer answers 200 for an operation it has taken: a status the app cannot read does not
    /// say the operation stayed off the chain.
    func test_anUnknownSendStatusIsNoRefusal() async {
        service.sendStatus = .unknown

        let error = await sendError()

        XCTAssertNotNil(error)
        XCTAssertNil(error as? EVMGaslessRelayerError)
    }

    func test_aRefusalIsARejection() async {
        service.sendError = BatteryAPI.ApiError.rejected(status: 400, code: "invalid_signature", message: "bad signature")

        let error = await sendError()

        XCTAssertEqual(error as? EVMGaslessRelayerError, .rejected(reason: "invalid_signature: bad signature"))
    }

    func test_aFailedBroadcastMayHaveBeenSent() async {
        service.sendError = BatteryAPI.ApiError.rejected(status: 400, code: "broadcast_failed", message: "broadcast failed")

        let error = await sendError()

        XCTAssertEqual(error as? EVMGaslessRelayerError, .rejected(reason: "broadcast_failed: broadcast failed", mayHaveBroadcast: true))
    }

    func test_aForgottenOperationIsAnExpiredQuote() async {
        service.sendError = BatteryAPI.ApiError.rejected(status: 404, code: "operation_not_found", message: "no such operation")

        let error = await sendError()

        XCTAssertEqual(error as? EVMGaslessRelayerError, .quoteExpired)
    }

    /// `already_sent` answers a resend of an operation whose first send may have landed.
    func test_anAlreadySentOperationIsNoRefusal() async {
        service.sendError = BatteryAPI.ApiError.rejected(status: 409, code: "already_sent", message: "already sent")

        let error = await sendError()

        XCTAssertNotNil(error)
        XCTAssertNil(error as? EVMGaslessRelayerError)
    }

    func test_aRequestWithoutAnAnswerIsNoRefusal() async {
        service.sendError = BatteryAPI.ApiError.unknown(underlying: URLError(.timedOut))

        let error = await sendError()

        XCTAssertNotNil(error)
        XCTAssertNil(error as? EVMGaslessRelayerError)
    }

    private func sendError() async -> Error? {
        do {
            try await relayer.send(wallet: wallet, signedOperation: Data(GaslessFixtures.signedEnvelope.utf8))
            return nil
        } catch {
            return error
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try MultichainDateTranscoder().decode(decoder.singleValueContainer().decode(String.self))
        }
        return try decoder.decode(type, from: Data(json.utf8))
    }

    /// A legacy transaction whose first account key, the fee payer, is `feePayer`.
    private static func solanaEmulation(feePayer: Data) -> String {
        solanaEmulation(transaction: (Data([1]) + Data(count: 64) + Data([1, 0, 1, 2]) + feePayer + Data(count: 32)).base64EncodedString())
    }

    private static func solanaEmulation(transaction: String) -> String {
        """
        {
          "chain_id": "sol/mainnet",
          "sender_address": "\(String(repeating: "1", count: 32))",
          "created_at": "2026-09-30T09:53:11Z",
          "expires_at": "2026-09-30T10:03:11Z",
          "asset_id": "battery/mainnet",
          "fee": { "type": "value", "asset_id": "battery/mainnet", "data": { "amount": "1" } },
          "operation": {
            "id": "op",
            "type": "swap",
            "payloads": [{ "id": "p_01", "type": "prebuild", "chain_id": "sol/mainnet", "version": 1, "meta": { "data": "\(transaction)" } }]
          }
        }
        """
    }

    private var call: EVMGaslessCall {
        EVMGaslessCall(kind: .transfer, chainId: "eth/mainnet", sender: GaslessFixtures.sender, to: GaslessFixtures.usdtContract, value: 0, data: GaslessFixtures.usdtTransfer)
    }

    private var wallet: Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: .init(
                label: "Test wallet",
                tintColor: .defaultColor,
                icon: .icon(.wallet)
            ),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: BatterySettings()
        )
    }
}

private final class FakeGaslessService: BatteryGaslessService {
    var sendError: Error?
    var sendStatus: Components.Schemas.GaslessV2SendResponse.statusPayload = .ok
    var sendHash: String?
    var estimateResponse: Components.Schemas.GaslessV2EstimateResponse?
    var emulateResponse: Components.Schemas.GaslessV2EmulateResponse?
    private(set) var emulateRequests = [Components.Schemas.GaslessV2EmulateRequest]()

    func gaslessConfig() async throws -> Components.Schemas.GaslessV2Config {
        throw URLError(.unsupportedURL)
    }

    func estimateGasless(
        wallet _: Wallet,
        request _: Components.Schemas.GaslessV2EstimateRequest
    ) async throws -> Components.Schemas.GaslessV2EstimateResponse {
        if let estimateResponse { return estimateResponse }
        throw URLError(.unsupportedURL)
    }

    func emulateGasless(
        wallet _: Wallet,
        request: Components.Schemas.GaslessV2EmulateRequest
    ) async throws -> Components.Schemas.GaslessV2EmulateResponse {
        emulateRequests.append(request)
        if let emulateResponse { return emulateResponse }
        throw URLError(.unsupportedURL)
    }

    func sendGasless(
        wallet _: Wallet,
        request: Components.Schemas.GaslessV2SendRequest
    ) async throws -> Components.Schemas.GaslessV2SendResponse {
        if let sendError {
            throw sendError
        }
        return Components.Schemas.GaslessV2SendResponse(operation_id: request.operation.id, status: sendStatus, tx_hash: sendHash)
    }
}
