@testable import App
import BigInt
import Combine
@testable import KeeperCore
import TKBatteryAPI
import TKLocalize
import TKTestSupport
import TKUIKit
import TonSwift
import XCTest

@MainActor
final class BatteryAssetRechargeViewModelTests: XCTestCase {
    func testAvailableBalanceRespectsTheCurrentSecureModeWithoutHidingThePurchaseAmount() throws {
        var isSecureMode = true
        let model = try makeModel(purchaser: RechargePurchaser(), isSecureMode: { isSecureMode })

        XCTAssertEqual(model.amountField.available, TKLocales.Battery.Refill.amountAvailable(String.secureModeValueShort))
        XCTAssertEqual(model.state.input.balance?.text, TKLocales.Battery.Refill.balance(String.secureModeValueShort))
        XCTAssertEqual(model.state.input.text, "2.5")
        XCTAssertNotNil(model.amountField.charges)

        isSecureMode = false
        XCTAssertEqual(model.amountField.available, TKLocales.Battery.Refill.amountAvailable("10 USDT"))
        XCTAssertEqual(model.state.input.text, "2.5")
        let visibleModel = try makeModel(purchaser: RechargePurchaser())
        XCTAssertEqual(visibleModel.state.input.balance?.text, TKLocales.Battery.Refill.balance("7.5 USDT"))
    }

    func testChosenAmountOpensConfirmationWithoutAnotherContinueOrSending() async throws {
        let purchaser = RechargePurchaser()
        let model = try makeModel(purchaser: purchaser)
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        XCTAssertTrue(model.state.isConfirmation)
        model.start()
        await waitUntil(changes) { model.state.isEnabled && !model.state.isBusy }

        XCTAssertTrue(model.state.isConfirmation)
        XCTAssertEqual(model.state.input.text, "2.5")
        XCTAssertEqual(model.selectedOptionID, "small")
        let requests = await purchaser.emulatedAmounts
        let sends = await purchaser.sends
        XCTAssertEqual(requests, [2_500_000])
        XCTAssertEqual(sends, 0)
    }

    func testEntryWithoutChosenAmountKeepsThePackFormUntilContinue() async throws {
        let purchaser = RechargePurchaser()
        let model = try makeModel(purchaser: purchaser, amount: nil, initialOptionID: "small")
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        model.start()
        await waitUntil(changes) { model.state.isEnabled }
        XCTAssertFalse(model.state.isConfirmation)
        let requests = await purchaser.emulatedAmounts
        XCTAssertTrue(requests.isEmpty)

        model.proceed()
        await waitUntil(changes) { model.state.isConfirmation && !model.state.isBusy }
        let sends = await purchaser.sends
        XCTAssertEqual(sends, 0)
    }

    func testOtherTokensEntryStartsWithTheMiddleAvailablePack() async throws {
        let purchaser = RechargePurchaser()
        let model = try makeModel(purchaser: purchaser, amount: nil)
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        model.start()
        await waitUntil(changes) { model.state.isEnabled }

        XCTAssertFalse(model.state.isConfirmation)
        XCTAssertEqual(model.selectedOptionID, "medium")
        XCTAssertEqual(model.state.input.text, "5")
        XCTAssertFalse(model.formState.showsAmount)
        let requests = await purchaser.emulatedAmounts
        let sends = await purchaser.sends
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(sends, 0)
    }

    func testExplicitCustomEntryStillOpensTheAmountField() throws {
        let model = try makeModel(purchaser: RechargePurchaser(), amount: nil, initialOptionID: "custom")

        model.start()

        XCTAssertFalse(model.state.isConfirmation)
        XCTAssertEqual(model.selectedOptionID, "custom")
        XCTAssertTrue(model.formState.showsAmount)
        XCTAssertFalse(model.state.isEnabled)
    }

    func testOfflineBalanceFailureKeepsConfirmationAndReportsErrorWithoutSending() async throws {
        let purchaser = RechargePurchaser()
        let model = try makeModel(purchaser: purchaser, loadBalance: { throw BatteryAPI.ApiError.unknown(underlying: URLError(.notConnectedToInternet)) })
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        model.start()
        await waitUntil(changes) { model.state.isEnabled && !model.state.isBusy }
        let resetToken = model.state.resetToken
        model.proceed()
        await waitUntil(changes) { model.state.resetToken > resetToken && !model.state.isBusy }

        XCTAssertEqual(model.state.message, TKLocales.MultichainSwap.Screen.Confirm.Error.networkError)
        XCTAssertTrue(model.state.isConfirmation)
        XCTAssertTrue(model.state.isEnabled)
        XCTAssertFalse(model.state.isTerminal)
        XCTAssertFalse(model.state.canRetry)
        let sends = await purchaser.sends
        XCTAssertEqual(sends, 0)
    }

    func testFailedInitialPreparationCanBeRetriedWithoutSending() async throws {
        let purchaser = RechargePurchaser(firstEmulationError: BatteryPurchaseError.invalidQuote)
        let model = try makeModel(purchaser: purchaser)
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        model.start()
        await waitUntil(changes) { model.state.canRetry && !model.state.isBusy }
        XCTAssertTrue(model.state.isConfirmation)
        XCTAssertFalse(model.state.isEnabled)
        XCTAssertEqual(model.state.message, TKLocales.Multichain.Transaction.Error.failedToPrepare)

        model.retry()
        await waitUntil(changes) { model.state.isEnabled && !model.state.isBusy }
        XCTAssertTrue(model.state.isConfirmation)
        XCTAssertFalse(model.state.canRetry)
        XCTAssertNil(model.state.message)
        let requests = await purchaser.emulatedAmounts
        let sends = await purchaser.sends
        XCTAssertEqual(requests, [2_500_000, 2_500_000])
        XCTAssertEqual(sends, 0)
    }

    func testNetworkEstimateFailureOnChargeCanBeRetried() async throws {
        let purchaser = RechargePurchaser(firstEstimateError: URLError(.timedOut))
        let model = try makeModel(purchaser: purchaser, amount: nil)
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        model.start()
        await waitUntil(changes) { model.canRetryEstimate }

        XCTAssertEqual(model.formState.message, TKLocales.MultichainSwap.Screen.Confirm.Error.networkError)
        XCTAssertFalse(model.formState.isEnabled)
        model.retry()
        await waitUntil(changes) { model.formState.isEnabled }

        XCTAssertNil(model.formState.message)
        let sends = await purchaser.sends
        XCTAssertEqual(sends, 0)
    }

    func testNetworkFailureDuringInitialEstimateOrEmulationKeepsRetryAvailable() async throws {
        let error = BatteryAPI.ApiError.unknown(underlying: URLError(.networkConnectionLost))
        for purchaser in [RechargePurchaser(firstEstimateError: error), RechargePurchaser(firstEmulationError: error)] {
            let model = try makeModel(purchaser: purchaser)
            let changes = TestSignal()
            let observation = model.$state.sink { _ in changes.send() }
            defer { observation.cancel() }

            model.start()
            await waitUntil(changes) { model.state.canRetry && !model.state.isBusy }

            XCTAssertEqual(model.state.message, TKLocales.MultichainSwap.Screen.Confirm.Error.networkError)
            XCTAssertFalse(model.state.isEnabled)
            model.retry()
            await waitUntil(changes) { model.state.isEnabled && !model.state.isBusy }

            XCTAssertNil(model.state.message)
            let sends = await purchaser.sends
            XCTAssertEqual(sends, 0)
        }
    }

    func testNonNetworkBalanceFailureKeepsPreparationMessageAndResetsConfirmation() async throws {
        let purchaser = RechargePurchaser()
        let model = try makeModel(purchaser: purchaser, loadBalance: { throw BatteryAPI.ApiError.badStatus(status: 503, message: "Unavailable") })
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        model.start()
        await waitUntil(changes) { model.state.isEnabled && !model.state.isBusy }
        let resetToken = model.state.resetToken
        model.proceed()
        await waitUntil(changes) { model.state.resetToken > resetToken && !model.state.isBusy }

        XCTAssertEqual(model.state.message, TKLocales.Multichain.Transaction.Error.failedToPrepare)
        XCTAssertTrue(model.state.isEnabled)
        XCTAssertFalse(model.state.isTerminal)
        let sends = await purchaser.sends
        XCTAssertEqual(sends, 0)
    }

    func testNetworkFailureBeforeSendingKeepsConfirmationAvailable() async throws {
        let purchaser = RechargePurchaser(sendError: BatteryAuthorizationError.deviceSessionFailure(.connectionError))
        let model = try makeModel(purchaser: purchaser)
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        model.start()
        await waitUntil(changes) { model.state.isEnabled && !model.state.isBusy }
        let resetToken = model.state.resetToken
        model.proceed()
        await waitUntil(changes) { model.state.resetToken > resetToken && !model.state.isBusy }

        XCTAssertEqual(model.state.message, TKLocales.MultichainSwap.Screen.Confirm.Error.networkError)
        XCTAssertTrue(model.state.isConfirmation)
        XCTAssertTrue(model.state.isEnabled)
        XCTAssertFalse(model.state.isTerminal)
        let sends = await purchaser.sends
        XCTAssertEqual(sends, 1)
    }

    func testExternallyCancelledDeviceSessionKeepsConfirmationRetryable() async throws {
        let purchaser = RechargePurchaser(sendError: BatteryAuthorizationError.deviceSessionFailure(.cancelled))
        let model = try makeModel(purchaser: purchaser)
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }
        model.start()
        await waitUntil(changes) { model.state.isEnabled && !model.state.isBusy }
        let resetToken = model.state.resetToken
        model.proceed()
        await waitUntil(changes) { model.state.resetToken > resetToken && !model.state.isBusy }
        XCTAssertEqual(model.state.message, TKLocales.Multichain.Transaction.Error.failedToPrepare)
        XCTAssertFalse(model.state.isTerminal)
        XCTAssertTrue(model.state.isEnabled)
    }

    func testExternallyCancelledInitialRequestsKeepRetryAvailable() async throws {
        let error = BatteryAuthorizationError.deviceSessionFailure(.cancelled)
        for purchaser in [RechargePurchaser(firstEstimateError: error), RechargePurchaser(firstEmulationError: error)] {
            let model = try makeModel(purchaser: purchaser)
            let changes = TestSignal()
            let observation = model.$state.sink { _ in changes.send() }
            defer { observation.cancel() }
            model.start()
            await waitUntil(changes) { model.state.canRetry && !model.state.isBusy }
            XCTAssertEqual(model.state.message, TKLocales.Multichain.Transaction.Error.failedToPrepare)
            model.retry()
            await waitUntil(changes) { model.state.isEnabled && !model.state.isBusy }
            XCTAssertNil(model.state.message)
        }
    }

    func testExternallyCancelledChargeEstimateKeepsRetryAvailable() async throws {
        let purchaser = RechargePurchaser(firstEstimateError: BatteryAuthorizationError.deviceSessionFailure(.cancelled))
        let model = try makeModel(purchaser: purchaser, amount: nil)
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }
        model.start()
        await waitUntil(changes) { model.canRetryEstimate }
        XCTAssertEqual(model.formState.message, TKLocales.Multichain.Transaction.Error.failedToPrepare)
        model.retry()
        await waitUntil(changes) { model.formState.isEnabled }
        XCTAssertNil(model.formState.message)
    }

    func testEditingConfirmationReturnsToTheChosenPack() async throws {
        let model = try makeModel(purchaser: RechargePurchaser())
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        model.start()
        await waitUntil(changes) { model.state.isEnabled && !model.state.isBusy }
        model.editAmount()
        await waitUntil(changes) { model.state.isEnabled && !model.state.isConfirmation }

        XCTAssertEqual(model.selectedOptionID, "small")
        XCTAssertEqual(model.state.input.text, "2.5")
    }

    func testChosenCustomAmountOpensConfirmation() async throws {
        let purchaser = RechargePurchaser()
        let model = try makeModel(purchaser: purchaser, amount: 3_000_000)
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        model.start()
        await waitUntil(changes) { model.state.isEnabled && !model.state.isBusy }

        XCTAssertTrue(model.state.isConfirmation)
        XCTAssertEqual(model.selectedOptionID, "custom")
        XCTAssertEqual(model.state.input.text, "3")
        let requests = await purchaser.emulatedAmounts
        XCTAssertEqual(requests, [3_000_000])
    }

    func testZeroChargeEstimateCannotPrepareOrSendAPurchase() async throws {
        let purchaser = RechargePurchaser(estimatedCharges: 0)
        let model = try makeModel(purchaser: purchaser)
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        model.start()
        await waitUntil(changes) { model.state.message != nil && !model.state.isBusy }

        XCTAssertTrue(model.state.isConfirmation)
        XCTAssertFalse(model.state.isEnabled)
        XCTAssertEqual(model.state.message, TKLocales.Battery.Purchase.noCharges)
        let requests = await purchaser.emulatedAmounts
        let sends = await purchaser.sends
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(sends, 0)
    }

    func testPromoResolvedDuringInitialPreparationRefreshesConfirmationWithoutSending() async throws {
        let gate = TestGate()
        let purchaser = RechargePurchaser(firstEmulationGate: gate)
        let model = try makeModel(purchaser: purchaser)
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        model.start()
        await waitUntil(purchaser.changes) { await purchaser.emulatedAmounts.count == 1 }
        model.updatePromo(.success(promocode: "promo"))
        await gate.open()
        await waitUntil(changes) { model.state.isEnabled && !model.state.isBusy }

        XCTAssertTrue(model.state.isConfirmation)
        let promos = await purchaser.emulatedPromos
        let sends = await purchaser.sends
        XCTAssertEqual(promos, [nil, "promo"])
        XCTAssertEqual(sends, 0)
    }

    func testClosingDuringPreparationDoesNotRestartForAPendingPromo() async throws {
        let gate = TestGate()
        let purchaser = RechargePurchaser(firstEmulationGate: gate)
        let model = try makeModel(purchaser: purchaser)
        let changes = TestSignal()
        let observation = model.$state.sink { _ in changes.send() }
        defer { observation.cancel() }

        model.start()
        await waitUntil(purchaser.changes) { await purchaser.emulatedAmounts.count == 1 }
        model.updatePromo(.success(promocode: "promo"))
        model.stop()
        await gate.open()
        await waitUntil(changes) { !model.state.isBusy }

        XCTAssertFalse(model.state.isEnabled)
        let requests = await purchaser.emulatedAmounts
        let sends = await purchaser.sends
        XCTAssertEqual(requests, [2_500_000])
        XCTAssertEqual(sends, 0)
    }

    private func makeModel(purchaser: RechargePurchaser, amount: BigUInt? = 2_500_000, initialOptionID: String? = nil, loadBalance: @escaping () async throws -> NSDecimalNumber = { .zero }, isSecureMode: @escaping () -> Bool = { false }) throws -> BatteryAssetRechargeViewModel {
        let method = try JSONDecoder().decode(BatteryAssetRechargeMethod.self, from: Data("""
        {"chainId":"eth/mainnet","assetId":"eth/mainnet/erc20/0xAbCd","symbol":"USDT","decimals":6,"minimum":"1","rate":"1","chargesRate":"300"}
        """.utf8))
        let source = BatteryRechargeAsset(
            method: method,
            asset: .init(asset: .init(assetId: method.assetId, name: "Tether", symbol: method.symbol, decimals: method.decimals, image: ""), price: .init(prices: ["USD": 1], diff24h: [:], diff7d: [:]), balance: 10_000_000),
            sender: "0xSender", chargeCost: "0.003", packages: [.init(id: "large", charges: 2500), .init(id: "medium", charges: 1500), .init(id: "small", charges: 750)]
        )
        let wallet = Wallet(
            id: "wallet", identity: .init(network: .mainnet, kind: .Regular(PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: .init(label: "Test", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true), batterySettings: BatterySettings()
        )
        return BatteryAssetRechargeViewModel(
            source: source, amount: amount, promo: nil, wallet: wallet, purchaser: purchaser,
            loadBatteryBalance: loadBalance, currency: { .USD }, isSecureMode: isSecureMode, refresh: {}, initialOptionID: initialOptionID,
            passcodeProvider: { nil }, onSelect: { _ in }, onCredit: { _ in }, onSuccess: { _ in }, onClose: {}, debounce: {}
        )
    }
}

private actor RechargePurchaser: BatteryPurchasing {
    nonisolated let changes = TestSignal()
    private let firstEmulationError: Error?
    private let firstEstimateError: Error?
    private let sendError: Error
    private let firstEmulationGate: TestGate?
    private let estimatedCharges: Int64
    private(set) var emulatedAmounts: [BigUInt] = []
    private(set) var emulatedPromos: [String?] = []
    private(set) var sends = 0
    private var estimates = 0

    init(firstEmulationError: Error? = nil, firstEstimateError: Error? = nil, sendError: Error = MultichainTransactionFailure.canceled, firstEmulationGate: TestGate? = nil, estimatedCharges: Int64 = 700) {
        self.firstEmulationError = firstEmulationError
        self.firstEstimateError = firstEstimateError
        self.sendError = sendError
        self.firstEmulationGate = firstEmulationGate
        self.estimatedCharges = estimatedCharges
    }

    func estimate(wallet: Wallet, request: BatteryPurchaseRequest) async throws -> BatteryPurchaseQuote {
        estimates += 1
        if estimates == 1, let firstEstimateError { throw firstEstimateError }
        return .init(charges: estimatedCharges, grossCharges: 750, fundsReceiver: "receiver")
    }

    func emulate(wallet: Wallet, request: BatteryPurchaseRequest) async throws -> BatteryPurchaseReview {
        emulatedAmounts.append(request.amount)
        emulatedPromos.append(request.promo)
        changes.send()
        if emulatedAmounts.count == 1 { try await firstEmulationGate?.wait() }
        if let firstEmulationError, emulatedAmounts.count == 1 { throw firstEmulationError }
        let response = Components.Schemas.PurchaseBatteryEmulateResponse(
            chain_id: request.method.chainId, sender_address: request.sender,
            created_at: Date(), expires_at: Date().addingTimeInterval(60),
            asset_id: request.method.assetId, amount: request.amount.description,
            fee: .init(_type: .value, asset_id: "battery/mainnet", data: .init(amount: "50")),
            gross_charges: 750, charges: 700, funds_receiver: "receiver",
            operation: .init(id: "purchase", _type: "transfer", payloads: [])
        )
        return BatteryPurchaseReview(quote: .init(charges: 700, grossCharges: 750, fundsReceiver: "receiver"), request: request, response: response, receivedAt: Date())
    }

    func send(wallet: Wallet, review: BatteryPurchaseReview, passcodeProvider: @escaping () async -> String?) async throws -> String? {
        sends += 1
        throw sendError
    }
}
