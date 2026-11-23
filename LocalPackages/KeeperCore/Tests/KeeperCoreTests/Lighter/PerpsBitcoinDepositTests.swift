import BigInt
import Foundation
@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsBitcoinDepositTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsBitcoinDepositTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    func testRelaysPsbtOfTheWalletsOwnCoinIsReadIntoWhatItSendsAndWhatItPaysTheMiners() async throws {
        let delivery = StubDepositDelivery()
        let quote = try await read(budget: BtcFixture.deposited, psbt: BtcFixture.livePsbt, delivery: delivery)

        XCTAssertEqual(quote.relayPaymentUnits, 99707)
        XCTAssertEqual(quote.bitcoinPayment, PerpsBitcoinDeposit(sentUnits: 99707, feeUnits: 1165, virtualSize: 218))
        XCTAssertEqual(delivery.bytePriceRequests, ["99707 from \(BtcFixture.sender)"])
    }

    func testTheReviewShowsWhatThePsbtSendsWhatItReallyPaysTheMinersAndRelay() async throws {
        var payload = Components.Schemas.QuotePayload.btc("p_btc", psbt: BitcoinPsbtFixture.deposit(amount: 5000))
        payload.setFee(.value(.init(_type: .value, asset_id: "btc/mainnet/coin", data: .init(amount: "1140"))))
        let delivery = StubDepositDelivery()
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(Self.quote(budget: "5000", payloads: [payload]))), delivery: delivery)

        let review = try await service.review(
            sourceAsset: BitcoinPsbtFixture.asset,
            amount: "0.00005",
            senderAddress: BtcFixture.sender,
            beneficiary: PaymentFixture.sender,
            registeringKey: false
        )

        XCTAssertEqual(review.sentAmount, "0.00005")
        XCTAssertEqual(review.provider, "Relay")
        XCTAssertEqual(review.networkFeeUnits, 1398)
        XCTAssertEqual(review.networkFee, "0.00001398")
        XCTAssertEqual(review.networkFeeSymbol, "BTC")
        XCTAssertTrue(delivery.pricedOperations.isEmpty)
    }

    func testOnlyOneOutputToRelaysDepositoryOneChangeBackAndTheOrderIdArePaid() async {
        let fixture = BitcoinPsbtFixture.self
        let deposit = fixture.Output(script: fixture.depositoryScript, value: 5000)
        let change = fixture.Output(script: fixture.senderScript, value: fixture.change)
        let order = fixture.Output(script: fixture.orderScript, value: 0)
        let input = [fixture.Input(script: fixture.senderScript, value: 5000 + fixture.fee + fixture.change)]
        let refused: (String) -> PerpsDepositQuoteError = { .unexpectedBitcoinPayment($0) }
        let cases: [(String, [BitcoinPsbtFixture.Output], PerpsDepositQuoteError)] = [
            ("to someone else", [.init(script: fixture.foreignScript, value: 5000), change, order], refused("depository output")),
            ("to the depository twice", [.init(script: fixture.depositoryScript, value: 2500), .init(script: fixture.depositoryScript, value: 2500), change, order], refused("depository output")),
            ("an extra output within the amount", [.init(script: fixture.depositoryScript, value: 4950), .init(script: fixture.foreignScript, value: 50), change, order], refused("outputs")),
            ("an extra output past the amount", [deposit, .init(script: fixture.foreignScript, value: 1000), change, order], .overspend(spent: "6000", budget: "5000")),
            ("the change to another wallet", [deposit, .init(script: fixture.foreignScript, value: fixture.change), order], .overspend(spent: "10499", budget: "5000")),
            ("the change in two outputs", [deposit, .init(script: fixture.senderScript, value: 2000), .init(script: fixture.senderScript, value: 3499), order], refused("change output")),
            ("no order id", [deposit, change], refused("outputs")),
            ("an order id carrying sats", [deposit, .init(script: fixture.senderScript, value: fixture.change - 546), .init(script: fixture.orderScript, value: 546)], .malformedPayload(payloadId: "p_btc")),
            ("an OP_RETURN of something else", [deposit, change, .init(script: fixture.opReturn("hello"), value: 0)], refused("op_return")),
            ("a short order id", [deposit, change, .init(script: fixture.opReturn(String(fixture.orderId.dropLast(2))), value: 0)], refused("op_return")),
            ("two order ids", [deposit, change, order, order], refused("outputs")),
        ]
        for (name, outputs, expected) in cases {
            await assertRefused(fixture.build(inputs: input, outputs: outputs), expected, name)
        }
    }

    func testTheDepositoryGetsNinetyNineToAHundredPercentOfTheAmount() async throws {
        for amount: UInt64 in [5000, 4950] {
            let quote = try await read(psbt: BitcoinPsbtFixture.deposit(amount: amount))
            XCTAssertEqual(quote.relayPaymentUnits, BigUInt(amount))
        }
        await assertRefused(BitcoinPsbtFixture.deposit(amount: 4949), .unexpectedBitcoinPayment("value"), "short by more than one percent")
        await assertRefused(BitcoinPsbtFixture.deposit(amount: 5001), .overspend(spent: "5001", budget: "5000"), "more than the amount")
    }

    func testOnlyTheWalletsOwnCoinsAreSpent() async {
        let fixture = BitcoinPsbtFixture.self
        let outputs = fixture.outputs(amount: 5000)
        let ownCoin = fixture.Input(script: fixture.senderScript, value: 5000 + fixture.fee + fixture.change)
        let cases: [(String, [BitcoinPsbtFixture.Input])] = [
            ("someone else's coin", [.init(script: fixture.foreignScript, value: 5000 + fixture.fee + fixture.change)]),
            ("someone else's coin beside the own one", [ownCoin, .init(script: fixture.foreignScript, value: 1000)]),
            ("a coin the PSBT does not carry", [ownCoin, .init(script: nil, value: 0)]),
        ]
        for (name, inputs) in cases {
            await assertRefused(fixture.build(inputs: inputs, outputs: outputs), .unexpectedBitcoinPayment("input"), name)
        }
    }

    func testAnInputIsSignedOnlyUnderSighashAllOrTaprootsDefault() async throws {
        let fixture = BitcoinPsbtFixture.self
        let coin = 5000 + fixture.fee + fixture.change
        for sighash: UInt32? in [nil, 1] {
            _ = try await read(psbt: fixture.build(inputs: [.init(script: fixture.senderScript, value: coin, sighash: sighash)], outputs: fixture.outputs(amount: 5000)))
        }
        for sighash: UInt32 in [0, 2, 3, 0x81, 0x82, 0x83] {
            await assertRefused(
                fixture.build(inputs: [.init(script: fixture.senderScript, value: coin, sighash: sighash)], outputs: fixture.outputs(amount: 5000)),
                .unexpectedBitcoinPayment("sighash"),
                "sighash \(sighash)"
            )
        }

        let taproot = fixture.build(
            inputs: [.init(script: fixture.taprootSenderScript, value: coin, sighash: 0)],
            outputs: fixture.outputs(amount: 5000, changeScript: fixture.taprootSenderScript)
        )
        let quote = try await read(psbt: taproot, sender: fixture.taprootSender)
        XCTAssertEqual(quote.bitcoinPayment?.feeUnits, BigUInt(fixture.fee))
    }

    func testTheMinersGetNoMoreThanThreeTimesTheWalletsOwnPriceOfTheTransaction() async throws {
        let fixture = BitcoinPsbtFixture.self
        let atTheCap = try await read(psbt: fixture.deposit(amount: 5000, fee: 3 * 5 * 218))
        XCTAssertEqual(atTheCap.bitcoinPayment?.virtualSize, 218)

        await assertRefused(fixture.deposit(amount: 5000, fee: 3 * 5 * 218 + 1), .unexpectedBitcoinPayment("fee rate"), "past three times")
        await assertRefused(
            fixture.build(inputs: [.init(script: fixture.senderScript, value: 105_000)], outputs: [
                .init(script: fixture.depositoryScript, value: 5000), .init(script: fixture.orderScript, value: 0),
            ]),
            .unexpectedBitcoinPayment("fee rate"),
            "the change left to the miners"
        )
        await assertRefused(
            fixture.build(inputs: [.init(script: fixture.senderScript, value: 6000)], outputs: fixture.outputs(amount: 5000)),
            .unexpectedBitcoinPayment("fee"),
            "paying out more than it takes in"
        )
        for price: BigUInt? in [nil, 0] {
            let delivery = StubDepositDelivery()
            delivery.walletBytePrice = price
            await assertRefused(fixture.deposit(amount: 5000), .unexpectedBitcoinPayment("wallet fee rate"), "no price of its own", delivery: delivery)
        }
    }

    func testABitcoinDepositIsOnlyRelaysOnePrebuiltPsbt() async {
        let psbt = BitcoinPsbtFixture.deposit(amount: 5000)
        await assertRefused(psbt, .unexpectedBitcoinPayment("provider"), provider: "funxyz")

        let main = Components.Schemas.QuotePayload.payload("p_main", chain: "btc/mainnet", meta: ["to": BitcoinPsbtFixture.depository, "value": "5000"])
        await assertRefused(payloads: [main], .malformedPayload(payloadId: "p_main"), "BTC main")
        await assertRefused(
            payloads: [.btc("p_1", psbt: psbt), .btc("p_2", psbt: BitcoinPsbtFixture.build(
                inputs: [.init(script: BitcoinPsbtFixture.senderScript, value: 1000)],
                outputs: [.init(script: BitcoinPsbtFixture.orderScript, value: 0)]
            ))],
            .unexpectedBitcoinPayment("payloads"),
            "two PSBTs"
        )
    }

    func testWithoutRelaysBitcoinDepositoryOnlyTheBitcoinDepositIsRefused() async throws {
        var withoutBitcoin = KeyRegistrationFixture.security
        withoutBitcoin.relayBitcoinDepositories = []
        for security in [nil, withoutBitcoin] {
            await assertRefused(BitcoinPsbtFixture.deposit(amount: 5000), .unexpectedBitcoinPayment("relay depository"), security: security)
        }

        let bsc = PaymentFixture.crosschainQuote(asset: KeyRegistrationFixture.bscAsset.assetId, amount: RelayFixture.bscBudget, payloads: [RelayFixture.bscBatch()])
        let fromBsc = try await makeService(api: FundingStubAPI(quoteDeposit: .success(bsc)), security: withoutBitcoin).quote(
            sourceAsset: KeyRegistrationFixture.bscAsset.assetId,
            sourceAmountUnits: RelayFixture.bscBudget,
            senderAddress: PaymentFixture.sender,
            beneficiary: PaymentFixture.sender
        )
        XCTAssertNotNil(fromBsc.relayPaymentUnits)
    }

    func testAFirstDepositPaysThePsbtQuotedAfterTheUnlockWhileItsFeeStaysWithinOnePercentOfTheOneShown() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: Self.registeringAPI(signed: BitcoinPsbtFixture.deposit(amount: 5000, fee: 1411, change: 5486)), delivery: delivery)
        let review = try await registeringReview(service)
        XCTAssertEqual(review.networkFeeUnits, 1398)

        _ = try await service.pay(review: review, passcode: "0000", consent: .refuse)

        let events = await delivery.session.events
        XCTAssertEqual(events, ["sign:p_auth,p_execute", "send:p_btc"])
    }

    func testAFirstDepositWhosePsbtQuotedAfterTheUnlockPaysTheMinersMoreIsShownAgainUnsent() async throws {
        let delivery = StubDepositDelivery()
        let service = makeService(api: Self.registeringAPI(signed: BitcoinPsbtFixture.deposit(amount: 5000, fee: 1412, change: 5485)), delivery: delivery)

        do {
            _ = try await service.pay(review: registeringReview(service), passcode: "0000", consent: .refuse)
            XCTFail("expected the dearer PSBT to be shown again")
        } catch {
            XCTAssertEqual(error as? PerpsDepositServiceError, .bitcoinFeeRaised(quoted: "1412", shown: "1398"))
            XCTAssertEqual(PerpsDepositService.message(for: error), .quoteChanged)
        }
        let events = await delivery.session.events
        XCTAssertEqual(events, ["sign:p_auth,p_execute"])
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
    }

    func testAFirstDepositWhosePsbtQuotedAfterTheUnlockPaysSomeoneElseIsNeverSigned() async throws {
        let fixture = BitcoinPsbtFixture.self
        let foreign = fixture.build(
            inputs: [.init(script: fixture.senderScript, value: 5000 + fixture.fee + fixture.change)],
            outputs: [.init(script: fixture.foreignScript, value: 5000), .init(script: fixture.senderScript, value: fixture.change), .init(script: fixture.orderScript, value: 0)]
        )
        let delivery = StubDepositDelivery()
        let service = makeService(api: Self.registeringAPI(signed: foreign), delivery: delivery)

        do {
            _ = try await service.pay(review: registeringReview(service), passcode: "0000", consent: .refuse)
            XCTFail("expected the PSBT to someone else to be refused")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .unexpectedBitcoinPayment("depository output"))
        }
        let events = await delivery.session.events
        XCTAssertEqual(events, ["sign:p_auth,p_execute"])
    }

    private func registeringReview(_ service: PerpsDepositService) async throws -> PerpsDepositReview {
        try await service.review(
            sourceAsset: BitcoinPsbtFixture.asset,
            amount: "0.00005",
            senderAddress: BtcFixture.sender,
            beneficiary: PaymentFixture.sender
        )
    }

    private static func registeringAPI(signed: String) -> FundingStubAPI {
        let plain = quote(budget: "5000", payloads: [.btc("p_btc", psbt: BitcoinPsbtFixture.deposit(amount: 5000))])
        var paid = quote(budget: "5000", payloads: [.btc("p_btc", psbt: signed)])
        paid.account_uninitialized = nil
        return FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDepositHandler: { request in
                guard request.change_pub_key != nil else { return plain }
                guard request.operation != nil else { return KeyRegistrationFixture.previewQuote(base: plain) }
                return paid
            }
        )
    }

    private func read(
        budget: String = "5000",
        psbt: String,
        sender: String = BtcFixture.sender,
        delivery: StubDepositDelivery = StubDepositDelivery()
    ) async throws -> PerpsDepositQuote {
        try await read(budget: budget, payloads: [.btc("p_btc", psbt: psbt)], sender: sender, delivery: delivery)
    }

    private func read(
        budget: String = "5000",
        payloads: [Components.Schemas.QuotePayload],
        sender: String = BtcFixture.sender,
        provider: String = "relay",
        security: PerpsSecurityConfig? = KeyRegistrationFixture.security,
        delivery: StubDepositDelivery = StubDepositDelivery()
    ) async throws -> PerpsDepositQuote {
        try await makeService(
            api: FundingStubAPI(quoteDeposit: .success(Self.quote(budget: budget, sender: sender, payloads: payloads, provider: provider))),
            delivery: delivery,
            security: security
        ).quote(
            sourceAsset: BitcoinPsbtFixture.asset.assetId,
            sourceAmountUnits: budget,
            senderAddress: sender,
            beneficiary: PaymentFixture.sender
        )
    }

    private func assertRefused(
        _ psbt: String,
        _ expected: PerpsDepositQuoteError,
        _ message: String = "",
        provider: String = "relay",
        security: PerpsSecurityConfig? = KeyRegistrationFixture.security,
        delivery: StubDepositDelivery = StubDepositDelivery(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await assertRefused(payloads: [.btc("p_btc", psbt: psbt)], expected, message, provider: provider, security: security, delivery: delivery, file: file, line: line)
    }

    private func assertRefused(
        payloads: [Components.Schemas.QuotePayload],
        _ expected: PerpsDepositQuoteError,
        _ message: String = "",
        provider: String = "relay",
        security: PerpsSecurityConfig? = KeyRegistrationFixture.security,
        delivery: StubDepositDelivery = StubDepositDelivery(),
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await read(payloads: payloads, provider: provider, security: security, delivery: delivery)
            XCTFail("expected \(expected) \(message)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, expected, message, file: file, line: line)
        }
    }

    private static func quote(
        budget: String,
        sender: String = BtcFixture.sender,
        payloads: [Components.Schemas.QuotePayload],
        provider: String = "relay"
    ) -> Components.Schemas.DepositQuote {
        var quote = PaymentFixture.crosschainQuote(asset: BitcoinPsbtFixture.asset.assetId, amount: budget, sender: sender, payloads: payloads)
        quote.provider = provider
        return quote
    }

    private func journal() -> PerpsPendingJournal {
        PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directoryURL)
    }

    private func makeService(
        api: FundingStubAPI,
        delivery: StubDepositDelivery = StubDepositDelivery(),
        security: PerpsSecurityConfig? = KeyRegistrationFixture.security
    ) -> PerpsDepositService {
        let served = ServedSecurityConfig(security)
        return PerpsDepositService(
            walletId: "multichain-wallet",
            walletIdentity: "wallet",
            environment: "mainnet",
            journal: journal(),
            api: api,
            delivery: delivery,
            gate: OperationGate { [] },
            keyRegistration: { KeyRegistrationFixture.registration },
            securityConfig: { served.config },
            now: { KeyRegistrationFixture.now },
            makeOperationId: { "op-1" }
        )
    }
}

enum BitcoinPsbtFixture {
    static let asset = PerpsFundingAsset(assetId: "btc/mainnet/coin", symbol: "BTC", decimals: 8)

    static let depository = "bc1qzmtn0q92ayejt2hpffvlktcpmyy7vvsd06sefu"
    static let depositoryScript = "001416d73780aae93325aae14a59fb2f01d909e6320d"
    static let senderScript = "0014dc6bf86354105de2fcd9868a2b0376d6731cb92f"
    static let foreignScript = "0014211b37827fadd3f121db10767e68c66010a4caed"
    static let taprootSender = "bc1ptfd95kj6tfd95kj6tfd95kj6tfd95kj6tfd95kj6tfd95kj6tfdqy9gdxa"
    static let taprootSenderScript = "5120" + String(repeating: "5a", count: 32)

    static let orderId = "0xba023b545859f2141fa73f8325bc035377a6c3fc1b1096624b5112aba2687951"
    static var orderScript: String {
        opReturn(orderId)
    }

    static let fee: UInt64 = 1398
    static let change: UInt64 = 5499

    struct Input {
        let script: String?
        let value: UInt64
        var sighash: UInt32? = nil
    }

    struct Output {
        let script: String
        let value: UInt64
    }

    static func deposit(amount: UInt64, fee: UInt64 = fee, change: UInt64 = change) -> String {
        build(inputs: [Input(script: senderScript, value: amount + fee + change)], outputs: outputs(amount: amount, change: change))
    }

    static func outputs(amount: UInt64, change: UInt64 = change, changeScript: String = senderScript) -> [Output] {
        [Output(script: depositoryScript, value: amount), Output(script: changeScript, value: change), Output(script: orderScript, value: 0)]
    }

    static func opReturn(_ text: String) -> String {
        "6a" + hex([UInt8(text.utf8.count)] + Array(text.utf8))
    }

    static func build(inputs: [Input], outputs: [Output]) -> String {
        var unsigned = littleEndian(2, 4) + compactSize(inputs.count)
        for index in inputs.indices {
            unsigned += [UInt8](repeating: UInt8(index + 1), count: 32) + littleEndian(0, 4) + compactSize(0) + littleEndian(0xFFFF_FFFD, 4)
        }
        unsigned += compactSize(outputs.count)
        for output in outputs {
            unsigned += serialized(output.script, value: output.value)
        }
        unsigned += littleEndian(0, 4)

        var psbt: [UInt8] = Array("psbt".utf8) + [0xFF] + entry([0x00], unsigned) + [0x00]
        for input in inputs {
            if let script = input.script {
                psbt += entry([0x01], serialized(script, value: input.value))
            }
            if let sighash = input.sighash {
                psbt += entry([0x03], littleEndian(UInt64(sighash), 4))
            }
            psbt.append(0x00)
        }
        psbt += [UInt8](repeating: 0x00, count: outputs.count)
        return Data(psbt).base64EncodedString()
    }

    private static func serialized(_ script: String, value: UInt64) -> [UInt8] {
        let bytes = unhex(script)
        return littleEndian(value, 8) + compactSize(bytes.count) + bytes
    }

    private static func entry(_ key: [UInt8], _ value: [UInt8]) -> [UInt8] {
        compactSize(key.count) + key + compactSize(value.count) + value
    }

    private static func compactSize(_ value: Int) -> [UInt8] {
        value < 0xFD ? [UInt8(value)] : [0xFD] + littleEndian(UInt64(value), 2)
    }

    private static func littleEndian(_ value: UInt64, _ size: Int) -> [UInt8] {
        (0 ..< size).map { UInt8(truncatingIfNeeded: value >> (8 * $0)) }
    }

    private static func unhex(_ hex: String) -> [UInt8] {
        stride(from: 0, to: hex.count, by: 2).map { offset in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            // swiftlint:disable:next force_unwrapping
            return UInt8(hex[start ..< hex.index(start, offsetBy: 2)], radix: 16)!
        }
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}
