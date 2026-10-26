@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsDepositQuoteTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testARelayQuoteIsReadIntoWhatTheWalletHasToSign() throws {
        let request = Fixtures.tonRequest()

        let quote = try PerpsDepositQuoteReader.read(Fixtures.relayQuote(), request: request, now: now)

        XCTAssertEqual(quote.route, .crosschainSwap)
        XCTAssertEqual(quote.executionId, "exec-1")
        XCTAssertEqual(quote.sourceAsset.chainId, "ton/mainnet")
        XCTAssertEqual(quote.sourceAmountUnits, "25000000000")
        XCTAssertEqual(quote.depositAmountUnits, "34746294")
        XCTAssertEqual(quote.beneficiary, Fixtures.beneficiary)
        XCTAssertEqual(quote.payloads.map(\.kind), [.main])
        XCTAssertEqual(quote.payloads.first?.valueUnits, "25000000000")
        XCTAssertEqual(quote.payloads.first?.mode, 1)
    }

    func testADirectQuoteCarriesItsApprovalAndNoTracking() throws {
        let request = Fixtures.usdcRequest()

        let quote = try PerpsDepositQuoteReader.read(Fixtures.directQuote(), request: request, now: now)

        XCTAssertEqual(quote.route, .directGateway)
        XCTAssertNil(quote.executionId)
        XCTAssertEqual(quote.payloads.map(\.kind), [.approval, .main])
        XCTAssertEqual(quote.payloads.map(\.chainId), ["eth/mainnet", "eth/mainnet"])
        XCTAssertEqual(quote.payloads.map(\.gasLimitUnits), [nil, nil])
    }

    func testABeneficiaryInAnotherCaseIsStillOurOwnAddress() throws {
        let quote = Fixtures.relayQuote(destination: Fixtures.beneficiary.uppercased().replacingOccurrences(of: "0X", with: "0x"))

        XCTAssertNoThrow(try PerpsDepositQuoteReader.read(quote, request: Fixtures.tonRequest(), now: now))
    }

    func testAQuoteForSomebodyElsesAccountIsRefused() {
        let foreign = "0x000000000000000000000000000000000000dead"
        let quote = Fixtures.relayQuote(destination: foreign)

        assertRefused(quote, Fixtures.tonRequest(), .beneficiaryMismatch(expected: Fixtures.beneficiary, quoted: foreign))
    }

    func testAnExpiredQuoteIsNotSigned() {
        let expiry = now.addingTimeInterval(-1)

        assertRefused(Fixtures.relayQuote(expiresAt: expiry), Fixtures.tonRequest(), .expired(expiry))
    }

    func testAnEchoThatDoesNotMatchTheRequestIsRefused() {
        assertRefused(
            Fixtures.relayQuote(echoAmount: "24000000000"),
            Fixtures.tonRequest(),
            .echoMismatch(field: "source_amount")
        )
        assertRefused(
            Fixtures.relayQuote(echoSender: "UQother"),
            Fixtures.tonRequest(),
            .echoMismatch(field: "sender_address")
        )
    }

    func testADepositOfSomethingOtherThanUsdcOnEthereumIsRefused() {
        let foreign = "eth/mainnet/erc20/0x0000000000000000000000000000000000000001"

        assertRefused(Fixtures.relayQuote(outputAsset: foreign), Fixtures.tonRequest(), .unexpectedTargetAsset(foreign))
    }

    func testADepositThatIsNotExactIsRefused() {
        assertRefused(
            Fixtures.relayQuote(minAmount: "34000000"),
            Fixtures.tonRequest(),
            .inexactDeposit(expected: "34746294", minimum: "34000000")
        )
    }

    func testADepositBelowTheGatewayFloorIsRefused() {
        assertRefused(
            Fixtures.relayQuote(expectedAmount: "999999", minAmount: "999999"),
            Fixtures.tonRequest(),
            .belowGatewayMinimum("999999")
        )
    }

    func testAmountsThatAreNotPlainIntegersAreRefused() {
        assertRefused(
            Fixtures.relayQuote(expectedAmount: "34.746294", minAmount: "34.746294"),
            Fixtures.tonRequest(),
            .malformedAmount(field: "expected_amount")
        )
    }

    func testARelayFillWithNothingToPollIsRefused() {
        assertRefused(Fixtures.relayQuote(executionId: nil), Fixtures.tonRequest(), .missingTracking)
        assertRefused(Fixtures.relayQuote(executionId: ""), Fixtures.tonRequest(), .missingTracking)
    }

    func testADirectQuoteThatClaimsTrackingIsRefused() {
        assertRefused(Fixtures.directQuote(executionId: "exec-1"), Fixtures.usdcRequest(), .unexpectedTracking)
    }

    func testAProviderNameDoesNotDecideTheRoute() throws {
        let quote = try PerpsDepositQuoteReader.read(
            Fixtures.relayQuote(provider: "direct"),
            request: Fixtures.tonRequest(),
            now: now
        )

        XCTAssertEqual(quote.route, .crosschainSwap)
    }

    func testARelayFillWithoutTrackingIsRefused() {
        assertRefused(Fixtures.relayQuote(executionId: nil), Fixtures.tonRequest(), .missingTracking)
    }

    func testAQuoteAnsweringAnotherRequestIsRefused() {
        assertRefused(
            Fixtures.directQuote(),
            Fixtures.tonRequest(),
            .echoMismatch(field: "source_asset")
        )
    }

    func testAPayloadOnAnotherChainIsRefused() {
        let quote = Fixtures.relayQuote(payloads: [Fixtures.payload(chain: "bsc/mainnet")])

        assertRefused(
            quote,
            Fixtures.tonRequest(),
            .payloadChainMismatch(payloadId: "p_01", expected: "ton/mainnet", quoted: "eip155:56")
        )
    }

    func testAnApprovalWithoutItsMainIsRefused() {
        assertRefused(Fixtures.directQuote(payloads: [Fixtures.approval]), Fixtures.usdcRequest(), .approvalWithoutMain)
    }

    func testAPayloadTypeThisClientDoesNotKnowIsRefused() throws {
        var raw = Fixtures.payload().value
        raw["type"] = "batch"
        let payload = try Components.Schemas.QuotePayload(unvalidatedValue: raw)

        assertRefused(Fixtures.relayQuote(payloads: [payload]), Fixtures.tonRequest(), .malformedOperation("op-1"))
    }

    func testAnApproveCallToTheSourceTokenIsReadAsTheApproval() throws {
        let quote = try PerpsDepositQuoteReader.read(Fixtures.directQuote(), request: Fixtures.usdcRequest(), now: now)

        XCTAssertEqual(quote.payloads.map(\.kind), [.approval, .main])
    }

    func testAQuoteWithNothingToSignIsRefused() {
        assertRefused(Fixtures.relayQuote(payloads: []), Fixtures.tonRequest(), .malformedOperation("op-1"))
    }

    func testPayloadsMayNotSpendMoreCoinThanTheBudget() {
        let quote = Fixtures.relayQuote(payloads: [
            Fixtures.payload(value: "20000000000"),
            Fixtures.payload(payloadId: "p_02", value: "6000000000"),
        ])

        assertRefused(
            quote,
            Fixtures.tonRequest(),
            .overspend(spent: "26000000000", budget: "25000000000")
        )
    }

    /// `value` says nothing about what these cost: they spend the balance, the inbound
    /// value, or a bit this client does not know the meaning of.
    func testASendModeTheBudgetDoesNotBoundIsRefused() {
        for mode in [128, 130, 64, 32, 16, 19, 1 | 128, 256, -1] {
            assertRefused(
                Fixtures.relayQuote(payloads: [Fixtures.payload(mode: mode)]),
                Fixtures.tonRequest(),
                .unboundedSendMode(payloadId: "p_01", mode: mode)
            )
        }
    }

    func testASendModeThatSpendsOnlyThePayloadIsSigned() {
        for mode in [0, 1, 3] {
            XCTAssertNoThrow(
                try PerpsDepositQuoteReader.read(
                    Fixtures.relayQuote(payloads: [Fixtures.payload(mode: mode)]),
                    request: Fixtures.tonRequest(),
                    now: now
                ),
                "mode \(mode)"
            )
        }
    }

    /// A token's budget travels in the calldata and an EVM transaction pays its gas
    /// outside `value`, so native value there is a transfer of its own that no term of
    /// the quote bounds.
    func testATokenPayloadThatAlsoSendsNativeValueIsRefused() {
        assertRefused(
            Fixtures.usdtQuote(payloadValue: "40000000000000000"),
            Fixtures.usdtRequest(),
            .overspend(spent: "40000000000000000", budget: "0")
        )
    }

    func testATokenPayloadSpendingNothingOfItsOwnIsSigned() throws {
        let read = try PerpsDepositQuoteReader.read(
            Fixtures.usdtQuote(payloadValue: "0"),
            request: Fixtures.usdtRequest(),
            now: now
        )

        XCTAssertEqual(read.payloads.first?.valueUnits, "0")
    }

    func testAnAssetIdThisClientCannotReadIsRefused() {
        for raw in [
            "", "ton", "ton/mainnet", "ton/mainnet/jetton/EQ", "eth/mainnet/erc20/0x1234",
            "tron/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
            "tron/mainnet/trc20/\(TronFixture.usdt.lowercased())", "btc/mainnet/brc20/ordi",
        ] {
            XCTAssertNil(PerpsFundingAssetId.parse(raw), raw)
        }
    }

    func testTronAndBitcoinAssetIdsAreReadWithTheirOwnFeeCoin() throws {
        let usdt = try XCTUnwrap(PerpsFundingAssetId.parse("tron/mainnet/trc20/\(TronFixture.usdt)"))
        XCTAssertEqual(usdt.kind, .token(address: TronFixture.usdt))
        XCTAssertEqual(usdt.chainId, "tron/mainnet")
        XCTAssertEqual([usdt.nativeSymbol, "\(usdt.nativeDecimals)"], ["TRX", "6"])

        let btc = try XCTUnwrap(PerpsFundingAssetId.parse("btc/mainnet/coin"))
        XCTAssertEqual(btc.kind, .coin)
        XCTAssertEqual([btc.nativeSymbol, "\(btc.nativeDecimals)"], ["BTC", "8"])
    }

    func testATronTokenDepositIsReadAsItsApprovalAndItsCall() throws {
        let quote = try PerpsDepositQuoteReader.read(Fixtures.tronQuote(), request: Fixtures.tronRequest(), now: now)

        XCTAssertEqual(quote.route, .crosschainSwap)
        XCTAssertEqual(quote.payloads.map(\.kind), [.approval, .main])
        XCTAssertEqual(quote.payloads.map(\.to), [TronFixture.usdt, TronFixture.router])
        XCTAssertEqual(quote.payloads.map(\.data), ["0x" + TronFixture.approve(amountUnits: "25000000"), "0xdeadbeef"])
    }

    func testATronPayloadToAnEvmAddressOrToItsOwnSenderIsRefused() {
        assertRefused(
            Fixtures.tronQuote(payloads: [.tron("p_01", to: PerpsDepositCalldata.gatewayAddress, data: "deadbeef")]),
            Fixtures.tronRequest(),
            .malformedOperation("op-1")
        )
        assertRefused(
            Fixtures.tronQuote(payloads: [.tron("p_01", to: TronFixture.sender, data: "deadbeef")]),
            Fixtures.tronRequest(),
            .malformedPayload(payloadId: "p_01")
        )
    }

    func testABitcoinDepositIsReadAsOnePrebuiltTransaction() throws {
        let quote = try PerpsDepositQuoteReader.read(Fixtures.btcQuote(), request: Fixtures.btcRequest(), now: now)

        XCTAssertEqual(quote.payloads.map(\.kind), [.prebuilt])
        XCTAssertEqual(quote.payloads.first?.data, BtcFixture.livePsbt)
        XCTAssertEqual(quote.payloads.first?.valueUnits, BtcFixture.deposited)
    }

    func testABitcoinTransactionPayingAwayMoreThanTheQuoteIsRefused() {
        assertRefused(
            Fixtures.btcQuote(amount: "99706"),
            Fixtures.btcRequest(amount: "99706"),
            .overspend(spent: BtcFixture.deposited, budget: "99706")
        )
    }

    func testBitcoinChangeIsOnlyWhatGoesBackToTheSender() {
        let otherSender = "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"

        assertRefused(
            Fixtures.btcQuote(sender: otherSender),
            Fixtures.btcRequest(sender: otherSender),
            .overspend(spent: "7107264", budget: BtcFixture.deposited)
        )
    }

    func testABitcoinOutputToAScriptWithNoAddressIsRefusedUnlessItCarriesNothing() throws {
        let opReturn: [UInt8] = [0x6A, 0x01, 0x2A]
        let opTrue: [UInt8] = [0x51]
        let unnamed = Fixtures.btcQuote(payloads: [.btc("p_01", psbt: BtcFixture.psbt(outputs: [(0, opReturn)]))])
        XCTAssertNoThrow(try PerpsDepositQuoteReader.read(unnamed, request: Fixtures.btcRequest(), now: now))

        assertRefused(
            Fixtures.btcQuote(payloads: [.btc("p_01", psbt: BtcFixture.psbt(outputs: [(1000, opTrue)]))]),
            Fixtures.btcRequest(),
            .malformedPayload(payloadId: "p_01")
        )
    }

    func testAnUnreadablePsbtIsRefused() {
        assertRefused(
            Fixtures.btcQuote(payloads: [.btc("p_01", psbt: "cHNidP8BAL4CAAAAARp+to64b/gtfLBuI7rEL2YIKXSwIDQna3RBoh4r0B2H")]),
            Fixtures.btcRequest(),
            .malformedPayload(payloadId: "p_01")
        )
    }

    func testABitcoinPayloadThatIsNotPrebuiltIsRefused() {
        assertRefused(
            Fixtures.btcQuote(payloads: [.btc("p_01", type: "main")]),
            Fixtures.btcRequest(),
            .malformedOperation("op-1")
        )
    }

    func testBscBep20AssetIdIsSupported() {
        let assetId = "bsc/mainnet/bep20/0x0000000000000000000000000000000000000001"
        XCTAssertEqual(PerpsFundingAssetId.parse(assetId)?.chainId, "bsc/mainnet")
    }

    func testAFoldedTokenDepositIsReadAsOneBatchCarryingItsDelegation() throws {
        let quote = try PerpsDepositQuoteReader.read(Fixtures.foldedQuote(), request: Fixtures.usdtRequest(), now: now)

        XCTAssertEqual(quote.payloads.map(\.kind), [.batch])
        XCTAssertEqual(quote.payloads.first?.gasLimitUnits, "180000")
        XCTAssertEqual(
            quote.payloads.first?.delegation,
            PerpsDepositDelegation(chainId: 1, address: PerpsDepositCalldata.hermesDelegate, nonce: 12)
        )
    }

    func testAFoldedDepositForAnAlreadyDelegatedAddressCarriesNoDelegation() throws {
        let quote = try PerpsDepositQuoteReader.read(Fixtures.foldedQuote(authorization: nil), request: Fixtures.usdtRequest(), now: now)

        XCTAssertEqual(quote.payloads.map(\.kind), [.batch])
        XCTAssertNil(quote.payloads.first?.delegation)
    }

    func testADelegationToAnyOtherContractIsRefused() {
        let foreign = HermesBatchFixture.authorization(address: "0xd1c44e466b70002ac54fb727ed7cbe8f92c782f1")

        assertRefused(Fixtures.foldedQuote(authorization: foreign), Fixtures.usdtRequest(), .malformedPayload(payloadId: "p_batch"))
    }

    func testADelegationForAnotherChainIsRefused() {
        var authorization = HermesBatchFixture.authorization()
        authorization.chainId = 0

        assertRefused(Fixtures.foldedQuote(authorization: authorization), Fixtures.usdtRequest(), .malformedPayload(payloadId: "p_batch"))
    }

    /// Off Ethereum the backend states no gas, so ChainKit prices the call with the delegate installed.
    func testAFoldedDepositFromAnotherHermesChainIsReadWithoutAGasLimit() throws {
        let token = "0x55d398326f99059ff775485246999027b3197955"
        let amount = "25000000000000000000"
        let spender = "0xf70da97812cb96acdf810712aa562db8dfa3dbef"
        for chain in [MultichainChain.bsc, .arb, .base, .polygon, .robinhood, .avax] {
            let asset = "\(chain.fundingChainId)/\(chain == .bsc ? "bep20" : "erc20")/\(token)"
            let chainId = try Int64(XCTUnwrap(chain.eip155ChainId))
            let quote = Fixtures.relayQuote(
                echoAsset: asset,
                echoAmount: amount,
                echoSender: Fixtures.beneficiary,
                payloads: [.evm(
                    "p_batch",
                    chain: chain.fundingChainId,
                    to: Fixtures.beneficiary,
                    data: HermesBatchFixture.execute([
                        (token, HermesBatchFixture.approve(spender: spender, amountUnits: amount)),
                        (spender, "0xdeadbeef"),
                    ]),
                    authorization: .init(chainId: chainId, address: PerpsDepositCalldata.hermesDelegate, nonce: 25)
                )]
            )
            let request = Fixtures.request(sourceAsset: asset, sourceAmount: amount, sender: Fixtures.beneficiary)
            if chain == .avax {
                assertRefused(quote, request, .malformedPayload(payloadId: "p_batch"))
                continue
            }
            let read = try PerpsDepositQuoteReader.read(quote, request: request, now: now)

            XCTAssertEqual(read.payloads.map(\.kind), [.batch], chain.rawValue)
            XCTAssertNil(read.payloads.first?.gasLimitUnits, chain.rawValue)
            XCTAssertEqual(
                read.payloads.first?.delegation,
                PerpsDepositDelegation(chainId: chainId, address: PerpsDepositCalldata.hermesDelegate, nonce: 25),
                chain.rawValue
            )
        }
    }

    func testACallIntoTheSendersAddressIsRefusedOutsideAFoldedTokenDeposit() {
        let ethRequest = Fixtures.request(sourceAsset: "eth/mainnet/coin", sourceAmount: "1000000000000000", sender: Fixtures.beneficiary)
        let quote = Fixtures.relayQuote(
            echoAsset: "eth/mainnet/coin",
            echoAmount: "1000000000000000",
            echoSender: Fixtures.beneficiary,
            payloads: [.evm("p_01", to: Fixtures.beneficiary, value: "1000000000000000", data: "0xdeadbeef")]
        )

        assertRefused(quote, ethRequest, .malformedPayload(payloadId: "p_01"))
    }

    func testADelegationOnACallToAnotherAddressIsRefused() {
        let quote = Fixtures.relayQuote(
            echoAsset: Fixtures.usdtAsset,
            echoAmount: "25000000",
            echoSender: Fixtures.beneficiary,
            payloads: [.evm(
                "p_01",
                to: PerpsDepositCalldata.gatewayAddress,
                data: "0xdeadbeef",
                gas: "180000",
                authorization: HermesBatchFixture.authorization()
            )]
        )

        assertRefused(quote, Fixtures.usdtRequest(), .malformedPayload(payloadId: "p_01"))
    }

    /// Registering the key from Ethereum, the payment itself delegates the address the key's
    /// `Execute` runs on — so only the address it credits.
    func testAPaymentRegisteringTheKeyFromEthereumCarriesTheDelegation() throws {
        func payment(from sender: String) -> (Components.Schemas.DepositQuote, Components.Schemas.DepositQuoteRequest) {
            let quote = Fixtures.relayQuote(
                echoAsset: "eth/mainnet/coin",
                echoAmount: "1000000000000000",
                echoSender: sender,
                payloads: [.evm(
                    "p_01",
                    to: "0x00000000000000000000000000000000000000ef",
                    value: "1000000000000000",
                    data: "0xdeadbeef",
                    authorization: HermesBatchFixture.authorization()
                )]
            )
            return (quote, Fixtures.request(sourceAsset: "eth/mainnet/coin", sourceAmount: "1000000000000000", sender: sender))
        }
        let (quote, request) = payment(from: Fixtures.beneficiary)
        let (elsewhere, elsewhereRequest) = payment(from: "0x00000000000000000000000000000000000000aa")

        let read = try PerpsDepositQuoteReader.read(quote, request: request, registration: KeyRegistrationFixture.registration, now: now)

        XCTAssertEqual(read.payloads.map(\.kind), [.main])
        XCTAssertEqual(read.payloads.first?.delegation, PerpsDepositDelegation(chainId: 1, address: PerpsDepositCalldata.hermesDelegate, nonce: 12))
        assertRefused(quote, request, .malformedPayload(payloadId: "p_01"))
        XCTAssertThrowsError(try PerpsDepositQuoteReader.read(elsewhere, request: elsewhereRequest, registration: KeyRegistrationFixture.registration, now: now)) {
            XCTAssertEqual($0 as? PerpsDepositQuoteError, .malformedPayload(payloadId: "p_01"))
        }
    }

    private func assertRefused(
        _ quote: Components.Schemas.DepositQuote,
        _ request: Components.Schemas.DepositQuoteRequest,
        _ expected: PerpsDepositQuoteError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try PerpsDepositQuoteReader.read(quote, request: request, now: now), file: file, line: line) { error in
            XCTAssertEqual(error as? PerpsDepositQuoteError, expected, file: file, line: line)
        }
    }
}

private enum Fixtures {
    static let beneficiary = "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984"
    static let tonSender = "UQARERERERERERERERERERERERERERERERERERERERERERbvW"
    static let tonAsset = "ton/mainnet/coin"
    static let usdcAsset = PerpsFundingAssetId.usdcEthereum

    static func tonRequest() -> Components.Schemas.DepositQuoteRequest {
        request(sourceAsset: tonAsset, sourceAmount: "25000000000", sender: tonSender)
    }

    static let usdtAsset = "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"
    static let tronUsdtAsset = "tron/mainnet/trc20/\(TronFixture.usdt)"

    static func tronRequest() -> Components.Schemas.DepositQuoteRequest {
        request(sourceAsset: tronUsdtAsset, sourceAmount: "25000000", sender: TronFixture.sender)
    }

    static func tronQuote(payloads: [Components.Schemas.QuotePayload]? = nil) -> Components.Schemas.DepositQuote {
        relayQuote(
            echoAsset: tronUsdtAsset,
            echoAmount: "25000000",
            echoSender: TronFixture.sender,
            payloads: payloads ?? [
                .tron("p_approve", to: TronFixture.usdt, data: TronFixture.approve(amountUnits: "25000000")),
                .tron("p_pay", to: TronFixture.router, data: "deadbeef"),
            ]
        )
    }

    static func btcRequest(
        amount: String = BtcFixture.deposited,
        sender: String = BtcFixture.sender
    ) -> Components.Schemas.DepositQuoteRequest {
        request(sourceAsset: "btc/mainnet/coin", sourceAmount: amount, sender: sender)
    }

    static func btcQuote(
        amount: String = BtcFixture.deposited,
        sender: String = BtcFixture.sender,
        payloads: [Components.Schemas.QuotePayload]? = nil
    ) -> Components.Schemas.DepositQuote {
        relayQuote(echoAsset: "btc/mainnet/coin", echoAmount: amount, echoSender: sender, payloads: payloads ?? [.btc("p_btc")])
    }

    static func usdcRequest() -> Components.Schemas.DepositQuoteRequest {
        request(sourceAsset: usdcAsset, sourceAmount: "40000000", sender: beneficiary)
    }

    static func usdtRequest() -> Components.Schemas.DepositQuoteRequest {
        request(sourceAsset: usdtAsset, sourceAmount: "25000000", sender: beneficiary)
    }

    static func usdtQuote(payloadValue: String) -> Components.Schemas.DepositQuote {
        relayQuote(
            echoAsset: usdtAsset,
            echoAmount: "25000000",
            echoSender: beneficiary,
            payloads: [payload(chain: "eth/mainnet", value: payloadValue)]
        )
    }

    static func foldedQuote(
        gas: String? = "180000",
        authorization: Components.Schemas.EIP7702AuthorizationTemplate? = HermesBatchFixture.authorization()
    ) -> Components.Schemas.DepositQuote {
        relayQuote(
            echoAsset: usdtAsset,
            echoAmount: "25000000",
            echoSender: beneficiary,
            payloads: [.evm(
                "p_batch",
                to: beneficiary,
                data: HermesBatchFixture.execute([
                    ("0xdac17f958d2ee523a2206206994597c13d831ec7", HermesBatchFixture.approve(spender: PerpsDepositCalldata.gatewayAddress, amountUnits: "25000000")),
                    (PerpsDepositCalldata.gatewayAddress, "0xdeadbeef"),
                ]),
                gas: gas,
                authorization: authorization
            )]
        )
    }

    static func request(
        sourceAsset: String,
        sourceAmount: String,
        sender: String
    ) -> Components.Schemas.DepositQuoteRequest {
        .init(
            source_asset: sourceAsset,
            source_amount: sourceAmount,
            sender_address: sender,
            destination_address: beneficiary
        )
    }

    static func payload(
        payloadId: String = "p_01",
        chain: String = "ton/mainnet",
        value: String = "25000000000",
        mode: Int? = 1
    ) -> Components.Schemas.QuotePayload {
        guard chain.hasPrefix("ton/") else {
            return .evm(payloadId, chain: chain, to: PerpsDepositCalldata.gatewayAddress, value: value, data: "0xdeadbeef")
        }
        return .ton(payloadId, chain: chain, value: value, mode: mode)
    }

    static let approval = Components.Schemas.QuotePayload.evm(
        "p_01",
        to: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        data: "0x095ea7b3000000000000000000000000"
    )

    static func relayQuote(
        provider: String = "relay",
        expiresAt: Date? = nil,
        echoAsset: String = tonAsset,
        echoAmount: String = "25000000000",
        echoSender: String = tonSender,
        outputAsset: String = usdcAsset,
        destination: String = beneficiary,
        expectedAmount: String = "34746294",
        minAmount: String = "34746294",
        executionId: String? = "exec-1",
        payloads: [Components.Schemas.QuotePayload]? = nil
    ) -> Components.Schemas.DepositQuote {
        .init(
            quote_id: "q_1",
            provider: provider,
            created_at: Date(timeIntervalSince1970: 1_699_999_990),
            expires_at: expiresAt ?? Date(timeIntervalSince1970: 1_700_000_060),
            input: .init(asset_id: echoAsset, amount: echoAmount, address: echoSender),
            output: .init(
                asset_id: outputAsset,
                amount: expectedAmount,
                min_amount: minAmount,
                address: destination
            ),
            operation: .transfer(payloads ?? [payload()]),
            tracking: executionId.map { .init(execution_id: $0, status_url: "/funding/status/\($0)") },
            preview: false
        )
    }

    static func directQuote(
        executionId: String? = nil,
        payloads: [Components.Schemas.QuotePayload]? = nil
    ) -> Components.Schemas.DepositQuote {
        .init(
            quote_id: "q_2",
            provider: "direct",
            created_at: Date(timeIntervalSince1970: 1_699_999_990),
            expires_at: Date(timeIntervalSince1970: 1_700_000_060),
            input: .init(asset_id: usdcAsset, amount: "40000000", address: beneficiary),
            output: .init(
                asset_id: usdcAsset,
                amount: "40000000",
                min_amount: "40000000",
                address: beneficiary
            ),
            operation: .transfer(payloads ?? [
                approval,
                payload(payloadId: "p_02", chain: "eth/mainnet", value: "0"),
            ]),
            tracking: executionId.map { .init(execution_id: $0, status_url: "/funding/status/\($0)") },
            preview: false
        )
    }
}
