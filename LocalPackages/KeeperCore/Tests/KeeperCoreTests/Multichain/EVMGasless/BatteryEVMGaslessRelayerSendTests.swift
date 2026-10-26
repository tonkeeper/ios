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

    func test_aFailedSendIsARejection() async {
        service.sendStatus = .failed

        let error = await sendError()

        guard case .rejected = error as? EVMGaslessRelayerError else {
            return XCTFail("expected a failed status rejection")
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
    var estimateResponse: Components.Schemas.GaslessV2EstimateResponse?
    var emulateResponse: Components.Schemas.GaslessV2EmulateResponse?

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
        request _: Components.Schemas.GaslessV2EmulateRequest
    ) async throws -> Components.Schemas.GaslessV2EmulateResponse {
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
        return Components.Schemas.GaslessV2SendResponse(operation_id: request.operation.id, status: sendStatus)
    }
}
