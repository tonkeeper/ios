import BigInt
import HTTPTypes
@testable import KeeperCore
import OpenAPIRuntime
import TKBatteryAPI
import TonSwift
import XCTest

final class BatteryPurchaseTests: XCTestCase {
    func testNetworkFailuresAreRecognizedThroughBatteryAndOpenAPIWrappers() {
        XCTAssertTrue(BatteryPurchaseError.isNetworkError(DeviceAuthError.connectionError))
        XCTAssertTrue(BatteryPurchaseError.isNetworkError(MultichainClientAPIError.connectionError(underlying: URLError(.networkConnectionLost))))
        XCTAssertTrue(BatteryPurchaseError.isNetworkError(MultichainTransactionFailure.failedToSign(kind: .networkError, reason: "offline")))
        XCTAssertTrue(BatteryPurchaseError.isNetworkError(MultichainTransactionFailure.failedToEstimateNonce(kind: .networkError, reason: "offline")))
        XCTAssertTrue(BatteryPurchaseError.isNetworkError(MultichainTransactionFailure.emulationFailure(.chainError(kind: .networkError, reason: "offline"))))
        for code: URLError.Code in [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost, .dataNotAllowed, .internationalRoamingOff, .secureConnectionFailed, .cannotLoadFromNetwork, .resourceUnavailable, .callIsActive] {
            let error = URLError(code)
            let wrapped = ClientError(operationID: "purchaseBatteryEstimate", operationInput: "request", causeDescription: "Transport failure", underlyingError: error)
            XCTAssertTrue(BatteryPurchaseError.isNetworkError(error), "\(code)")
            XCTAssertTrue(BatteryPurchaseError.isNetworkError(BatteryAPI.ApiError.unknown(underlying: wrapped)), "\(code)")
        }
    }

    func testPreparationAndServerErrorsAreNotReportedAsNetworkFailures() {
        let errors: [Error] = [
            BatteryPurchaseError.invalidQuote,
            BatteryPurchaseError.expired,
            BatteryAuthorizationError.unavailable,
            MultichainTransactionFailure.failedToSign(kind: .unknown, reason: "network"),
            DeviceAuthError.cancelled, DeviceAuthError.unauthorized(reason: "expired"),
            BatteryAPI.ApiError.badStatus(status: 503, message: "Network unavailable"),
            BatteryAPI.ApiError.rejected(status: 400, code: "insufficient_funds", message: "Not enough funds"),
            BatteryAPI.ApiError.unknown(underlying: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid quote"))),
            BatteryAPI.ApiError.unknown(underlying: nil),
            URLError(.badURL), URLError(.cancelled), CancellationError(),
        ]
        for error in errors {
            XCTAssertFalse(BatteryPurchaseError.isNetworkError(error), "\(error)")
        }
    }

    func testChargesRateUsesServerValueAndFallsBackToBatteryConfig() {
        XCTAssertEqual(BatteryRechargeMath.chargesRate("320.78", rate: "0.8", chargeCost: "0.0026"), Decimal(string: "320.78"))
        XCTAssertEqual(BatteryRechargeMath.chargesRate("320.78", rate: "0.8", chargeCost: "0"), Decimal(string: "320.78"))
        XCTAssertEqual(BatteryRechargeMath.chargesRate(nil, rate: "0.8", chargeCost: "0.002"), 400)
        XCTAssertEqual(BatteryRechargeMath.chargesRate("0", rate: "0.8", chargeCost: "0.002"), 400)
        XCTAssertNil(BatteryRechargeMath.chargesRate(nil, rate: "0.8", chargeCost: "0"))
        XCTAssertNil(BatteryRechargeMath.chargesRate("invalid", rate: "invalid", chargeCost: "0.002"))
        XCTAssertNil(BatteryRechargeMath.decimal("12oops"))
    }

    func testPackRoundsUpAndChargesRoundDown() throws {
        let rate = try XCTUnwrap(Decimal(string: "320.78"))
        let amount = try XCTUnwrap(BatteryRechargeMath.amount(charges: 750, rate: rate, decimals: 6))
        XCTAssertEqual(amount, 2_338_052)
        let value = try XCTUnwrap(BatteryRechargeMath.value(amount, decimals: 6))
        XCTAssertGreaterThanOrEqual(BatteryRechargeMath.charges(amount: value, rate: rate), 750)
        XCTAssertLessThan(try BatteryRechargeMath.charges(amount: XCTUnwrap(BatteryRechargeMath.value(amount - 1, decimals: 6)), rate: rate), 750)
        XCTAssertEqual(try BatteryRechargeMath.charges(amount: XCTUnwrap(Decimal(string: "1.999")), rate: 1), 1)
    }

    func testBaseUnitsDoNotOverflowUInt64() throws {
        XCTAssertEqual(BatteryRechargeMath.units(20, decimals: 18)?.description, "20000000000000000000")
        for decimals in [6, 9, 18] {
            let units = try XCTUnwrap(try BatteryRechargeMath.units(XCTUnwrap(Decimal(string: "10.123456")), decimals: decimals))
            XCTAssertEqual(BatteryRechargeMath.value(units, decimals: decimals), Decimal(string: "10.123456"))
        }
    }

    func testShownMinimumCanBeBoughtAtTheAssetsPrecision() {
        XCTAssertEqual(BatteryRechargeMath.minimumUnits("0.030314279", decimals: 9), 30_314_279)
        XCTAssertEqual(BatteryRechargeMath.minimumUnits("0.0303142791", decimals: 9), 30_314_280)
        XCTAssertEqual(BatteryRechargeMath.minimumUnits(nil, decimals: 9), 1)
        XCTAssertNil(BatteryRechargeMath.minimumUnits("bad", decimals: 9))
        XCTAssertNil(BatteryRechargeMath.units(1, decimals: -1))
        XCTAssertNil(BatteryRechargeMath.units(1, decimals: 39))
    }

    func testQuotedChargesAreConvertedToTheTonBalanceUnitForReconciliation() {
        XCTAssertEqual(BatteryRechargeMath.tonAmount(charges: 700, chargeCost: "0.003"), Decimal(string: "2.1"))
        XCTAssertEqual(BatteryRechargeMath.tonAmount(charges: 100, chargeCost: "0.001"), Decimal(string: "0.1"))
        for cost in ["0", "invalid", "-0.003"] {
            XCTAssertNil(BatteryRechargeMath.tonAmount(charges: 700, chargeCost: cost))
        }
        XCTAssertNil(BatteryRechargeMath.tonAmount(charges: 0, chargeCost: "0.003"))
    }

    func testEvmContractsMatchAcrossStandardAndCaseButBase58DoesNot() {
        XCTAssertTrue(BatteryAssetRechargeMethod.sameAsset("bsc/mainnet/erc20/0xAbCd", "bsc/mainnet/bep20/0xabcd"))
        XCTAssertFalse(BatteryAssetRechargeMethod.sameAsset("eth/mainnet/coin", "base/mainnet/coin"))
        XCTAssertFalse(BatteryAssetRechargeMethod.sameAsset("sol/mainnet/spl/AbCd", "sol/mainnet/spl/abcd"))
        XCTAssertFalse(BatteryAssetRechargeMethod.sameAsset("tron/mainnet/trc20/TAbC", "tron/mainnet/trc20/Tabc"))
        XCTAssertFalse(BatteryAssetRechargeMethod.sameAsset("eth/mainnet/coin", "eth/testnet/coin"))
    }

    func testMapperKeepsLegacyMethodsSeparateAndSkipsUnknownTypes() {
        var raw = method()
        XCTAssertNotNil(BatteryAssetRechargeMethod(raw))
        raw._type = .unknown
        XCTAssertNil(BatteryAssetRechargeMethod(raw))
        raw._type = .ton
        raw.chain = "ton/mainnet"
        raw.asset_id = "ton/mainnet/coin"
        XCTAssertNil(BatteryAssetRechargeMethod(raw))
        raw = method()
        raw.support_recharge = false
        XCTAssertNil(BatteryAssetRechargeMethod(raw))
        raw = method()
        raw.chain = "base/mainnet"
        XCTAssertNil(BatteryAssetRechargeMethod(raw))
    }

    func testQuoteMustEchoTheEntirePurchaseIntent() throws {
        let request = try BatteryPurchaseRequest(method: XCTUnwrap(BatteryAssetRechargeMethod(method())), sender: "0xAbCd", amount: 123, promo: "PROMO")
        XCTAssertNoThrow(try BatteryPurchaser.check(request, chain: "eth/mainnet", asset: "eth/mainnet/erc20/0xabcd", sender: "0xabcd", amount: "123"))
        XCTAssertThrowsError(try BatteryPurchaser.check(request, chain: "base/mainnet", asset: request.method.assetId, sender: request.sender, amount: "123"))
        XCTAssertThrowsError(try BatteryPurchaser.check(request, chain: "eth/mainnet", asset: request.method.assetId, sender: "0x1234", amount: "123"))
        XCTAssertThrowsError(try BatteryPurchaser.check(request, chain: "eth/mainnet", asset: request.method.assetId, sender: request.sender, amount: "124"))
        XCTAssertThrowsError(try BatteryPurchaser.quote(charges: 10, gross: 9, receiver: "receiver"))
        XCTAssertThrowsError(try BatteryPurchaser.quote(charges: 10, gross: 12, receiver: ""))
        XCTAssertEqual(try BatteryPurchaser.quote(charges: 10, gross: 12, receiver: "receiver").feeCharges, 2)
    }

    func testRequoteCannotReduceChargesOrChangeTheReceiverWithoutConsent() throws {
        let shown = try review(charges: 100)
        XCTAssertNoThrow(try BatteryPurchaser.checkFresh(review(charges: 100), against: shown))
        XCTAssertNoThrow(try BatteryPurchaser.checkFresh(review(charges: 101), against: shown))
        XCTAssertThrowsError(try BatteryPurchaser.checkFresh(review(charges: 99), against: shown))
        XCTAssertThrowsError(try BatteryPurchaser.checkFresh(review(charges: 101, receiver: "elsewhere"), against: shown))
        XCTAssertThrowsError(try BatteryPurchaser.checkFresh(review(charges: 0), against: shown))
    }

    func testQuoteDeadlineUsesTheServerLifetimeAndLeavesTimeForSending() throws {
        let review = try review(charges: 100)
        XCTAssertFalse(review.isExpired(at: Date(timeIntervalSince1970: 154)))
        XCTAssertTrue(review.isExpired(at: Date(timeIntervalSince1970: 155)))
    }

    func testSolanaFeePayerIsReadForLegacyAndVersionedTransactions() {
        let payer = [UInt8](repeating: 0, count: 32)
        let legacy = Data([0, 1, 0, 0, 1] + payer).base64EncodedString()
        let versioned = Data([0, 0x80, 1, 0, 0, 1] + payer).base64EncodedString()
        XCTAssertEqual(BatteryPurchaseOperationGuard.solanaFeePayer(legacy), String(repeating: "1", count: 32))
        XCTAssertEqual(BatteryPurchaseOperationGuard.solanaFeePayer(versioned), String(repeating: "1", count: 32))
        XCTAssertNil(BatteryPurchaseOperationGuard.solanaFeePayer(Data([0, 0x81, 1, 0, 0, 1] + payer).base64EncodedString()))
        XCTAssertNil(BatteryPurchaseOperationGuard.solanaFeePayer(Data([0, 1, 0, 0, 2] + payer).base64EncodedString()))
        XCTAssertNil(BatteryPurchaseOperationGuard.solanaFeePayer("invalid"))
    }

    func testFeeMustBePaidInChargesAndMatchTheNetPurchase() throws {
        let fee = Components.Schemas.GaslessV2Fee(_type: .value, asset_id: "battery/mainnet", data: .init(amount: "3"))
        XCTAssertNoThrow(try BatteryPurchaser.checkFee(fee, charges: 97, gross: 100, chainId: "sol/mainnet"))
        XCTAssertThrowsError(try BatteryPurchaser.checkFee(fee, charges: 98, gross: 100, chainId: "sol/mainnet"))
        XCTAssertThrowsError(try BatteryPurchaser.checkFee(fee, charges: 100, gross: 97, chainId: "sol/mainnet"))
        var other = fee
        other.asset_id = "sol/mainnet/coin"
        XCTAssertThrowsError(try BatteryPurchaser.checkFee(other, charges: 97, gross: 100, chainId: "sol/mainnet"))
    }

    func testAnAbandonedPurchaseNeverUnlocksOrSends() async throws {
        let purchaser = BatteryPurchaser(service: UnusedPurchaseService(), relayer: UnusedPurchaseRelayer()) { _, _, _, _, _ in
            XCTFail("An abandoned purchase must not reach the signer")
            throw CancellationError()
        }
        let wallet = Wallet(
            id: "wallet", identity: .init(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: .init(label: "Test", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true), batterySettings: BatterySettings()
        )
        let review = try review(charges: 100)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await purchaser.send(wallet: wallet, review: review, passcodeProvider: {
                XCTFail("An abandoned purchase must not ask for a PIN")
                return nil
            })
        }
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
    }

    private func review(charges: Int64, receiver: String = "receiver") throws -> BatteryPurchaseReview {
        let request = try BatteryPurchaseRequest(method: XCTUnwrap(BatteryAssetRechargeMethod(method())), sender: "0xAbCd", amount: 123, promo: nil)
        let response = Components.Schemas.PurchaseBatteryEmulateResponse(
            chain_id: request.method.chainId, sender_address: request.sender,
            created_at: Date(timeIntervalSince1970: 1000), expires_at: Date(timeIntervalSince1970: 1060),
            asset_id: request.method.assetId, amount: "123",
            fee: .init(_type: .value, asset_id: "battery/mainnet", data: .init(amount: "1")),
            gross_charges: charges + 1, charges: charges, funds_receiver: receiver,
            operation: .init(id: "purchase", _type: "transfer", payloads: [])
        )
        return BatteryPurchaseReview(quote: .init(charges: charges, grossCharges: charges + 1, fundsReceiver: receiver), request: request, response: response, receivedAt: Date(timeIntervalSince1970: 100))
    }

    func testSendDistinguishesNoConnectionFromAnAmbiguousNetworkFailure() async throws {
        let wallet = Wallet(
            id: "wallet", identity: .init(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: .init(label: "Test", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true), batterySettings: BatterySettings()
        )
        let original = try review(charges: 100)
        let shown = BatteryPurchaseReview(quote: original.quote, request: original.request, response: original.response, receivedAt: Date())
        let improved = try review(charges: 120)
        let fresh = BatteryPurchaseReview(quote: improved.quote, request: improved.request, response: improved.response, receivedAt: Date())
        for phase in FailingPurchaseRelayer.Phase.allCases {
            for code in [URLError.notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .timedOut] {
                let purchaser = BatteryPurchaser(service: UnusedPurchaseService(), relayer: FailingPurchaseRelayer(code: code, phase: phase)) { _, _, _, _, _ in
                    (Data(), fresh)
                }
                let isAmbiguous = phase == .responseReceived || [URLError.networkConnectionLost, .timedOut].contains(code)
                do {
                    _ = try await purchaser.send(wallet: wallet, review: shown, passcodeProvider: { nil })
                    XCTFail("The relayer must fail")
                } catch let BatteryPurchaseError.outcomeUnknown(sentReview) {
                    XCTAssertTrue(isAmbiguous)
                    XCTAssertEqual(sentReview.quote.charges, 120)
                } catch let error as URLError {
                    XCTAssertEqual(error.code, code)
                    XCTAssertFalse(isAmbiguous)
                }
            }
        }
    }

    func testSendKeepsLocalConfigurationAndAuthorizationErrorsRetryable() async throws {
        let wallet = Wallet(
            id: "wallet", identity: .init(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: .init(label: "Test", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true), batterySettings: BatterySettings()
        )
        let original = try review(charges: 100)
        let fresh = BatteryPurchaseReview(quote: original.quote, request: original.request, response: original.response, receivedAt: Date())
        let errors: [Error] = [BatteryAPI.ApiError.badUrl(underlying: nil), BatteryAuthorizationError.unavailable, BatteryAuthorizationError.deviceSessionFailure(.connectionError), BatteryAuthorizationError.deviceSessionFailure(.failed(message: "503")), BatteryAuthorizationError.deviceSessionFailure(.cancelled)]
        for expectedError in errors {
            let purchaser = BatteryPurchaser(service: UnusedPurchaseService(), relayer: FailingPurchaseRelayer(code: .unknown, phase: .raw, localError: expectedError)) { _, _, review, _, _ in
                (Data(), review)
            }
            do {
                _ = try await purchaser.send(wallet: wallet, review: fresh, passcodeProvider: { nil })
                XCTFail("The relayer must fail before dispatch")
            } catch let error as BatteryAPI.ApiError {
                guard case .badUrl = error else { return XCTFail("Expected the local URL error") }
            } catch let error as BatteryAuthorizationError {
                XCTAssertEqual(error, expectedError as? BatteryAuthorizationError)
            }
        }
    }

    func testARefusalThatMayFollowABroadcastLeavesTheOutcomeUnknown() async throws {
        let wallet = Wallet(
            id: "wallet", identity: .init(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: .init(label: "Test", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true), batterySettings: BatterySettings()
        )
        let original = try review(charges: 100)
        let fresh = BatteryPurchaseReview(quote: original.quote, request: original.request, response: original.response, receivedAt: Date())
        for mayHaveBroadcast in [true, false] {
            let refusal = EVMGaslessRelayerError.rejected(reason: "refused", mayHaveBroadcast: mayHaveBroadcast)
            let purchaser = BatteryPurchaser(service: UnusedPurchaseService(), relayer: FailingPurchaseRelayer(code: .unknown, phase: .raw, localError: refusal)) { _, _, review, _, _ in
                (Data(), review)
            }
            do {
                _ = try await purchaser.send(wallet: wallet, review: fresh, passcodeProvider: { nil })
                XCTFail("The relayer must refuse")
            } catch BatteryPurchaseError.outcomeUnknown {
                XCTAssertTrue(mayHaveBroadcast)
            } catch BatteryPurchaseError.rejected {
                XCTAssertFalse(mayHaveBroadcast)
            }
        }
    }

    func testPurchasePayloadCannotChargeANativeFeeOrUseAnotherNetwork() throws {
        let raw = Components.Schemas.RechargeMethods.methodsPayloadPayload(
            chain: "tron/mainnet", asset_id: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t", _type: .trc20,
            rate: "1", symbol: "USDT", decimals: 6, support_gasless: true, support_recharge: true
        )
        let request = try BatteryPurchaseRequest(method: XCTUnwrap(BatteryAssetRechargeMethod(raw)), sender: "sender", amount: 10, promo: nil)
        func operation(asset: String, amount: String = "1", chain: String = "tron/mainnet") throws -> Components.Schemas.GaslessV2Operation {
            let json = """
            {"id":"purchase","type":"transfer","payloads":[{"id":"p","type":"prebuild","chain_id":"\(chain)","version":1,"meta":{},"fee":{"type":"value","asset_id":"\(asset)","data":{"amount":"\(amount)"}}}]}
            """
            return try JSONDecoder().decode(Components.Schemas.GaslessV2Operation.self, from: Data(json.utf8))
        }
        XCTAssertThrowsError(try BatteryPurchaseOperationGuard.check(operation(asset: "tron/mainnet/coin"), request: request))
        XCTAssertThrowsError(try BatteryPurchaseOperationGuard.check(operation(asset: "battery/mainnet", chain: "tron/testnet"), request: request))
        XCTAssertNoThrow(try BatteryPurchaseOperationGuard.check(operation(asset: "battery/mainnet"), request: request))
        XCTAssertNoThrow(try BatteryPurchaseOperationGuard.check(operation(asset: "tron/mainnet/coin", amount: "0"), request: request))
    }

    private func method() -> Components.Schemas.RechargeMethods.methodsPayloadPayload {
        .init(chain: "eth/mainnet", asset_id: "eth/mainnet/erc20/0xAbCd", min_bootstrap_value: "5", _type: .erc20, rate: "0.8", charges_rate: "320.78", symbol: "USDT", decimals: 6, support_gasless: true, support_recharge: true)
    }
}

private struct FailingPurchaseRelayer: EVMGaslessRelaying {
    enum Phase: CaseIterable {
        case raw
        case request
        case responseReceived
    }

    let code: URLError.Code
    let phase: Phase
    var localError: Error? = nil

    func estimate(wallet: Wallet, call: EVMGaslessCall) async throws -> [EVMGaslessEstimation] {
        throw CancellationError()
    }

    func emulate(wallet: Wallet, calls: [EVMGaslessCall], assetId: String) async throws -> EVMGaslessEmulation {
        throw CancellationError()
    }

    func emulate(wallet: Wallet, batch: EVMBatchRelay, assetId: String) async throws -> EVMGaslessEmulation {
        throw CancellationError()
    }

    func send(wallet: Wallet, signedOperation: Data) async throws -> String? {
        if let localError { throw localError }
        if phase == .raw { throw URLError(code) }
        throw BatteryAPI.ApiError.unknown(underlying: ClientError(
            operationID: "gaslessSend", operationInput: "request",
            response: phase == .responseReceived ? HTTPResponse(status: .ok) : nil,
            causeDescription: "Transport failure", underlyingError: URLError(code)
        ))
    }
}

private struct UnusedPurchaseService: BatteryPurchaseService {
    func cachedAssetRechargeMethods(wallet: Wallet) -> [BatteryAssetRechargeMethod] {
        []
    }

    func loadAssetRechargeMethods(wallet: Wallet) async throws -> [BatteryAssetRechargeMethod] {
        throw CancellationError()
    }

    func estimatePurchase(wallet: Wallet, request: BatteryPurchaseRequest) async throws -> Components.Schemas.PurchaseBatteryEstimateResponse {
        throw CancellationError()
    }

    func emulatePurchase(wallet: Wallet, request: BatteryPurchaseRequest) async throws -> Components.Schemas.PurchaseBatteryEmulateResponse {
        throw CancellationError()
    }
}

private struct UnusedPurchaseRelayer: EVMGaslessRelaying {
    func estimate(wallet: Wallet, call: EVMGaslessCall) async throws -> [EVMGaslessEstimation] {
        throw CancellationError()
    }

    func emulate(wallet: Wallet, calls: [EVMGaslessCall], assetId: String) async throws -> EVMGaslessEmulation {
        throw CancellationError()
    }

    func emulate(wallet: Wallet, batch: EVMBatchRelay, assetId: String) async throws -> EVMGaslessEmulation {
        throw CancellationError()
    }

    func send(wallet: Wallet, signedOperation: Data) async throws -> String? {
        XCTFail("An abandoned purchase must not reach the relayer")
        throw CancellationError()
    }
}
