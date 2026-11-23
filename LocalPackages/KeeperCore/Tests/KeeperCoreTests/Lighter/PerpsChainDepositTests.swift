import BigInt
import Foundation
@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsChainDepositTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsChainDepositTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    func testATokenDepositFoldedIntoOneBatchIsReadIntoWhatItDeposits() async throws {
        let quote = try await read(.bscToken, [RelayFixture.bscBatch()])

        XCTAssertEqual(quote.relayPaymentUnits, BigUInt(RelayFixture.bscBudget))
        XCTAssertEqual(quote.provider, .relay)
    }

    func testATokenDepositInTwoTransactionsIsReadToo() async throws {
        let quote = try await read(.avaxToken, [
            .evm("p_approve", chain: "avax/mainnet", to: RelayFixture.avaxToken, data: RelayFixture.approve(amountUnits: RelayFixture.avaxBudget)),
            .evm("p_deposit", chain: "avax/mainnet", to: PaymentFixture.relayDepository, data: RelayFixture.depositErc20(token: RelayFixture.avaxToken, amountUnits: RelayFixture.avaxBudget)),
        ])

        XCTAssertEqual(quote.relayPaymentUnits, BigUInt(RelayFixture.avaxBudget))
    }

    func testATokenDepositOfNoLessThanNinetyNinePercentIsSigned() async throws {
        for deposited in ["25000000000000000000", "24750000000000000000"] {
            let quote = try await read(.bscToken, [RelayFixture.bscBatch(depositedUnits: deposited)])

            XCTAssertEqual(quote.relayPaymentUnits.map(String.init), deposited)
        }
        for deposited in ["24749999999999999999", "25000000000000000001", "0"] {
            await assertRefused(.bscToken, [RelayFixture.bscBatch(depositedUnits: deposited)], .unexpectedChainPayment("amount"), deposited)
        }
    }

    func testACoinDepositIsReadIntoTheValueItCarries() async throws {
        let quote = try await read(.bnb, [RelayFixture.bnbDeposit(value: "3990000000000000")])

        XCTAssertEqual(quote.relayPaymentUnits, 3_990_000_000_000_000)
    }

    func testACoinDepositIsRefusedUnlessItIsTheDepositorysNativeDepositOfTheBudget() async {
        let foreign = "0x000000000000000000000000000000000000dead"
        let cases: [(String, Components.Schemas.QuotePayload, PerpsDepositQuoteError)] = [
            ("short by more than one percent", RelayFixture.bnbDeposit(value: "3959999999999999"), .unexpectedChainPayment("value")),
            ("for someone else", RelayFixture.bnbDeposit(data: RelayFixture.depositNative(depositor: foreign)), .unexpectedChainPayment("depositor")),
            ("another call", RelayFixture.bnbDeposit(data: RelayFixture.depositErc20(token: foreign, amountUnits: RelayFixture.bnbBudget)), .unexpectedChainPayment("deposit")),
            ("to another contract", RelayFixture.bnbDeposit(to: foreign), .unexpectedChainPayment("relay target")),
        ]
        for (name, payload, expected) in cases {
            await assertRefused(.bnb, [payload], expected, name)
        }
    }

    func testATokenDepositIsRefusedUnlessItIsTheDepositorysDepositOfTheSourceToken() async {
        let foreign = "0x000000000000000000000000000000000000dead"
        let budget = RelayFixture.bscBudget
        let token = KeyRegistrationFixture.bscToken
        let cases: [(String, [(to: String, data: String)], PerpsDepositQuoteError)] = [
            ("another depository", [
                (token, RelayFixture.approve(spender: foreign, amountUnits: budget)),
                (foreign, RelayFixture.depositErc20(token: token, amountUnits: budget)),
            ], .unexpectedChainPayment("relay target")),
            ("another call of the depository", [
                (token, RelayFixture.approve(amountUnits: budget)),
                (PaymentFixture.relayDepository, RelayFixture.depositNative()),
            ], .unexpectedChainPayment("deposit")),
            ("for someone else", [
                (token, RelayFixture.approve(amountUnits: budget)),
                (PaymentFixture.relayDepository, RelayFixture.depositErc20(depositor: foreign, token: token, amountUnits: budget)),
            ], .unexpectedChainPayment("depositor")),
            ("of another token", [
                (token, RelayFixture.approve(amountUnits: budget)),
                (PaymentFixture.relayDepository, RelayFixture.depositErc20(token: foreign, amountUnits: budget)),
            ], .unexpectedChainPayment("token")),
            ("approving someone else", [
                (token, RelayFixture.approve(spender: foreign, amountUnits: budget)),
                (PaymentFixture.relayDepository, RelayFixture.depositErc20(token: token, amountUnits: budget)),
            ], .unexpectedChainPayment("approve")),
            ("approving more than the amount", [
                (token, RelayFixture.approve(amountUnits: (BigUInt(2).power(256) - 1).description)),
                (PaymentFixture.relayDepository, RelayFixture.depositErc20(token: token, amountUnits: budget)),
            ], .unexpectedChainPayment("approve")),
            ("a call besides", [
                (token, RelayFixture.approve(amountUnits: budget)),
                (PaymentFixture.relayDepository, RelayFixture.depositErc20(token: token, amountUnits: budget)),
                (token, RelayFixture.transfer(to: foreign, amountUnits: budget)),
            ], .unexpectedChainPayment("calls")),
            ("a transfer of the token", [
                (token, RelayFixture.transfer(to: foreign, amountUnits: budget)),
            ], .unexpectedChainPayment("relay payment")),
        ]
        for (name, calls, expected) in cases {
            await assertRefused(.bscToken, [RelayFixture.bscBatch(calls: calls)], expected, name)
        }
    }

    func testRelaysApprovalProxyIsPaidForWhatItsCallTransfersWithOrWithoutAnApproval() async throws {
        let budget = RelayFixture.usdtBudget
        for transferred in [budget, "1834446"] {
            let call = RelayFixture.proxyCall(amounts: [transferred])
            let approved = try await read(.usdt, [RelayFixture.ethereumBatch([
                (PaymentFixture.usdt, RelayFixture.approve(spender: RelayFixture.approvalProxy, amountUnits: transferred)),
                (RelayFixture.approvalProxy, call),
            ])])
            XCTAssertEqual(approved.relayPaymentUnits.map(String.init), transferred)

            let leftFromBefore = try await read(.usdt, [.evm("p_relay", to: RelayFixture.approvalProxy, data: call)])
            XCTAssertEqual(leftFromBefore.relayPaymentUnits.map(String.init), transferred)
        }
    }

    func testRelaysApprovalProxyIsRefusedACallThatPullsAnythingElse() async {
        let foreign = "0x45a9034c5dc4e1731b7ff8f977e50012822d5b9d"
        let budget = RelayFixture.usdtBudget
        let usdt = PaymentFixture.usdt
        let cases: [(String, [Components.Schemas.QuotePayload], PerpsDepositQuoteError)] = [
            ("another token", [.evm("p", to: RelayFixture.approvalProxy, data: RelayFixture.proxyCall(tokens: [foreign]))], .unexpectedChainPayment("approval proxy transfer")),
            ("a second token", [.evm("p", to: RelayFixture.approvalProxy, data: RelayFixture.proxyCall(tokens: [usdt, foreign], amounts: [budget, budget]))], .unexpectedChainPayment("approval proxy transfer")),
            ("the token twice", [.evm("p", to: RelayFixture.approvalProxy, data: RelayFixture.proxyCall(tokens: [usdt, usdt], amounts: ["900000", "900000"]))], .unexpectedChainPayment("approval proxy transfer")),
            ("more than the amount", [.evm("p", to: RelayFixture.approvalProxy, data: RelayFixture.proxyCall(amounts: ["1891182"]))], .unexpectedChainPayment("approval proxy transfer")),
            ("well under the amount", [.evm("p", to: RelayFixture.approvalProxy, data: RelayFixture.proxyCall(amounts: ["1834445"]))], .unexpectedChainPayment("approval proxy transfer")),
            ("nothing", [.evm("p", to: RelayFixture.approvalProxy, data: RelayFixture.proxyCall(tokens: [], amounts: []))], .unexpectedChainPayment("approval proxy transfer")),
            ("no amount", [.evm("p", to: RelayFixture.approvalProxy, data: RelayFixture.proxyCall(amounts: []))], .unexpectedChainPayment("approval proxy transfer")),
            ("another function", [.evm("p", to: RelayFixture.approvalProxy, data: "0x12345678" + RelayFixture.proxyCall().dropFirst(10))], .unexpectedChainPayment("approval proxy call")),
            ("a call it cannot read", [.evm("p", to: RelayFixture.approvalProxy, data: "0xdeadbeef")], .unexpectedChainPayment("approval proxy call")),
            ("arrays out of the call", [.evm("p", to: RelayFixture.approvalProxy, data: String(RelayFixture.proxyCall().prefix(10 + 64 * 7)))], .unexpectedChainPayment("approval proxy call")),
            ("an array at an odd offset", [.evm("p", to: RelayFixture.approvalProxy, data: "0xf9e4bab4" + String(repeating: "0", count: 62) + "c1" + RelayFixture.proxyCall().dropFirst(10 + 64))], .unexpectedChainPayment("approval proxy call")),
            ("approved for less than it transfers", [RelayFixture.ethereumBatch([
                (usdt, RelayFixture.approve(spender: RelayFixture.approvalProxy, amountUnits: "1891180")),
                (RelayFixture.approvalProxy, RelayFixture.proxyCall()),
            ])], .unexpectedChainPayment("approval proxy transfer")),
            ("approved for more than the amount", [RelayFixture.ethereumBatch([
                (usdt, RelayFixture.approve(spender: RelayFixture.approvalProxy, amountUnits: "1891182")),
                (RelayFixture.approvalProxy, RelayFixture.proxyCall()),
            ])], .unexpectedChainPayment("approve")),
            ("approved to another contract", [RelayFixture.ethereumBatch([
                (usdt, RelayFixture.approve(spender: PaymentFixture.relayRouter, amountUnits: budget)),
                (RelayFixture.approvalProxy, RelayFixture.proxyCall()),
            ])], .unexpectedChainPayment("approve")),
        ]
        for (name, payloads, expected) in cases {
            await assertRefused(.usdt, payloads, expected, name)
        }
    }

    func testRelaysRouterOrReceiverIsPaidATokenOnlyBehindAnApprovalOfNoMoreThanTheAmount() async throws {
        let approved = "1878404"
        for contract in [PaymentFixture.relayRouter, RelayFixture.receiver] {
            let quote = try await read(.usdt, [RelayFixture.ethereumBatch([
                (PaymentFixture.usdt, RelayFixture.approve(spender: contract, amountUnits: approved)),
                (contract, "0xdeadbeef"),
            ])])
            XCTAssertEqual(quote.relayPaymentUnits, BigUInt(approved), contract)
            await assertRefused(.usdt, [.evm("p_relay", to: contract, data: "0xdeadbeef")], .unexpectedChainPayment("approve"), contract)
        }
    }

    func testACoinRouteThroughRelaysRouterIsBoundByTheValueItCarries() async throws {
        for value in [RelayFixture.ethBudget, "989700000000000", "970000000000000"] {
            let quote = try await read(.eth, [.evm("p_relay", to: PaymentFixture.relayRouter, value: value, data: "0xcd6e13f7")])
            XCTAssertEqual(quote.relayPaymentUnits.map(String.init), value)
        }

        for value in ["969999999999999", "0"] {
            await assertRefused(.eth, [.evm("p_relay", to: PaymentFixture.relayRouter, value: value, data: "0xcd6e13f7")], .unexpectedChainPayment("value"), value)
        }
        await assertRefused(
            .eth,
            [.evm("p_relay", to: PaymentFixture.relayDepository, value: "989700000000000", data: RelayFixture.depositNative())],
            .unexpectedChainPayment("value"),
            "the depository"
        )
        for (contract, data) in [(RelayFixture.approvalProxy, RelayFixture.proxyCall(tokens: [], amounts: [])), (RelayFixture.receiver, "0xcd6e13f7")] {
            await assertRefused(.eth, [.evm("p_relay", to: contract, value: RelayFixture.ethBudget, data: data)], .unexpectedChainPayment("relay target"), contract)
        }
    }

    func testRelaysContractsAreTheOnesTheSignedConfigNamesForTheSourceChain() async throws {
        let otherRouter = "0x9a6f2c3e1b7d4a8c5e0f1b2d3c4a5e6f7a8b9c0d"
        var security = KeyRegistrationFixture.security
        security.relayRouters = ["bsc": [otherRouter: .erc20Router]]

        let signed = try await read(.bnb, [RelayFixture.bnbDeposit(to: otherRouter, data: "0xcd6e13f7")], security: security)
        XCTAssertEqual(signed.relayPaymentUnits.map(String.init), RelayFixture.bnbBudget)

        await assertRefused(.bnb, [RelayFixture.bnbDeposit(to: PaymentFixture.relayRouter, data: "0xcd6e13f7")], .unexpectedChainPayment("relay target"), "unsigned", security: security)
        await assertRefused(.eth, [.evm("p_relay", to: otherRouter, value: RelayFixture.ethBudget, data: "0xcd6e13f7")], .unexpectedChainPayment("relay target"), "another chain", security: security)

        security.relayRouters = ["eth": [RelayFixture.approvalProxy: .erc20Router]]
        await assertRefused(.usdt, [.evm("p_relay", to: RelayFixture.approvalProxy, data: RelayFixture.proxyCall())], .unexpectedChainPayment("approve"), "read as a router", security: security)
    }

    func testAChainWithoutSignedRoutersStillDepositsThroughRelaysDepository() async throws {
        var security = KeyRegistrationFixture.security
        security.relayRouters["eth"] = nil

        await assertRefused(.usdt, [.evm("p_relay", to: RelayFixture.approvalProxy, data: RelayFixture.proxyCall())], .unexpectedChainPayment("relay target"), security: security)
        let depository = try await read(
            .eth,
            [.evm("p_relay", to: PaymentFixture.relayDepository, value: RelayFixture.ethBudget, data: RelayFixture.depositNative())],
            security: security
        )
        XCTAssertEqual(depository.relayPaymentUnits.map(String.init), RelayFixture.ethBudget)
    }

    func testARouterPaymentReadAgainstABlockCachedBeforeTheChainsRoutersTakesTheDownloadedBlock() async throws {
        var cached = KeyRegistrationFixture.security
        cached.relayRouters = ["bsc": KeyRegistrationFixture.relayRouters]
        let downloads = DownloadCount()
        let service = makeService(
            api: FundingStubAPI(quoteDeposit: .success(Self.quote(.eth, [.evm("p_relay", to: PaymentFixture.relayRouter, value: RelayFixture.ethBudget, data: "0xcd6e13f7")]))),
            security: cached,
            downloaded: { downloads.increment(); return KeyRegistrationFixture.security }
        )

        let quote = try await service.quote(
            sourceAsset: RelayFixture.Source.eth.assetId,
            sourceAmountUnits: RelayFixture.ethBudget,
            senderAddress: PaymentFixture.sender,
            beneficiary: PaymentFixture.sender
        )

        XCTAssertEqual(quote.relayPaymentUnits.map(String.init), RelayFixture.ethBudget)
        XCTAssertEqual(downloads.value, 1)
    }

    func testADepositThatCannotGoThroughRelaysRouterDoesNotWaitForTheDownload() async throws {
        var cached = KeyRegistrationFixture.security
        cached.relayRouters = [:]
        let downloads = DownloadCount()
        let service = makeService(
            api: FundingStubAPI(quoteDeposit: .success(Self.quote(.trx, [RelayFixture.trxDeposit()]))),
            security: cached,
            downloaded: { downloads.increment(); return KeyRegistrationFixture.security }
        )

        let quote = try await service.quote(
            sourceAsset: RelayFixture.Source.trx.assetId,
            sourceAmountUnits: RelayFixture.trxBudget,
            senderAddress: RelayFixture.Source.trx.sender,
            beneficiary: PaymentFixture.sender
        )

        XCTAssertEqual(quote.relayPaymentUnits.map(String.init), RelayFixture.trxBudget)
        XCTAssertEqual(downloads.value, 0)
    }

    func testWithoutRelaysDepositoryForTheChainOnlyThatChainIsRefused() async throws {
        var withoutBsc = KeyRegistrationFixture.security
        withoutBsc.relayEVMDepositories["bsc"] = nil
        withoutBsc.relayRouters["bsc"] = nil
        let unfolded: [Components.Schemas.QuotePayload] = [
            .evm("p_approve", chain: "bsc/mainnet", to: KeyRegistrationFixture.bscToken, data: RelayFixture.approve(amountUnits: RelayFixture.bscBudget)),
            .evm("p_deposit", chain: "bsc/mainnet", to: PaymentFixture.relayDepository, data: RelayFixture.depositErc20(token: KeyRegistrationFixture.bscToken, amountUnits: RelayFixture.bscBudget)),
        ]
        for security in [nil, withoutBsc] {
            await assertRefused(.bscToken, unfolded, .unexpectedChainPayment("relay depository"), security: security)
        }
        await assertRefused(.bscToken, [RelayFixture.bscBatch()], .unexpectedChainPayment("relay depository"), security: withoutBsc)

        let fromEthereum = try await read(
            .eth,
            [.evm("p_relay", to: PaymentFixture.relayDepository, value: RelayFixture.ethBudget, data: RelayFixture.depositNative())],
            security: withoutBsc
        )
        XCTAssertNotNil(fromEthereum.relayPaymentUnits)
    }

    func testUSDCOnEthereumIsNeverPaidThroughRelay() async {
        let usdc = PerpsFundingAssetId.usdcEthereum.replacingOccurrences(of: "eth/mainnet/erc20/", with: "")
        await assertRefused(.usdcEthereum, [
            .evm("p_approve", to: usdc, data: RelayFixture.approve(amountUnits: RelayFixture.usdcBudget)),
            .evm("p_deposit", to: PaymentFixture.relayDepository, data: RelayFixture.depositErc20(token: usdc, amountUnits: RelayFixture.usdcBudget)),
        ], .unexpectedChainPayment("relay source"))
    }

    func testAProviderTheClientDoesNotKnowIsRefused() async {
        await assertRefused(.bscToken, [RelayFixture.bscBatch()], .unexpectedProvider("lifi"), provider: "lifi")
        await assertRefused(.bscToken, [RelayFixture.bscBatch()], .unexpectedProvider("direct"), provider: "direct")
    }

    func testLightersBridgeTakesOnlyOneTransferOfTheAmountToAnotherAddress() async throws {
        let deposit = "0x" + String(repeating: "b", count: 40)
        let quote = try await read(.arbitrumUsdc, [
            .evm("p_bridge", chain: "arb/mainnet", to: RelayFixture.arbitrumUsdc, data: RelayFixture.transfer(to: deposit, amountUnits: RelayFixture.usdcBudget)),
        ], provider: "funxyz")
        XCTAssertNil(quote.relayPaymentUnits)

        for recipient in [PaymentFixture.sender, RelayFixture.arbitrumUsdc] {
            do {
                _ = try await read(.arbitrumUsdc, [
                    .evm("p_bridge", chain: "arb/mainnet", to: RelayFixture.arbitrumUsdc, data: RelayFixture.transfer(to: recipient, amountUnits: RelayFixture.usdcBudget)),
                ], provider: "funxyz")
                XCTFail("a transfer to \(recipient) must not be signed")
            } catch {
                XCTAssertEqual(error as? PerpsDepositCalldataError, .unsafeBridgeTransfer(payloadId: "p_bridge"))
            }
        }
    }

    func testLightersBridgeTakesOnlyUSDCFromTheChainsItBridges() async {
        let deposit = "0x" + String(repeating: "b", count: 40)
        await assertRefused(.bscToken, [
            .evm("p_bridge", chain: "bsc/mainnet", to: KeyRegistrationFixture.bscToken, data: RelayFixture.transfer(to: deposit, amountUnits: RelayFixture.bscBudget)),
        ], .unexpectedChainPayment("bridge source"), provider: "funxyz")
    }

    func testADirectDepositPaysOnlyTheGatewayTheBackendSigned() async throws {
        var withoutGateway = KeyRegistrationFixture.security
        withoutGateway.lighterGateway = nil
        for security in [nil, withoutGateway] {
            do {
                _ = try await makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), security: security).quote(
                    sourceAsset: PerpsFundingAssetId.usdcEthereum,
                    sourceAmountUnits: "2500000",
                    senderAddress: PaymentFixture.sender,
                    beneficiary: PaymentFixture.sender
                )
                XCTFail("a direct deposit must not be signed without the signed gateway")
            } catch {
                XCTAssertEqual(error as? PerpsDepositQuoteError, .unexpectedChainPayment("lighter gateway"))
            }
        }

        var elsewhere = KeyRegistrationFixture.security
        elsewhere.lighterGateway = "0x000000000000000000000000000000000000dead"
        do {
            _ = try await makeService(api: FundingStubAPI(quoteDeposit: .success(PaymentFixture.directQuote())), security: elsewhere).quote(
                sourceAsset: PerpsFundingAssetId.usdcEthereum,
                sourceAmountUnits: "2500000",
                senderAddress: PaymentFixture.sender,
                beneficiary: PaymentFixture.sender
            )
            XCTFail("a deposit into another gateway must not be signed")
        } catch {
            XCTAssertNotNil(error as? PerpsDepositCalldataError)
        }
    }

    func testATrxDepositIsReadIntoTheValueItCarries() async throws {
        let quote = try await read(.trx, [RelayFixture.trxDeposit()])

        XCTAssertEqual(quote.relayPaymentUnits.map(String.init), RelayFixture.trxBudget)
    }

    func testATrc20DepositIsAnApprovalOfTheDepositoryAndItsDeposit() async throws {
        let quote = try await read(.trc20, RelayFixture.trc20Deposit())

        XCTAssertEqual(quote.relayPaymentUnits.map(String.init), RelayFixture.trc20Budget)
    }

    func testATronDepositIsRefusedUnlessItIsTheDepositorysForTheSender() async {
        let foreignHex = "0x" + String(repeating: "d", count: 40)
        await assertRefused(.trx, [RelayFixture.trxDeposit(to: TronFixture.usdt)], .unexpectedChainPayment("relay target"), "another contract")
        await assertRefused(.trx, [RelayFixture.trxDeposit(data: RelayFixture.tronData(RelayFixture.depositNative(depositor: foreignHex)))], .unexpectedChainPayment("depositor"), "someone else")
        await assertRefused(.trx, [RelayFixture.trxDeposit(value: "3959999")], .unexpectedChainPayment("value"), "short")
        await assertRefused(.trx, [RelayFixture.trxDeposit(value: "4000001")], .overspend(spent: "4000001", budget: RelayFixture.trxBudget), "over")
        await assertRefused(.trc20, RelayFixture.trc20Deposit(approvedSpenderHex: String(repeating: "d", count: 40)), .unexpectedChainPayment("approve"), "approving someone else")
        await assertRefused(.trc20, RelayFixture.trc20Deposit(depositedUnits: "2000001"), .unexpectedChainPayment("amount"), "depositing more")
    }

    func testATronDepositIsOnlyRelaysWithNoMemoAndOnlyWhileTheBlockNamesItsDepository() async {
        await assertRefused(.trx, [RelayFixture.trxDeposit()], .unexpectedChainPayment("provider"), provider: "funxyz")
        var withoutTron = KeyRegistrationFixture.security
        withoutTron.relayTronDepositories = []
        for security in [nil, withoutTron] {
            await assertRefused(.trx, [RelayFixture.trxDeposit()], .unexpectedChainPayment("relay depository"), security: security)
        }
        let memo = Components.Schemas.QuotePayload.payload("p_trx", chain: "tron/mainnet", meta: [
            "to": TronFixture.router,
            "value": RelayFixture.trxBudget,
            "data": RelayFixture.tronData(RelayFixture.depositNative(depositor: RelayFixture.tronSenderHex)),
            "memo": "pay",
        ])
        await assertRefused(.trx, [memo], .malformedPayload(payloadId: "p_trx"))
    }

    func testATronPaymentIsChargedTheWalletsPriceWhenTheQuoteLeavesOutBandwidth() async throws {
        let delivery = StubDepositDelivery()
        delivery.walletFeeUnits = ["p_trx": 532_500]
        let quoted = Self.quote(.trx, [RelayFixture.trxDeposit(fee: "399250")])
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(quoted)), delivery: delivery)

        _ = try await service.review(
            sourceAsset: PerpsFundingAsset(assetId: RelayFixture.Source.trx.assetId, symbol: "TRX", decimals: 6),
            amount: "4",
            senderAddress: TronFixture.sender,
            beneficiary: PaymentFixture.sender,
            registeringKey: false
        )

        let priced = try XCTUnwrap(delivery.pricedOperations.last)
        XCTAssertEqual(priced.quotedNetworkFeeUnits(on: .tron), 532_500)
        XCTAssertEqual(
            try PerpsDepositQuoteReader.payloads(of: priced, sourceAsset: XCTUnwrap(PerpsFundingAssetId.parse(RelayFixture.Source.trx.assetId)), sender: TronFixture.sender, security: nil).payloads,
            try PerpsDepositQuoteReader.payloads(of: PerpsDepositOperation(quoted.operation), sourceAsset: XCTUnwrap(PerpsFundingAssetId.parse(RelayFixture.Source.trx.assetId)), sender: TronFixture.sender, security: nil).payloads
        )
        XCTAssertEqual(try delivery.walletPricedOperations.map { try $0.quotedFeeUnits(on: .tron).map(\.units) }, [[399_250]])
        XCTAssertEqual(delivery.bandwidthRequests, 0)
    }

    func testATronPaymentKeepsItsQuotedFeeWhenTheWalletPricesItLower() async throws {
        let delivery = StubDepositDelivery()
        delivery.walletFeeUnits = ["p_trx": 187_500]
        let quoted = Self.quote(.trx, [RelayFixture.trxDeposit(fee: "399250")])

        let quote = try await read(quoted, delivery: delivery)

        XCTAssertEqual(try quote.operation.quotedFeeUnits(on: .tron).map(\.units), [399_250])
        XCTAssertEqual(delivery.bandwidthRequests, 0)
    }

    func testATronCallTheWalletCannotSimulateCostsItsQuoteAndTheBandwidth() async throws {
        let delivery = StubDepositDelivery()
        delivery.walletFeeUnits = ["p_approve": 100_000]
        delivery.bandwidthFeeUnits = 345_000
        let payloads = RelayFixture.trc20Deposit(depositFee: "11233560")

        let quote = try await read(Self.quote(.trc20, payloads), delivery: delivery)

        let fees = try quote.operation.quotedFeeUnits(on: .tron)
        XCTAssertEqual(fees.map(\.payloadId), ["p_deposit"])
        XCTAssertEqual(fees.map(\.units), [11_578_560])
        XCTAssertEqual(delivery.bandwidthRequests, 1)
    }

    func testATronDepositIsNotQuotedWhileTheWalletCanPriceNeitherTheCallNorItsBandwidth() async {
        let delivery = StubDepositDelivery()
        delivery.bandwidthFeeUnits = nil

        do {
            _ = try await read(Self.quote(.trx, [RelayFixture.trxDeposit(fee: "399250")]), delivery: delivery)
            XCTFail("a payment the wallet cannot price must not be quoted")
        } catch {
            XCTAssertEqual(error as? PerpsDepositServiceError, .networkFeeUnavailable)
            XCTAssertEqual(PerpsDepositService.message(for: error), .failed)
        }
    }

    func testOnlyATronPaymentIsPricedByTheWallet() async throws {
        let delivery = StubDepositDelivery()
        var deposit = RelayFixture.bnbDeposit()
        deposit.setFee(.value(.init(_type: .value, asset_id: RelayFixture.Source.bnb.assetId, data: .init(amount: "1000"))))

        _ = try await read(Self.quote(.bnb, [deposit]), delivery: delivery)

        XCTAssertTrue(delivery.walletPricedOperations.isEmpty)
        XCTAssertEqual(delivery.bandwidthRequests, 0)
    }

    func testTheReviewOfARelayDepositShowsWhatItSendsAndRelay() async throws {
        let service = makeService(api: FundingStubAPI(quoteDeposit: .success(Self.quote(.bscToken, [RelayFixture.bscBatch(depositedUnits: "24900000000000000000")]))))

        let review = try await service.review(
            sourceAsset: KeyRegistrationFixture.bscAsset,
            amount: "25",
            senderAddress: PaymentFixture.sender,
            beneficiary: PaymentFixture.sender,
            registeringKey: false
        )

        XCTAssertEqual(review.sentAmount, "24.9")
        XCTAssertEqual(review.provider, "Relay")
    }

    private func read(
        _ source: RelayFixture.Source,
        _ payloads: [Components.Schemas.QuotePayload],
        provider: String = "relay",
        security: PerpsSecurityConfig? = KeyRegistrationFixture.security
    ) async throws -> PerpsDepositQuote {
        try await makeService(api: FundingStubAPI(quoteDeposit: .success(Self.quote(source, payloads, provider: provider))), security: security).quote(
            sourceAsset: source.assetId,
            sourceAmountUnits: source.budget,
            senderAddress: source.sender,
            beneficiary: PaymentFixture.sender
        )
    }

    private func read(_ quoted: Components.Schemas.DepositQuote, delivery: StubDepositDelivery) async throws -> PerpsDepositQuote {
        try await makeService(api: FundingStubAPI(quoteDeposit: .success(quoted)), delivery: delivery).quote(
            sourceAsset: quoted.input.asset_id,
            sourceAmountUnits: quoted.input.amount,
            senderAddress: quoted.input.address,
            beneficiary: PaymentFixture.sender
        )
    }

    private func assertRefused(
        _ source: RelayFixture.Source,
        _ payloads: [Components.Schemas.QuotePayload],
        _ expected: PerpsDepositQuoteError,
        _ message: String = "",
        provider: String = "relay",
        security: PerpsSecurityConfig? = KeyRegistrationFixture.security,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await read(source, payloads, provider: provider, security: security)
            XCTFail("expected \(expected) \(message)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, expected, message, file: file, line: line)
        }
    }

    private static func quote(
        _ source: RelayFixture.Source,
        _ payloads: [Components.Schemas.QuotePayload],
        provider: String = "relay"
    ) -> Components.Schemas.DepositQuote {
        var quote = PaymentFixture.crosschainQuote(asset: source.assetId, amount: source.budget, sender: source.sender, payloads: payloads)
        quote.provider = provider
        return quote
    }

    private func makeService(
        api: FundingStubAPI,
        security: PerpsSecurityConfig? = KeyRegistrationFixture.security,
        downloaded: @escaping @Sendable () async -> PerpsSecurityConfig? = { nil },
        delivery: StubDepositDelivery = StubDepositDelivery()
    ) -> PerpsDepositService {
        let served = ServedSecurityConfig(security)
        return PerpsDepositService(
            walletId: "multichain-wallet",
            walletIdentity: "wallet",
            environment: "mainnet",
            journal: PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directoryURL),
            api: api,
            delivery: delivery,
            gate: OperationGate { [] },
            keyRegistration: { KeyRegistrationFixture.registration },
            securityConfig: { served.config },
            downloadedSecurityConfig: downloaded,
            now: { KeyRegistrationFixture.now },
            makeOperationId: { "op-1" }
        )
    }
}

enum RelayFixture {
    enum Source {
        case bscToken, avaxToken, bnb, eth, usdt, usdcEthereum, arbitrumUsdc, trx, trc20

        var assetId: String {
            switch self {
            case .bscToken: KeyRegistrationFixture.bscAsset.assetId
            case .avaxToken: "avax/mainnet/erc20/\(RelayFixture.avaxToken)"
            case .bnb: "bsc/mainnet/coin"
            case .eth: "eth/mainnet/coin"
            case .usdt: PaymentFixture.usdtAsset
            case .usdcEthereum: PerpsFundingAssetId.usdcEthereum
            case .arbitrumUsdc: "arb/mainnet/erc20/\(RelayFixture.arbitrumUsdc)"
            case .trx: "tron/mainnet/coin"
            case .trc20: "tron/mainnet/trc20/\(TronFixture.usdt)"
            }
        }

        var budget: String {
            switch self {
            case .bscToken: RelayFixture.bscBudget
            case .avaxToken: RelayFixture.avaxBudget
            case .bnb: RelayFixture.bnbBudget
            case .eth: RelayFixture.ethBudget
            case .usdt: RelayFixture.usdtBudget
            case .usdcEthereum, .arbitrumUsdc: RelayFixture.usdcBudget
            case .trx: RelayFixture.trxBudget
            case .trc20: RelayFixture.trc20Budget
            }
        }

        var sender: String {
            switch self {
            case .trx, .trc20: TronFixture.sender
            default: PaymentFixture.sender
            }
        }
    }

    static let bscBudget = KeyRegistrationFixture.bscAmountUnits
    static let avaxToken = "0x9702230a8ea53601f5cd2dc00fdbc13d4df4a8c7"
    static let avaxBudget = "3000000"
    static let bnbBudget = "4000000000000000"
    static let ethBudget = "1000000000000000"
    static let usdtBudget = "1891181"
    static let usdcBudget = "2500000"
    static let trxBudget = "4000000"
    static let trc20Budget = "2000000"
    static let arbitrumUsdc = "0xaf88d065e77c8cc2239327c5edb3a432268e5831"
    static let approvalProxy = "0x5567954cd026cebfe486062cb75848e0f1c12e58"
    static let receiver = "0xa5f565650890fba1824ee0f21ebbbf660a179934"
    static let orderId = String(repeating: "ab", count: 32)
    static var tronSenderHex: String {
        PerpsDepositCalldata.normalizedAddress(TronFixture.sender)
    }

    static func bscBatch(depositedUnits: String = bscBudget) -> Components.Schemas.QuotePayload {
        bscBatch(calls: [
            (KeyRegistrationFixture.bscToken, approve(amountUnits: bscBudget)),
            (PaymentFixture.relayDepository, depositErc20(token: KeyRegistrationFixture.bscToken, amountUnits: depositedUnits)),
        ])
    }

    static func bscBatch(calls: [(to: String, data: String)]) -> Components.Schemas.QuotePayload {
        .evm(
            "p_batch",
            chain: "bsc/mainnet",
            to: PaymentFixture.sender,
            data: HermesBatchFixture.execute(calls),
            authorization: .init(chainId: 56, address: PerpsDepositCalldata.hermesDelegate, nonce: 25)
        )
    }

    static func ethereumBatch(_ calls: [(to: String, data: String)]) -> Components.Schemas.QuotePayload {
        .evm("p_batch", to: PaymentFixture.sender, data: HermesBatchFixture.execute(calls))
    }

    static func bnbDeposit(
        to: String = PaymentFixture.relayDepository,
        value: String = bnbBudget,
        data: String = depositNative()
    ) -> Components.Schemas.QuotePayload {
        .evm("p_deposit", chain: "bsc/mainnet", to: to, value: value, data: data)
    }

    static func trxDeposit(
        to: String = TronFixture.router,
        value: String = trxBudget,
        data: String? = nil,
        fee: String? = nil
    ) -> Components.Schemas.QuotePayload {
        var payload = Components.Schemas.QuotePayload.tron("p_trx", to: to, value: value, data: data ?? tronData(depositNative(depositor: tronSenderHex)))
        payload.setFee(fee.map(trxFee))
        return payload
    }

    static func trc20Deposit(
        approvedSpenderHex: String = TronFixture.routerHex,
        depositedUnits: String = trc20Budget,
        depositFee: String? = nil
    ) -> [Components.Schemas.QuotePayload] {
        var deposit = Components.Schemas.QuotePayload.tron("p_deposit", to: TronFixture.router, data: tronData(depositErc20(
            depositor: tronSenderHex,
            token: PerpsDepositCalldata.normalizedAddress(TronFixture.usdt),
            amountUnits: depositedUnits
        )))
        deposit.setFee(depositFee.map(trxFee))
        return [
            .tron("p_approve", to: TronFixture.usdt, data: TronFixture.approve(spenderHex: approvedSpenderHex, amountUnits: trc20Budget)),
            deposit,
        ]
    }

    static func trxFee(_ units: String) -> Components.Schemas.PayloadFee {
        .value(.init(_type: .value, asset_id: Source.trx.assetId, data: .init(amount: units)))
    }

    static func tronData(_ data: String) -> String {
        String(data.dropFirst(2))
    }

    static func proxyCall(tokens: [String] = [PaymentFixture.usdt], amounts: [String] = [usdtBudget]) -> String {
        let headBytes = 6 * 32
        let tokensOffset = headBytes
        let amountsOffset = tokensOffset + (tokens.count + 1) * 32
        let callsOffset = amountsOffset + (amounts.count + 1) * 32
        let metadataOffset = callsOffset + 32
        let head = [uint(String(tokensOffset)), uint(String(amountsOffset)), uint(String(callsOffset)), address(PaymentFixture.sender), address(PaymentFixture.sender), uint(String(metadataOffset))]
        let tail = [uint(String(tokens.count))] + tokens.map(address) + [uint(String(amounts.count))] + amounts.map(uint) + [uint("0"), uint("0")]
        return "0x" + PerpsChainDepositReader.transferAndMulticallSelector + (head + tail).joined()
    }

    static func approve(spender: String = PaymentFixture.relayDepository, amountUnits: String) -> String {
        HermesBatchFixture.approve(spender: spender, amountUnits: amountUnits)
    }

    static func transfer(to recipient: String, amountUnits: String) -> String {
        "0x" + PerpsDepositCalldata.transferSelector + address(recipient) + uint(amountUnits)
    }

    static func depositErc20(depositor: String = PaymentFixture.sender, token: String, amountUnits: String) -> String {
        "0x" + PerpsChainDepositReader.depositErc20Selector + address(depositor) + address(token) + uint(amountUnits) + orderId
    }

    static func depositNative(depositor: String = PaymentFixture.sender) -> String {
        "0x" + PerpsChainDepositReader.depositNativeSelector + address(depositor) + orderId
    }

    private static func address(_ value: String) -> String {
        String(repeating: "0", count: 24) + value.lowercased().dropFirst(2)
    }

    private static func uint(_ units: String) -> String {
        let hex = String(BigUInt(units) ?? 0, radix: 16)
        return String(repeating: "0", count: 64 - hex.count) + hex
    }
}

private final class DownloadCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}
