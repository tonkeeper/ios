import BigInt
import ChainKit
import Foundation
@testable import KeeperCore
import TKPerpsAPI
import XCTest

final class PerpsKeyRegistrationTests: XCTestCase {
    private var directoryURL: URL!

    override func setUpWithError() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerpsKeyRegistrationTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
    }

    // MARK: - Registration

    func testTheGatewayCallRegistersTheKeyOnTheAccountTheDepositCreates() throws {
        let registration = try XCTUnwrap(PerpsKeyRegistration(apiKeyIndex: 3, publicKey: KeyRegistrationFixture.publicKey.uppercased().replacingOccurrences(of: "0X", with: "")))

        XCTAssertEqual(registration.publicKey, KeyRegistrationFixture.publicKey)
        XCTAssertEqual(
            registration.calldata,
            "0x17010c68"
                + String(repeating: "0", count: 52) + "ffffffffffff"
                + String(repeating: "0", count: 63) + "3"
                + String(repeating: "0", count: 62) + "60"
                + String(repeating: "0", count: 62) + "28"
                + KeyRegistrationFixture.publicKey.dropFirst(2) + String(repeating: "0", count: 48)
        )
    }

    func testOnlyAKeySlotAndAFortyByteKeyAreRegistered() {
        XCTAssertNil(PerpsKeyRegistration(apiKeyIndex: 255, publicKey: KeyRegistrationFixture.publicKey))
        XCTAssertNil(PerpsKeyRegistration(apiKeyIndex: -1, publicKey: KeyRegistrationFixture.publicKey))
        XCTAssertNil(PerpsKeyRegistration(apiKeyIndex: 3, publicKey: String(KeyRegistrationFixture.publicKey.dropLast(2))))
        XCTAssertNil(PerpsKeyRegistration(apiKeyIndex: 3, publicKey: String(KeyRegistrationFixture.publicKey.dropLast()) + "g"))
    }

    // MARK: - Preview

    func testAPreviewIsReadForTheDelegationAndTheCallItSigns() throws {
        let preview = try readPreview(KeyRegistrationFixture.previewQuote())

        XCTAssertEqual(preview.quoteId, "q_crosschain")
        XCTAssertEqual(preview.depositAmountUnits, "2500000")
        XCTAssertEqual(preview.sourceAmountUnits, KeyRegistrationFixture.bscAmountUnits)
        XCTAssertEqual(preview.delegationPayloadId, "p_auth")
        XCTAssertEqual(preview.executePayloadId, "p_execute")
    }

    /// Paid from Ethereum the payment delegates the address itself, so only `Execute` is signed ahead.
    func testAPreviewFromEthereumIsTheCallAloneAndGoesBackAlone() throws {
        let preview = try readPreview(KeyRegistrationFixture.ethereumPreviewQuote())

        XCTAssertNil(preview.delegationPayloadId)
        XCTAssertEqual(preview.executePayloadId, "p_execute")
        let operation = try preview.signedOperation(KeyRegistrationFixture.signed().filter { $0.key == "p_execute" })
        let payloads = try operation.payloads.map {
            try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) as? [String: Any])
        }
        XCTAssertEqual(payloads.map { $0["payload_id"] as? String }, ["p_execute"])
    }

    func testAPreviewSpellingTheDomainTypeIsRead() throws {
        var types = KeyRegistrationFixture.executeTypes
        types["EIP712Domain"] = KeyRegistrationFixture.domainType

        XCTAssertNoThrow(try readPreview(KeyRegistrationFixture.previewQuote(typedData: KeyRegistrationFixture.typedData(types: types))))
    }

    func testAPreviewTheWalletMustNotSignIsRefused() throws {
        let other = "0x00000000000000000000000000000000000000aa"
        let otherKey = try XCTUnwrap(PerpsKeyRegistration(apiKeyIndex: 3, publicKey: "0x" + String(repeating: "1", count: 80)))
        let registrationCall = Components.Schemas.HermesExecuteCall(
            target: PerpsDepositCalldata.gatewayAddress,
            value: "0",
            data: KeyRegistrationFixture.registration.calldata
        )
        var extraTypes = KeyRegistrationFixture.executeTypes
        extraTypes["Extra"] = [.init(name: "x", _type: "uint256")]
        var domainWithoutSalt = KeyRegistrationFixture.executeTypes
        domainWithoutSalt["EIP712Domain"] = Array(KeyRegistrationFixture.domainType.dropLast())
        let cases: [(String, Components.Schemas.DepositQuote, PerpsDepositQuoteError)] = [
            ("another delegate", KeyRegistrationFixture.previewQuote(delegate: other), .malformedKeyRegistration("authorization")),
            ("another chain", KeyRegistrationFixture.previewQuote(delegationChainId: 10), .malformedKeyRegistration("authorization")),
            ("one payload", KeyRegistrationFixture.previewQuote(payloads: [KeyRegistrationFixture.authorizationPayload()]), .malformedKeyRegistration("payloads")),
            (
                "another account",
                KeyRegistrationFixture.previewQuote(typedData: KeyRegistrationFixture.typedData(owner: other)),
                .malformedKeyRegistration("execute domain")
            ),
            (
                "another salt",
                KeyRegistrationFixture.previewQuote(typedData: KeyRegistrationFixture.typedData(salt: "0x" + String(repeating: "0", count: 64))),
                .malformedKeyRegistration("execute domain")
            ),
            (
                "unsigned batch mode",
                KeyRegistrationFixture.previewQuote(typedData: KeyRegistrationFixture.typedData(mode: "0x" + PerpsDepositCalldata.plainBatchMode)),
                .malformedKeyRegistration("execute call")
            ),
            (
                "another key",
                KeyRegistrationFixture.previewQuote(typedData: KeyRegistrationFixture.typedData(calls: [.init(
                    target: PerpsDepositCalldata.gatewayAddress,
                    value: "0",
                    data: otherKey.calldata
                )])),
                .malformedKeyRegistration("execute call")
            ),
            (
                "another target",
                KeyRegistrationFixture.previewQuote(typedData: KeyRegistrationFixture.typedData(calls: [.init(
                    target: other,
                    value: "0",
                    data: KeyRegistrationFixture.registration.calldata
                )])),
                .malformedKeyRegistration("execute call")
            ),
            (
                "a second call",
                KeyRegistrationFixture.previewQuote(typedData: KeyRegistrationFixture.typedData(calls: [registrationCall, registrationCall])),
                .malformedKeyRegistration("execute call")
            ),
            (
                "an extra type",
                KeyRegistrationFixture.previewQuote(typedData: KeyRegistrationFixture.typedData(types: extraTypes)),
                .malformedKeyRegistration("execute types")
            ),
            (
                "another domain type",
                KeyRegistrationFixture.previewQuote(typedData: KeyRegistrationFixture.typedData(types: domainWithoutSalt)),
                .malformedKeyRegistration("execute domain type")
            ),
            (
                "a deadline past a day",
                KeyRegistrationFixture.previewQuote(typedData: KeyRegistrationFixture.typedData(deadline: 1_700_000_000 + 86400 + 1)),
                .malformedKeyRegistration("execute nonce or deadline")
            ),
            (
                "a past deadline",
                KeyRegistrationFixture.previewQuote(typedData: KeyRegistrationFixture.typedData(deadline: 1_700_000_000)),
                .malformedKeyRegistration("execute nonce or deadline")
            ),
            ("the direct route", KeyRegistrationFixture.previewQuote(base: PaymentFixture.directQuote()), .malformedKeyRegistration("preview for an Ethereum source")),
            ("a delegation from Ethereum", KeyRegistrationFixture.previewQuote(base: PaymentFixture.approvedRelayQuote()), .malformedKeyRegistration("payloads")),
            (
                "no delegation off Ethereum",
                KeyRegistrationFixture.previewQuote(payloads: [KeyRegistrationFixture.executePayload(KeyRegistrationFixture.typedData())]),
                .malformedKeyRegistration("payloads")
            ),
            (
                "paid from another Ethereum address",
                KeyRegistrationFixture.ethereumPreviewQuote(sender: other),
                .malformedKeyRegistration("preview for an Ethereum source")
            ),
            ("a quote to send", KeyRegistrationFixture.previewQuote(preview: false), .unexpectedPreview(false)),
        ]
        for (name, quote, expected) in cases {
            XCTAssertThrowsError(try readPreview(quote), name) {
                XCTAssertEqual($0 as? PerpsDepositQuoteError, expected, name)
            }
        }
    }

    // MARK: - Signatures

    /// The signed payloads go back as ChainKit wrote them, fields this client does not read
    /// included, plus the `version` ChainKit leaves out.
    func testTheSignedOperationGoesBackAsChainKitWroteIt() throws {
        let preview = try readPreview(KeyRegistrationFixture.previewQuote())
        let signed = KeyRegistrationFixture.signed()

        let operation = try preview.signedOperation(signed)

        XCTAssertEqual(operation.id, "op-auth")
        let sent = try operation.payloads.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) as? NSDictionary }
        let written = try ["p_auth", "p_execute"].map { id -> NSDictionary in
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(XCTUnwrap(signed[id]).utf8), options: .mutableContainers) as? NSMutableDictionary
            )
            payload["version"] = 1
            return payload
        }
        XCTAssertEqual(sent, written)
    }

    /// The shape `signedOperation` reads is ChainKit's, not the backend's: sign a preview with
    /// the real delegates and check it is the signed-payload format the backend takes.
    func testChainKitSignaturesOfAPreviewAreReadBack() async throws {
        let owner = "0x9858effd232b4033e47d90003d41ec34ecaeda94"
        var quote = KeyRegistrationFixture.previewQuote(typedData: KeyRegistrationFixture.typedData(owner: owner))
        quote.input.address = owner
        quote.output.address = owner
        let preview = try PerpsDepositQuoteReader.readPreview(
            quote,
            request: .init(
                source_asset: quote.input.asset_id,
                source_amount: quote.input.amount,
                sender_address: owner,
                destination_address: owner
            ),
            registration: KeyRegistrationFixture.registration,
            now: KeyRegistrationFixture.now
        )
        let chain = MultichainChain.eth.asChainKitChain
        let account = try ChainKit.Account(
            address: XCTUnwrap(Address.Companion.shared.from(value: owner, chain: chain, type: .default_)),
            asset: chain.toAsset(),
            derivation: DerivationDefaultPath.shared,
            publicKey: nil
        )
        let client = CryptoKitClient(netModule: ModuleNetModule(netConfig: ModuleNetConfig(
            isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil
        )))
        let wallet = try CryptoWallet.Companion.shared.fromMnemonic(
            mnemonic_: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )

        let signed = try await ChainKitOperationSender(client: client).signDocuments(preview.operation.parsed(), account: account, wallet: wallet)
        let operation = try preview.signedOperation(signed)

        XCTAssertEqual(operation.id, preview.operation.id)
        let payloads = try operation.payloads.map {
            try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode($0)) as? [String: Any])
        }
        XCTAssertEqual(payloads.map { $0["type"] as? String }, ["eip7702/authorization/signed", "eip7821/hermes/delegate/signed"])
        XCTAssertEqual(payloads.map { $0["payload_id"] as? String }, ["p_auth", "p_execute"])
        XCTAssertEqual(payloads.map { $0["chain_id"] as? String }, ["eth/mainnet", "eth/mainnet"])
        XCTAssertEqual(payloads.map { $0["version"] as? Int }, [1, 1])
        let signature = try XCTUnwrap((payloads[1]["meta"] as? [String: Any])?["data"] as? String)
        XCTAssertTrue(signature.hasSuffix("1b") || signature.hasSuffix("1c"), signature)
    }

    func testAMalformedSignatureIsNotSent() throws {
        let preview = try readPreview(KeyRegistrationFixture.previewQuote())
        let cases: [(String, [String: String], PerpsDepositQuoteError)] = [
            ("y_parity", KeyRegistrationFixture.signed(yParity: 2), .malformedKeyRegistration("authorization signature")),
            ("short r", KeyRegistrationFixture.signed(r: "0x" + String(repeating: "a", count: 62)), .malformedKeyRegistration("authorization signature")),
            ("another id", KeyRegistrationFixture.signed(authorizationId: "p_other"), .malformedKeyRegistration("authorization signature")),
            ("not json", KeyRegistrationFixture.signed().merging(["p_auth": "{"]) { $1 }, .malformedKeyRegistration("authorization signature")),
            (
                "no payload id",
                KeyRegistrationFixture.signed().merging(["p_auth": #"{"id":"p_auth","meta":{"data":{"y_parity":1,"r":"\#(KeyRegistrationFixture.r)","s":"\#(KeyRegistrationFixture.s)"}}}"#]) { $1 },
                .malformedKeyRegistration("authorization signature")
            ),
            (
                "no execute payload id",
                KeyRegistrationFixture.signed().merging(["p_execute": #"{"meta":{"data":"\#(KeyRegistrationFixture.signature)"}}"#]) { $1 },
                .malformedKeyRegistration("execute signature")
            ),
            ("short signature", KeyRegistrationFixture.signed(signature: "0x1b"), .malformedKeyRegistration("execute signature")),
            ("no signature", KeyRegistrationFixture.signed().filter { $0.key != "p_execute" }, .malformedKeyRegistration("execute signature")),
        ]
        for (name, signed, expected) in cases {
            XCTAssertThrowsError(try preview.signedOperation(signed), name) {
                XCTAssertEqual($0 as? PerpsDepositQuoteError, expected, name)
            }
        }
    }

    // MARK: - Deposit

    func testAFirstDepositSignsTheRegistrationAndSendsTheQuoteSignedFor() async throws {
        let delivery = StubDepositDelivery()
        let api = Self.api(plain: Self.uninitialized(KeyRegistrationFixture.bscRelayQuote()), registering: KeyRegistrationFixture.previewQuote(outputUnits: "2490000"))
        let service = makeService(api: api, delivery: delivery)

        let review = try await review(service)
        guard case .registering = review.payment else { return XCTFail("\(review.payment)") }
        XCTAssertEqual(review.delegatedChains, [.eth])
        XCTAssertEqual(review.creditedAmount, "2.49")
        XCTAssertEqual(review.networkFee, "0.000042")

        let outcome = try await service.pay(review: review, passcode: "0000")

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let events = await delivery.session.events
        XCTAssertEqual(events, ["sign:p_auth,p_execute", "send:p_approve,p_relay"])
        let requests = await api.quoteDepositRequests
        XCTAssertEqual(requests.map(\.change_pub_key), [
            KeyRegistrationFixture.registration.request(),
            nil,
            KeyRegistrationFixture.registration.request(),
        ])
        XCTAssertEqual(requests.map(\.operation), try [
            nil,
            nil,
            readPreview(KeyRegistrationFixture.previewQuote()).signedOperation(KeyRegistrationFixture.signed()),
        ])
    }

    func testAKeyRegisteredWhileThePreviewIsOpenStillSignsAndNamesTheKey() async throws {
        let delivery = StubDepositDelivery()
        let api = Self.api(plain: Self.uninitialized(KeyRegistrationFixture.bscRelayQuote()), registering: KeyRegistrationFixture.previewQuote())
        let service = makeService(api: api, delivery: delivery)
        let review = try await review(service)
        await api.setAccountResult(.success(.init(
            account_index: 42,
            api_keys: [.init(api_key_index: 3, public_key: KeyRegistrationFixture.publicKey.uppercased())]
        )))

        _ = try await service.pay(review: review, passcode: "0000")

        let requests = await api.quoteDepositRequests
        XCTAssertEqual(requests.last?.change_pub_key, KeyRegistrationFixture.registration.request())
        XCTAssertNotNil(requests.last?.operation)
        let events = await delivery.session.events
        XCTAssertEqual(events, ["sign:p_auth,p_execute", "send:p_approve,p_relay"])
    }

    func testAuthorizingAPreviewDoesNotReadTheAccount() async throws {
        let delivery = StubDepositDelivery()
        let api = Self.api(plain: Self.uninitialized(KeyRegistrationFixture.bscRelayQuote()), registering: KeyRegistrationFixture.previewQuote())
        let service = makeService(api: api, delivery: delivery)
        let review = try await review(service)
        await api.setAccountResult(.failure(.transport(underlying: nil)))

        _ = try await service.pay(review: review, passcode: "0000")
        let events = await delivery.session.events
        XCTAssertEqual(events, ["sign:p_auth,p_execute", "send:p_approve,p_relay"])
        let requests = await api.quoteDepositRequests
        XCTAssertEqual(requests.count, 3)
    }

    func testAPreviewCancelledDuringUnlockIsNeverSigned() async throws {
        let delivery = StubDepositDelivery()
        delivery.onOpenSession = { withUnsafeCurrentTask { $0?.cancel() } }
        let api = Self.api(plain: KeyRegistrationFixture.bscRelayQuote(), registering: KeyRegistrationFixture.previewQuote())
        let service = makeService(api: api, delivery: delivery)
        let reviewed = try await review(service)

        let payment = Task { try await service.pay(review: reviewed, passcode: "0000") }
        guard case let .failure(error) = await payment.result else { return XCTFail("paid after cancellation") }

        XCTAssertTrue(error is CancellationError)
        let events = await delivery.session.events
        XCTAssertTrue(events.isEmpty)
        let requests = await api.quoteDepositRequests
        XCTAssertEqual(requests.count, 2)
    }

    /// A new quote would be another payment beside the one the first confirmation left unsent.
    func testConfirmingAFirstDepositAgainFinishesThePaymentItStarted() async throws {
        let delivery = StubDepositDelivery()
        await delivery.session.failSend(ChainKitOperationError.insufficientFunds(payloadId: "p_relay"))
        let api = Self.api(plain: Self.uninitialized(KeyRegistrationFixture.bscRelayQuote()), registering: KeyRegistrationFixture.previewQuote(outputUnits: "2490000"))
        let service = makeService(api: api, delivery: delivery)
        let review = try await review(service)

        do {
            _ = try await service.pay(review: review, passcode: "0000")
            XCTFail("paid")
        } catch {
            XCTAssertEqual(PerpsDepositService.message(for: error), .insufficientNetworkFee(symbol: "BNB"))
        }
        await delivery.session.failSend(nil)
        let outcome = try await service.pay(review: review, passcode: "0000")

        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        let signatures = await delivery.session.signatures
        XCTAssertEqual(signatures, ["p_approve", "p_relay"])
        let requests = await api.quoteDepositRequests
        XCTAssertEqual(requests.count, 3)
    }

    func testARegistrationRepricedPastItsPreviewAsksForANewQuoteWithoutSending() async throws {
        let delivery = StubDepositDelivery()
        let api = Self.api(plain: Self.uninitialized(KeyRegistrationFixture.bscRelayQuote()), registering: KeyRegistrationFixture.previewQuote(outputUnits: "2530000"))
        let service = makeService(api: api, delivery: delivery)

        do {
            _ = try await service.pay(review: review(service), passcode: "0000")
            XCTFail("expected the repriced quote to be refused")
        } catch {
            XCTAssertEqual(error as? PerpsDepositServiceError, .registrationRepriced(quoted: "2500000", previewed: "2530000"))
            XCTAssertEqual(PerpsDepositService.message(for: error), .quoteExpired)
        }
        let events = await delivery.session.events
        XCTAssertEqual(events, ["sign:p_auth,p_execute"])
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
    }

    func testASignedPreviewAnsweredWithAnotherPreviewIsNeverSent() async throws {
        let delivery = StubDepositDelivery()
        let api = FundingStubAPI(quoteDepositHandler: { request in
            request.change_pub_key == nil ? KeyRegistrationFixture.bscRelayQuote() : KeyRegistrationFixture.previewQuote()
        })
        let service = makeService(api: api, delivery: delivery)
        let reviewed = try await review(service)

        do {
            _ = try await service.pay(review: reviewed, passcode: "0000")
            XCTFail("sent another preview")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .unexpectedPreview(true))
        }
        let events = await delivery.session.events
        XCTAssertEqual(events, ["sign:p_auth,p_execute"])
        let stored = try await journal().allFunding()
        XCTAssertTrue(stored.isEmpty)
    }

    func testTheBackendDecidesToRegisterTheKeyRegardlessOfAccountInitialization() async throws {
        let cases: [Bool?] = [true, false, nil]
        for uninitialized in cases {
            var plain = KeyRegistrationFixture.bscRelayQuote()
            plain.account_uninitialized = uninitialized
            var preview = KeyRegistrationFixture.previewQuote()
            preview.account_uninitialized = uninitialized
            let api = Self.api(plain: plain, registering: preview)
            let service = makeService(api: api)

            let review = try await review(service)

            guard case .registering = review.payment else { return XCTFail("\(review.payment)") }
            let requests = await api.quoteDepositRequests
            XCTAssertEqual(requests.count, 2)
            XCTAssertEqual(requests.first?.change_pub_key, KeyRegistrationFixture.registration.request())
            XCTAssertNil(requests.last?.change_pub_key)
        }
    }

    func testAKeyTheBackendAlreadyHoldsIsNamedAndTheDepositIsUsedAsIs() async throws {
        let api = FundingStubAPI(quoteDeposit: .success(KeyRegistrationFixture.bscRelayQuote()))
        let service = makeService(api: api)

        let review = try await review(service)

        guard case .quoted = review.payment else { return XCTFail("\(review.payment)") }
        XCTAssertEqual(review.delegatedChains, [])
        let requests = await api.quoteDepositRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.change_pub_key, KeyRegistrationFixture.registration.request())
    }

    func testAFeeOnlyReviewDoesNotAskToRegisterTheKey() async throws {
        let api = Self.api(plain: KeyRegistrationFixture.bscRelayQuote(), registering: KeyRegistrationFixture.previewQuote())

        let review = try await review(makeService(api: api), registeringKey: false)

        guard case let .quoted(quote) = review.payment else { return XCTFail("\(review.payment)") }
        XCTAssertNil(quote.registration)
        let requests = await api.quoteDepositRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertNil(requests.first?.change_pub_key)
    }

    func testAReviewWithoutAKeptKeyDoesNotQuoteOrUnlock() async throws {
        let api = FundingStubAPI(quoteDeposit: .success(KeyRegistrationFixture.bscRelayQuote()))
        let delivery = StubDepositDelivery()

        do {
            _ = try await review(makeService(api: api, delivery: delivery, keyRegistration: nil))
            XCTFail("quoted without a trading key")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .malformedKeyRegistration("trading key unavailable"))
        }
        let requests = await api.quoteDepositRequests
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(delivery.openedSessionCount, 0)
    }

    func testARegistrationThatCannotBeQuotedDoesNotFallBackToAPlainDeposit() async throws {
        let refusals: [(String, Result<Components.Schemas.DepositQuote, PerpsAPIError>)] = [
            ("another delegate", .success(KeyRegistrationFixture.previewQuote(delegate: "0x00000000000000000000000000000000000000aa"))),
            ("refused", .failure(PaymentFixture.accountCreationPending)),
        ]
        for (name, registering) in refusals {
            let api = Self.api(plain: Self.uninitialized(KeyRegistrationFixture.bscRelayQuote()), registering: registering)
            let service = makeService(api: api)

            do {
                _ = try await review(service)
                XCTFail(name)
            } catch {
                if case .failure = registering {
                    XCTAssertEqual((error as? PerpsAPIError)?.isAccountCreationPending, true, name)
                } else {
                    XCTAssertEqual(error as? PerpsDepositQuoteError, .malformedKeyRegistration("authorization"), name)
                }
            }
            let requests = await api.quoteDepositRequests
            XCTAssertEqual(requests.count, 1, name)
        }
    }

    func testAFirstEthereumDepositShowsQuotedPayloadFeesBeforeUnlocking() async throws {
        let value = Components.Schemas.PayloadFee.value(.init(
            _type: .value, asset_id: "eth/mainnet/coin", data: .init(amount: "42000000000000")
        ))
        let gas = Components.Schemas.PayloadFee.gas(.init(
            _type: .gas, asset_id: "eth/mainnet/coin", data: .init(limit: "40000", price: "1000000000")
        ))
        let eip1559 = Components.Schemas.PayloadFee.eip1559(.init(
            _type: .eip1559, asset_id: "eth/mainnet/coin",
            data: .init(limit: "100000", max_fee_per_gas: "2000000000", max_priority_fee_per_gas: "1000000000")
        ))
        let zero = Components.Schemas.PayloadFee.value(.init(
            _type: .value, asset_id: "eth/mainnet/coin", data: .init(amount: "0")
        ))
        let otherAsset = Components.Schemas.PayloadFee.value(.init(
            _type: .value, asset_id: "bsc/mainnet/coin", data: .init(amount: "42000000000000")
        ))
        let cases: [(String, Components.Schemas.PayloadFee?, Components.Schemas.PayloadFee?, String?)] = [
            ("flat fees", value, value, "0.000084"),
            ("both", gas, eip1559, "0.00024"),
            ("unpriced approval", nil, eip1559, nil),
            ("unpriced payment", gas, nil, nil),
            ("no fees", nil, nil, nil),
            ("zero fees", zero, zero, "0"),
            ("another fee asset", otherAsset, otherAsset, "0"),
            ("only native fee", gas, otherAsset, "0.00004"),
        ]
        for (name, approvalFee, paymentFee, expected) in cases {
            var approval = Components.Schemas.QuotePayload.evm(
                "p_approve",
                to: PaymentFixture.usdt,
                data: HermesBatchFixture.approve(spender: PaymentFixture.relayRouter, amountUnits: "25000000")
            )
            var payment = Components.Schemas.QuotePayload.evm("p_relay", to: PaymentFixture.relayRouter, data: "0xdeadbeef")
            approval.setFee(approvalFee)
            payment.setFee(paymentFee)
            let plain = Self.uninitialized(PaymentFixture.crosschainQuote(
                asset: PaymentFixture.usdtAsset, amount: "25000000", payloads: [approval, payment]
            ))
            let delivery = StubDepositDelivery()
            let service = makeService(
                api: Self.api(plain: plain, registering: KeyRegistrationFixture.ethereumPreviewQuote()),
                delivery: delivery
            )

            let reviewed = try await review(service, asset: PaymentFixture.usdtFundingAsset, amount: "25")

            guard case .registering = reviewed.payment else { return XCTFail(name) }
            XCTAssertEqual(reviewed.networkFee, expected, name)
            XCTAssertEqual(reviewed.networkFeeSymbol, "ETH", name)
            XCTAssertTrue(delivery.pricedOperations.isEmpty, name)
            XCTAssertEqual(delivery.openedSessionCount, 0, name)
        }
    }

    /// A delegation signed ahead would be for the nonce the payment spends, so the payment carries it.
    func testAFirstDepositFromEthereumThroughAnAggregatorDelegatesInItsPayment() async throws {
        let delivery = StubDepositDelivery()
        let plain = Self.uninitialized(PaymentFixture.approvedRelayQuote())
        let preview = KeyRegistrationFixture.ethereumPreviewQuote()
        let delegated = PaymentFixture.crosschainQuote(asset: PaymentFixture.usdtAsset, amount: "25000000", payloads: [
            .evm("p_relay", to: PaymentFixture.relayRouter, data: "0xdeadbeef", authorization: HermesBatchFixture.authorization()),
        ])
        let api = FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDepositHandler: { request in
                guard request.change_pub_key != nil else { return plain }
                return request.operation == nil ? preview : delegated
            }
        )
        let service = makeService(api: api, delivery: delivery)

        let review = try await review(service, asset: PaymentFixture.usdtFundingAsset, amount: "25")
        guard case .registering = review.payment else { return XCTFail("\(review.payment)") }
        XCTAssertEqual(review.delegatedChains, [.eth])
        XCTAssertNil(review.networkFee)
        XCTAssertTrue(delivery.pricedOperations.isEmpty)
        delivery.feeUnits = 84_000_000_000_000
        let pendingJournal = journal()
        let feeChecked = expectation(description: "final fee checked before payment")
        let outcome = try await service.pay(review: review, passcode: "0000") { fee in
            XCTAssertEqual(fee, "0.000084")
            let events = await delivery.session.events
            XCTAssertEqual(events, ["sign:p_execute"])
            let pending = try await pendingJournal.allFunding()
            XCTAssertTrue(pending.isEmpty)
            feeChecked.fulfill()
        }

        await fulfillment(of: [feeChecked], timeout: 1)
        XCTAssertEqual(outcome, .registered(operationId: "op-1"))
        XCTAssertEqual(delivery.openedSessionCount, 1)
        XCTAssertEqual(delivery.pricedOperations.count, 1)
        let priced = try XCTUnwrap(delivery.pricedOperations.first)
        XCTAssertNotNil(try (priced.parsed().payloads.first?.meta as? PayloadMetaEvmMain)?.authorization)
        let events = await delivery.session.events
        XCTAssertEqual(events, ["sign:p_execute", "send:p_relay"])
        let requests = await api.quoteDepositRequests
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests.last?.operation?.payloads.count, 1)
    }

    func testAnEthereumRegistrationIsNotSentWhenItsFeeCannotBePaid() async throws {
        let delivery = StubDepositDelivery()
        let delegated = PaymentFixture.crosschainQuote(asset: PaymentFixture.usdtAsset, amount: "25000000", payloads: [
            .evm("p_relay", to: PaymentFixture.relayRouter, data: "0xdeadbeef", authorization: HermesBatchFixture.authorization()),
        ])
        let plain = Self.uninitialized(PaymentFixture.approvedRelayQuote())
        let api = FundingStubAPI(quoteDepositHandler: { request in
            guard request.change_pub_key != nil else { return plain }
            return request.operation == nil ? KeyRegistrationFixture.ethereumPreviewQuote() : delegated
        })
        let service = makeService(api: api, delivery: delivery)
        let review = try await review(service, asset: PaymentFixture.usdtFundingAsset, amount: "25")
        delivery.feeUnits = nil
        do {
            _ = try await service.pay(review: review, passcode: "0000")
            XCTFail("an unpriced registration payment must not be sent")
        } catch {
            guard case ChainKitOperationError.feeUnavailable = error else { return XCTFail("\(error)") }
        }
        delivery.feeUnits = 84_000_000_000_000
        do {
            _ = try await service.pay(review: review, passcode: "0000") { fee in
                XCTAssertEqual(fee, "0.000084")
                throw ChainKitOperationError.insufficientFunds(payloadId: "p_relay")
            }
            XCTFail("a registration payment must not be sent when the balance cannot cover its fee")
        } catch {
            XCTAssertEqual(error as? ChainKitOperationError, .insufficientFunds(payloadId: "p_relay"))
        }
        let events = await delivery.session.events
        XCTAssertEqual(events, ["sign:p_execute"])
        let pending = try await journal().allFunding()
        XCTAssertTrue(pending.isEmpty)
        let requests = await api.quoteDepositRequests
        XCTAssertEqual(requests.count, 3)
    }

    func testARegistrationFromAnotherEthereumAddressIsAskedForAndAnUnsafePreviewIsRejected() async throws {
        let other = "0x00000000000000000000000000000000000000aa"
        let plain = PaymentFixture.crosschainQuote(asset: PaymentFixture.usdtAsset, amount: "25000000", sender: other, payloads: [
            .evm("p_relay", to: PaymentFixture.relayRouter, data: "0xdeadbeef"),
        ])
        let api = Self.api(plain: Self.uninitialized(plain), registering: KeyRegistrationFixture.ethereumPreviewQuote(sender: other))
        let service = makeService(api: api)

        do {
            _ = try await service.review(
                sourceAsset: PaymentFixture.usdtFundingAsset,
                amount: "25",
                senderAddress: other,
                beneficiary: PaymentFixture.sender
            )
            XCTFail("accepted a preview for another Ethereum address")
        } catch {
            XCTAssertEqual(error as? PerpsDepositQuoteError, .malformedKeyRegistration("preview for an Ethereum source"))
        }
        let requests = await api.quoteDepositRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.change_pub_key, KeyRegistrationFixture.registration.request())
    }

    func testTheDelegationIsNamedOnEveryChainItIsSignedFor() async throws {
        let folded = FundingStubAPI(quoteDeposit: .success(KeyRegistrationFixture.bscFoldedQuote()))
        let registering = Self.api(plain: Self.uninitialized(KeyRegistrationFixture.bscFoldedQuote()), registering: KeyRegistrationFixture.previewQuote())

        let foldedReview = try await review(makeService(api: folded))
        let registeringReview = try await review(makeService(api: registering))

        XCTAssertEqual(foldedReview.delegatedChains, [.bsc])
        XCTAssertEqual(registeringReview.delegatedChains, [.eth, .bsc])
    }

    func testADirectFirstDepositRegistersTheKeyAsTheThirdCallOfItsBatch() async throws {
        let delivery = StubDepositDelivery()
        let api = Self.api(plain: Self.uninitialized(PaymentFixture.directQuote()), registering: Self.directBatch(registering: KeyRegistrationFixture.registration))
        let service = makeService(api: api, delivery: delivery)

        let review = try await review(service, asset: PerpsDepositService.targetAsset, amount: "2.5")
        guard case let .quoted(quote) = review.payment else { return XCTFail("\(review.payment)") }
        XCTAssertEqual(quote.registration, KeyRegistrationFixture.registration)
        XCTAssertEqual(quote.payloads.map(\.payloadId), ["p_batch"])
        _ = try await service.pay(review: review, passcode: "0000")

        let events = await delivery.session.events
        XCTAssertEqual(events, ["send:p_batch"])
    }

    func testADirectDepositWithoutRegistrationIsUsedWhenTheBackendAlreadyHoldsTheKey() async throws {
        let cases = [
            (PaymentFixture.directQuote(), ["p_approve", "p_gateway"]),
            (PaymentFixture.directQuote(withApproval: false), ["p_gateway"]),
            (PaymentFixture.foldedQuote(), ["p_batch"]),
        ]
        for (quoted, payloadIds) in cases {
            let api = FundingStubAPI(quoteDeposit: .success(quoted))
            let service = makeService(api: api)

            let review = try await review(service, asset: PerpsDepositService.targetAsset, amount: "2.5")

            guard case let .quoted(quote) = review.payment else { return XCTFail("\(review.payment)") }
            XCTAssertNil(quote.registration)
            XCTAssertEqual(quote.payloads.map(\.payloadId), payloadIds)
            let requests = await api.quoteDepositRequests
            XCTAssertEqual(requests.count, 1)
            XCTAssertEqual(requests.first?.change_pub_key, KeyRegistrationFixture.registration.request())
        }
    }

    func testADirectBatchRegisteringAnotherKeyIsRejectedWithoutFallback() async throws {
        let otherKey = try XCTUnwrap(PerpsKeyRegistration(apiKeyIndex: 3, publicKey: "0x" + String(repeating: "1", count: 80)))
        let api = Self.api(plain: PaymentFixture.directQuote(), registering: Self.directBatch(registering: otherKey))
        let service = makeService(api: api)

        do {
            _ = try await review(service, asset: PerpsDepositService.targetAsset, amount: "2.5")
            XCTFail("accepted another trading key")
        } catch {
            XCTAssertEqual(error as? PerpsDepositCalldataError, .unsafeKeyRegistration(payloadId: "p_batch"))
        }
        let requests = await api.quoteDepositRequests
        XCTAssertEqual(requests.count, 1)
    }

    // MARK: - Helpers

    private func readPreview(_ quote: Components.Schemas.DepositQuote) throws -> PerpsKeyRegistrationPreview {
        try PerpsDepositQuoteReader.readPreview(
            quote,
            request: .init(
                source_asset: quote.input.asset_id,
                source_amount: quote.input.amount,
                sender_address: quote.input.address,
                destination_address: PaymentFixture.sender,
                change_pub_key: KeyRegistrationFixture.registration.request()
            ),
            registration: KeyRegistrationFixture.registration,
            now: KeyRegistrationFixture.now
        )
    }

    private static func uninitialized(_ quote: Components.Schemas.DepositQuote) -> Components.Schemas.DepositQuote {
        var quote = quote
        quote.account_uninitialized = true
        return quote
    }

    /// The direct deposit folded into one self-call with `changePubKey` after it.
    private static func directBatch(registering registration: PerpsKeyRegistration) -> Components.Schemas.DepositQuote {
        var quote = PaymentFixture.foldedQuote()
        let token = PerpsFundingAssetId.usdcEthereum.replacingOccurrences(of: "eth/mainnet/erc20/", with: "")
        quote.operation = .transfer([.evm(
            "p_batch",
            to: PaymentFixture.sender,
            data: HermesBatchFixture.execute([
                (token, HermesBatchFixture.approve(spender: PaymentFixture.gateway, amountUnits: "2500000")),
                (PaymentFixture.gateway, PaymentFixture.depositCalldata(amountUnits: "2500000")),
                (PaymentFixture.gateway, registration.calldata),
            ]),
            gas: "260000",
            authorization: HermesBatchFixture.authorization()
        )])
        return quote
    }

    private static func api(
        plain: Components.Schemas.DepositQuote,
        registering: Components.Schemas.DepositQuote
    ) -> FundingStubAPI {
        api(plain: plain, registering: .success(registering))
    }

    /// Answers the plain quote, the registration asked unsigned, and the registration signed as
    /// the plain quote it then costs.
    private static func api(
        plain: Components.Schemas.DepositQuote,
        registering: Result<Components.Schemas.DepositQuote, PerpsAPIError>
    ) -> FundingStubAPI {
        FundingStubAPI(
            openDeposit: .success(.init(deposit_id: "deposit", status: .pending)),
            quoteDepositHandler: { request in
                guard request.change_pub_key != nil else { return plain }
                guard request.operation != nil else { return try registering.get() }
                var signed = plain
                signed.account_uninitialized = nil
                return signed
            }
        )
    }

    private func review(
        _ service: PerpsDepositService,
        asset: PerpsFundingAsset = KeyRegistrationFixture.bscAsset,
        amount: String = "25",
        registeringKey: Bool = true
    ) async throws -> PerpsDepositReview {
        try await service.review(
            sourceAsset: asset,
            amount: amount,
            senderAddress: PaymentFixture.sender,
            beneficiary: PaymentFixture.sender,
            registeringKey: registeringKey
        )
    }

    private func journal() -> PerpsPendingJournal {
        PerpsPendingJournal(walletId: "wallet", environment: "test", directoryURL: directoryURL)
    }

    private func makeService(
        api: FundingStubAPI,
        delivery: StubDepositDelivery = StubDepositDelivery(),
        keyRegistration: PerpsKeyRegistration? = KeyRegistrationFixture.registration
    ) -> PerpsDepositService {
        PerpsDepositService(
            walletId: "multichain-wallet",
            walletIdentity: "wallet",
            environment: "mainnet",
            journal: journal(),
            api: api,
            delivery: delivery,
            recovery: nil,
            keyRegistration: { keyRegistration },
            now: { KeyRegistrationFixture.now },
            makeOperationId: { "op-1" }
        )
    }
}

enum KeyRegistrationFixture {
    static let now = Date(timeIntervalSince1970: 1_700_000_000)
    static let publicKey = "0x520d548cab0dc20d5970fe48eac6b1ab5b9a3f1581a7f50fa78e8149d38d5eb2d76784210ab3c083"
    // swiftlint:disable:next force_unwrapping
    static let registration = PerpsKeyRegistration(apiKeyIndex: 3, publicKey: publicKey)!
    static let r = "0x" + String(repeating: "a", count: 64)
    static let s = "0x" + String(repeating: "b", count: 64)
    static let signature = "0x" + String(repeating: "c", count: 128) + "1b"

    static let executeTypes: [String: [Components.Schemas.EIP712TypeField]] = [
        "Execute": [
            .init(name: "mode", _type: "bytes32"),
            .init(name: "calls", _type: "Call[]"),
            .init(name: "nonce", _type: "uint256"),
            .init(name: "deadline", _type: "uint256"),
        ],
        "Call": [
            .init(name: "target", _type: "address"),
            .init(name: "value", _type: "uint256"),
            .init(name: "data", _type: "bytes"),
        ],
    ]
    static let domainType: [Components.Schemas.EIP712TypeField] = [
        .init(name: "name", _type: "string"),
        .init(name: "version", _type: "string"),
        .init(name: "chainId", _type: "uint256"),
        .init(name: "verifyingContract", _type: "address"),
        .init(name: "salt", _type: "bytes32"),
    ]

    static func typedData(
        owner: String = PaymentFixture.sender,
        salt: String = "0x" + String(repeating: "0", count: 24) + PerpsDepositCalldata.hermesDelegate.dropFirst(2),
        mode: String = PerpsDepositQuoteReader.signedBatchMode,
        calls: [Components.Schemas.HermesExecuteCall] = [.init(target: PerpsDepositCalldata.gatewayAddress, value: "0", data: KeyRegistrationFixture.registration.calldata)],
        types: [String: [Components.Schemas.EIP712TypeField]] = KeyRegistrationFixture.executeTypes,
        deadline: Int64 = 1_700_000_600
    ) -> Components.Schemas.HermesExecuteTypedData {
        .init(
            types: .init(additionalProperties: types),
            primaryType: "Execute",
            domain: .init(name: "Hermes", version: "v1.0.0", chainId: 1, verifyingContract: owner, salt: salt),
            message: .init(mode: mode, calls: calls, nonce: "5", deadline: "\(deadline)")
        )
    }

    static let bscToken = "0x55d398326f99059ff775485246999027b3197955"
    static let bscAsset = PerpsFundingAsset(assetId: "bsc/mainnet/bep20/\(bscToken)", symbol: "USDT", decimals: 18)
    static let bscAmountUnits = "25000000000000000000"

    /// An aggregator route off Ethereum, where paying leaves the Ethereum nonce alone.
    static func bscRelayQuote() -> Components.Schemas.DepositQuote {
        PaymentFixture.crosschainQuote(asset: bscAsset.assetId, amount: bscAmountUnits, payloads: [
            .evm("p_approve", chain: "bsc/mainnet", to: bscToken, data: HermesBatchFixture.approve(spender: PaymentFixture.relayRouter, amountUnits: bscAmountUnits)),
            .evm("p_relay", chain: "bsc/mainnet", to: PaymentFixture.relayRouter, data: "0xdeadbeef"),
        ])
    }

    /// The same route folded into one self-call, which delegates the BSC address.
    static func bscFoldedQuote() -> Components.Schemas.DepositQuote {
        PaymentFixture.crosschainQuote(asset: bscAsset.assetId, amount: bscAmountUnits, payloads: [.evm(
            "p_batch",
            chain: "bsc/mainnet",
            to: PaymentFixture.sender,
            data: HermesBatchFixture.execute([
                (bscToken, HermesBatchFixture.approve(spender: PaymentFixture.relayRouter, amountUnits: bscAmountUnits)),
                (PaymentFixture.relayRouter, "0xdeadbeef"),
            ]),
            authorization: .init(chainId: 56, address: PerpsDepositCalldata.hermesDelegate, nonce: 25)
        )])
    }

    static func authorizationPayload(
        delegate: String = PerpsDepositCalldata.hermesDelegate,
        chainId: Int64 = 1
    ) -> Components.Schemas.QuotePayload {
        .payload("p_auth", type: "eip7702/authorization", chain: "eth/mainnet", meta: Components.Schemas.PayloadMetaEip7702Authorization(chainId: chainId, address: delegate, nonce: 7))
    }

    static func executePayload(_ typedData: Components.Schemas.HermesExecuteTypedData) -> Components.Schemas.QuotePayload {
        .payload("p_execute", type: "eip7821/hermes/delegate", chain: "eth/mainnet", meta: Components.Schemas.PayloadMetaHermesDelegate(data: typedData))
    }

    /// The aggregator's answer to a registration asked without signatures.
    static func previewQuote(
        base: Components.Schemas.DepositQuote = KeyRegistrationFixture.bscRelayQuote(),
        preview: Bool = true,
        outputUnits: String = "2500000",
        delegate: String = PerpsDepositCalldata.hermesDelegate,
        delegationChainId: Int64 = 1,
        typedData: Components.Schemas.HermesExecuteTypedData = KeyRegistrationFixture.typedData(),
        payloads: [Components.Schemas.QuotePayload]? = nil
    ) -> Components.Schemas.DepositQuote {
        var quote = base
        quote.output.amount = outputUnits
        quote.output.min_amount = outputUnits
        quote.account_uninitialized = true
        quote.operation = .transfer(id: "op-auth", payloads ?? [
            authorizationPayload(delegate: delegate, chainId: delegationChainId),
            executePayload(typedData),
        ])
        quote.preview = preview
        return quote
    }

    /// The same answer for an aggregator route paid from Ethereum: `Execute` alone.
    static func ethereumPreviewQuote(sender: String = PaymentFixture.sender) -> Components.Schemas.DepositQuote {
        previewQuote(
            base: PaymentFixture.crosschainQuote(asset: PaymentFixture.usdtAsset, amount: "25000000", sender: sender, payloads: []),
            payloads: [executePayload(typedData())]
        )
    }

    /// ChainKit's signed payloads, as `StubDepositSigningSession` writes them.
    static func signed(
        authorizationId: String = "p_auth",
        yParity: Int = 1,
        r: String = KeyRegistrationFixture.r,
        signature: String = KeyRegistrationFixture.signature
    ) -> [String: String] {
        [
            "p_auth": #"{"type":"eip7702/authorization/signed","chain_id":"eth/mainnet","payload_id":"\#(authorizationId)","meta":{"data":{"y_parity":\#(yParity),"r":"\#(r)","s":"\#(s)"}}}"#,
            "p_execute": #"{"type":"eip7821/hermes/delegate/signed","chain_id":"eth/mainnet","payload_id":"p_execute","meta":{"data":"\#(signature)"}}"#,
        ]
    }
}
