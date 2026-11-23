@preconcurrency import ChainKit
@testable import KeeperCore
@testable import KeeperCoreComponents
import KeeperCoreSensitive
import OperationReviewModels
import TKTestSupport
import TonSwift
import WalletCore
import WalletCoreSwiftProtobuf
import XCTest

/// A dApp's EVM transaction from a mnemonic, signed as the operation its review read while
/// `genericPayloadEnabled` is on: the gate clears that operation before the passcode, and it is
/// signed from the unlocked keys at the fee shown and at the dApp's nonce, broadcast while the dApp
/// still waits, recorded and answered with its hash. Every other request keeps its signer.
final class WalletConnectOperationSigningTests: XCTestCase {
    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let passcode = "1234"
    /// m/44'/60'/0'/0/0 of the phrase above, and the key its address stored.
    private static let sender = "0x9858effd232b4033e47d90003d41ec34ecaeda94"
    private static let storedKey = MultichainPublicKey(defaultHex: "0x0237b0bb7a8288d38ed49a524b5dc98cff3eb5ca824c9f9dc0dfdb3d9cd600f299", segWit: "")
    private static let recipient = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    private static let foreign = "0x00000000000000000000000000000000000000aa"
    private static let usdt = "0xdac17f958d2ee523a2206206994597c13d831ec7"
    private static let usdtAssetId = "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"
    /// `transfer(recipient, 1)` of an ERC-20 token.
    private static let tokenTransfer = "0xa9059cbb" + String(repeating: "0", count: 24) + recipient.dropFirst(2) + String(repeating: "0", count: 63) + "1"
    /// `approve(recipient, 2^256 - 1)`: a call that moves nothing yet.
    private static let approval = "0x095ea7b3" + String(repeating: "0", count: 24) + recipient.dropFirst(2) + String(repeating: "f", count: 64)
    private static let weth = "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"
    /// WETH's `deposit()`: a contract call paid for with the coin sent along.
    private static let deposit = "0xd0e30db0"
    /// m/44'/195'/0'/0/0 of the phrase above.
    private static let tronSender: String = {
        guard let wallet = try? CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic) else {
            return ""
        }
        return wallet.getAddress(chain: MultichainChain.tron.asChainKitChain, type: .default_).display
    }()

    private static let foreignTron = "TLsV52sRDL79HXGGm9yzwKibb6BeruhUzy"
    /// What chain-kit and the SDK's signer must sign alike: ASCII, Cyrillic, emoji, an empty text and a
    /// text that reads as hex.
    private static let tronMessages = ["hello", "Привет, мир", "gm 👋🏽🚀", "", "0x48656c6c6f"]
    /// What the confirmation showed: 21000 gas at up to 5 gwei.
    private static let shownFee = WalletConnectEVMFee(
        amount: 105_000_000_000_000,
        limit: 21000,
        price: .eip1559(networkPrice: 3_000_000_000, maxPrice: 5_000_000_000, minerPrice: 1_000_000_000)
    )

    private let taken = Taken()
    private let recorded = RecordedTransactions()
    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    func test_aTransactionIsSignedAsTheOperationTheUserAcceptedAtTheShownFeeAndTheDAppsNonce() async throws {
        let check = Verdict { ValidationError.UnlistedAsset(payloadId: $0.operation.id, asset: Self.usdtAssetId, amount: nil, to: nil, approved: false) }
        let user = ConsentingUser(answering: true) { [taken] in await taken.take("ask") }
        let service = try await service(checks: [check], sending: taken.sending())
        let request = request(transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a"))

        let response = try await service.sign(signer: mnemonic, wallet: wallet(), request: request, evmFee: Self.shownFee, consent: user.attempt(), isPending: { true })

        XCTAssertEqual(response, .string("0xsent"))
        let steps = await taken.steps
        XCTAssertEqual(steps, ["ask", "passcode", "send", "broadcast"])
        let reads = await check.reads.all
        let reviewed = try XCTUnwrap(reads.first)
        let handed = await taken.sent
        let sent = try XCTUnwrap(handed.first)
        XCTAssertEqual(reads.count, 1)
        XCTAssertTrue(sent.operation === reviewed.operation, "what is signed is the operation the user was asked about")
        XCTAssertEqual(reviewed.fidelity, .exact)
        XCTAssertEqual(reviewed.intent, .dapp)
        XCTAssertEqual(reviewed.operation.id, request.id)
        let main = try XCTUnwrap(sent.operation.payloads.first?.meta as? PayloadMetaEvmMain)
        XCTAssertEqual(main.to.display.lowercased(), Self.recipient)
        XCTAssertEqual(main.value.description, "1000")
        XCTAssertNil(main.data)
        XCTAssertNil(main.gas)
        XCTAssertEqual(sent.account.addressDisplay.lowercased(), Self.sender)
        XCTAssertEqual(sent.account.publicKey?.defaultHex, sent.wallet.getPublicKey(chain: sent.account.chain).defaultHex)
        XCTAssertEqual(try WalletConnectEVMFee(fee: XCTUnwrap(sent.fee)), Self.shownFee)
        XCTAssertEqual(sent.nonce?.description, "42")
        let asked = await user.asked
        XCTAssertEqual(asked.map(\.severity), [.warning])
        let transactions = await recorded.all
        XCTAssertEqual(transactions.map(\.txHash), ["0xsent"])
        XCTAssertEqual(transactions.map(\.chain), [.eth])
        XCTAssertEqual(transactions.map(\.activityType), [.send])
    }

    /// The sender then reads the account's next nonce from the node.
    func test_aTransactionNamingNoNonceIsSignedWithoutOne() async throws {
        let service = try await service(sending: taken.sending())

        _ = try await service.sign(
            signer: mnemonic,
            wallet: wallet(),
            request: request(transaction(to: Self.recipient, value: "0x3e8", nonce: nil)),
            evmFee: Self.shownFee,
            consent: .refuse,
            isPending: { true }
        )

        let handed = await taken.sent
        let sent = try XCTUnwrap(handed.first)
        XCTAssertNil(sent.nonce)
        XCTAssertEqual(try WalletConnectEVMFee(fee: XCTUnwrap(sent.fee)), Self.shownFee)
    }

    /// chain-kit signs the operation of a coin transfer, a token's transfer and a contract call into the
    /// very transaction the SDK's signing output carries for the request at the same fee and nonce.
    func test_aCoinTransferATokenTransferAndAContractCallAreEachSignedAsTheSDKSignsThem() async throws {
        let utilities = WalletConnectEVMTransactionSigningUtilities()
        let chain = WalletConnectChain.eth.multichainChain.asChainKitChain
        let mediator = client.blockchain.getMediator(network: chain.network.type)
        let service = try await service(sending: taken.sending())
        let transactions = [
            transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a"),
            transaction(to: Self.usdt, value: "0x0", data: Self.tokenTransfer, nonce: "0x2a"),
            transaction(to: Self.usdt, value: "0x0", data: Self.approval, nonce: "0x2a"),
        ]

        for transaction in transactions {
            _ = try await service.sign(signer: mnemonic, wallet: wallet(), request: request(transaction), evmFee: Self.shownFee, consent: .refuse, isPending: { true })
        }

        let sent = await taken.sent
        XCTAssertEqual(sent.count, transactions.count)
        for (sent, transaction) in zip(sent, transactions) {
            let label = transaction.data
            let payload = try XCTUnwrap(sent.operation.payloads.first, label)
            let main = try XCTUnwrap(payload.meta as? PayloadMetaEvmMain, label)
            XCTAssertEqual(main.to.display.lowercased(), transaction.to, label)
            let fee = try XCTUnwrap(sent.fee, label)
            let nonce = try XCTUnwrap(sent.nonce, label)
            let signed = try await mediator.operation.sign(payload: payload, account: sent.account, fee: fee, nonce: nonce, wallet: sent.wallet)
            let asOperation = try XCTUnwrap(signed.getOrNull(), label)
            let bySDK = try await utilities.signAndEncode(
                mediator: mediator,
                transaction: utilities.chainKitTransaction(account: sent.account, chain: .eth, payload: transaction),
                fee: fee,
                nonce: nonce,
                privateKey: sent.wallet.getPrivateKey(chain: chain)
            )
            let raw = try JSONDecoder().decode(String.self, from: Data(asOperation.data.description.utf8))
            let encoded = try EthereumSigningOutput(serializedBytes: bySDK.asData).encoded
            XCTAssertEqual(raw, "0x" + encoded.map { String(format: "%02x", $0) }.joined(), label)
        }
        let recordedTransactions = await recorded.all
        XCTAssertEqual(recordedTransactions.map(\.activityType), [.send, .send, .contractCall])
    }

    /// A dApp's warning is asked about as its danger is, before the passcode; a decline is the user's
    /// rejection and nothing is unlocked, signed or recorded.
    func test_whatChainKitFindsIsAskedBeforeThePasscodeAndADeclineSignsNothing() async throws {
        let verdicts: [(OperationFinding.Severity, @Sendable (SignableOperation) -> ValidationError)] = [
            (.warning, { ValidationError.UnlistedAsset(payloadId: $0.operation.id, asset: Self.usdtAssetId, amount: nil, to: nil, approved: false) }),
            (.danger, { ValidationError.ForeignRecipient(payloadId: $0.operation.id, expected: Self.recipient, actual: Self.foreign) }),
        ]
        for (severity, verdict) in verdicts {
            let taken = Taken()
            let user = ConsentingUser(answering: false) { await taken.take("ask") }
            let service = try await service(checks: [Verdict(error: verdict)], sending: taken.sending())

            let error = await signingError {
                try await service.sign(
                    signer: self.mnemonic(taken),
                    wallet: self.wallet(),
                    request: self.request(self.transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a")),
                    evmFee: Self.shownFee,
                    consent: user.attempt(),
                    isPending: { true }
                )
            }

            XCTAssertEqual(error, .canceled, "\(severity)")
            XCTAssertEqual(error?.walletConnectRequestRejectionReason, .userRejected, "\(severity)")
            let steps = await taken.steps
            XCTAssertEqual(steps, ["ask"], "\(severity)")
            let asked = await user.asked
            XCTAssertEqual(asked.map(\.severity), [severity])
        }
        let transactions = await recorded.all
        XCTAssertTrue(transactions.isEmpty)
    }

    /// Earn shows nothing it could ask about, so what chain-kit finds in the operation is only logged:
    /// the operation is signed at chain-kit's price, as the SDK prices Earn's transaction.
    func test_EarnSignsTheOperationWithoutAskingAtChainKitsPrice() async throws {
        let log = RecordedLog()
        defer { log.stop() }
        let check = Verdict { ValidationError.ForeignRecipient(payloadId: $0.operation.id, expected: Self.recipient, actual: Self.foreign) }
        let service = try await service(checks: [check], sending: taken.sending())

        let response = try await service.signWithoutAsking(
            signer: mnemonic,
            wallet: wallet(),
            request: request(transaction(to: Self.recipient, value: "0x3e8", nonce: nil), id: UUID().uuidString)
        )
        let unasked = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)

        XCTAssertEqual(response, .string("0xsent"))
        let steps = await taken.steps
        XCTAssertEqual(steps, ["passcode", "send", "broadcast"])
        let handed = await taken.sent
        let sent = try XCTUnwrap(handed.first)
        XCTAssertNil(sent.fee)
        XCTAssertNil(sent.nonce)
        XCTAssertEqual(unasked.first?.extraInfo["fidelity"], "exact")
        let reads = await check.reads.all
        XCTAssertTrue(reads.first?.operation === sent.operation)
        let transactions = await recorded.all
        XCTAssertEqual(transactions.map(\.txHash), ["0xsent"])
    }

    /// The checks can take seconds: the request is held to still be pending once they are done, so a
    /// request that ended meanwhile never asks for the passcode.
    func test_aRequestThatEndedWhileItWasReviewedIsNeverUnlocked() async throws {
        let pending = PendingRequest()
        let service = try await service(checks: [EndingCheck { await pending.end() }], sending: taken.sending())

        let error = await signingError {
            try await service.sign(
                signer: self.mnemonic,
                wallet: self.wallet(),
                request: self.request(self.transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a")),
                evmFee: Self.shownFee,
                consent: .refuse,
                isPending: { await pending.isPending }
            )
        }

        XCTAssertEqual(error, .canceled)
        let steps = await taken.steps
        XCTAssertTrue(steps.isEmpty)
        let transactions = await recorded.all
        XCTAssertTrue(transactions.isEmpty)
    }

    /// The request can end, or its approval be cancelled, while the passcode is typed: what is typed then
    /// unlocks nothing, so nothing is signed or sent.
    func test_aPasscodeTypedForARequestThatEndedOrWasCancelledUnlocksNothing() async throws {
        for cancels in [false, true] {
            let taken = Taken()
            let pending = PendingRequest()
            let typed = TestGate()
            let service = try await service(sending: taken.sending())
            let signer = mnemonic(taken, typed: typed)
            let wallet = wallet()
            let request = request(transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a"))

            let approval = Task {
                await self.signingError {
                    try await service.sign(signer: signer, wallet: wallet, request: request, evmFee: Self.shownFee, consent: .refuse, isPending: { await pending.isPending })
                }
            }
            await waitUntil(taken.changes) { await taken.steps.contains("passcode") }
            if cancels {
                approval.cancel()
            } else {
                await pending.end()
            }
            await typed.open()
            let error = await approval.value

            let interruption = cancels ? "cancelled" : "ended"
            XCTAssertEqual(error, .canceled, interruption)
            let steps = await taken.steps
            XCTAssertEqual(steps, ["passcode"], interruption)
        }
        let transactions = await recorded.all
        XCTAssertTrue(transactions.isEmpty)
    }

    /// The dApp stops waiting while the transaction is signed: the request is asked about right before
    /// the broadcast, so nothing goes out or is recorded, as the SDK's send stops then.
    func test_aTransactionWhoseRequestEndsBeforeItGoesOutIsNeverBroadcast() async throws {
        let pending = PendingRequest()
        let signing = TestGate()
        let service = try await service(sending: taken.sending(signing: signing))
        let signer = mnemonic
        let wallet = wallet()
        let request = request(transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a"))

        let approval = Task {
            await self.signingError {
                try await service.sign(signer: signer, wallet: wallet, request: request, evmFee: Self.shownFee, consent: .refuse, isPending: { await pending.isPending })
            }
        }
        await waitUntil(taken.changes) { await self.taken.steps.contains("send") }
        await pending.end()
        await signing.open()
        let error = await approval.value

        XCTAssertEqual(error, .canceled)
        let steps = await taken.steps
        XCTAssertEqual(steps, ["passcode", "send"])
        let transactions = await recorded.all
        XCTAssertTrue(transactions.isEmpty)
    }

    /// The dApp stops waiting, and the request's screen closes, while the transaction goes out: it is
    /// recorded where the screen's cancellation does not reach, and only the dApp's answer is lost.
    func test_aTransactionWhoseRequestEndsAsItGoesOutIsRecordedAndOnlyItsAnswerIsLost() async throws {
        let pending = PendingRequest()
        let broadcasting = TestGate()
        let service = try await service(sending: taken.sending(broadcasting: broadcasting))
        let signer = mnemonic
        let wallet = wallet()
        let request = request(transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a"))

        let approval = Task {
            await self.signingError {
                try await service.sign(signer: signer, wallet: wallet, request: request, evmFee: Self.shownFee, consent: .refuse, isPending: { await pending.isPending })
            }
        }
        await waitUntil(taken.changes) { await self.taken.steps.contains("broadcast") }
        approval.cancel()
        await pending.end()
        await broadcasting.open()
        let error = await approval.value

        XCTAssertEqual(error, .requestEndedAfterBroadcast)
        let steps = await taken.steps
        XCTAssertEqual(steps, ["passcode", "send", "broadcast"])
        let transactions = await recorded.all
        XCTAssertEqual(transactions.map(\.txHash), ["0xsent"])
        let cancelled = await recorded.cancelled
        XCTAssertEqual(cancelled, [false], "the transaction was recorded from the cancelled approval")
    }

    /// Once the unlock released the transaction, cancelling its approval while the dApp still waits does
    /// not stop it: it goes out and is recorded.
    func test_aTransactionTheUnlockReleasedGoesOutThoughItsApprovalIsCancelled() async throws {
        let signing = TestGate()
        let service = try await service(sending: taken.sending(signing: signing))
        let signer = mnemonic
        let wallet = wallet()
        let request = request(transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a"))

        let approval = Task {
            await self.signingError {
                try await service.sign(signer: signer, wallet: wallet, request: request, evmFee: Self.shownFee, consent: .refuse, isPending: { true })
            }
        }
        await waitUntil(taken.changes) { await self.taken.steps.contains("send") }
        approval.cancel()
        await signing.open()
        let error = await approval.value

        XCTAssertEqual(error, .requestEndedAfterBroadcast, "the send ran cancelled")
        let steps = await taken.steps
        XCTAssertEqual(steps, ["passcode", "send", "broadcast"])
        let transactions = await recorded.all
        XCTAssertEqual(transactions.map(\.txHash), ["0xsent"])
    }

    /// The sender the assembly hands the operation to signs it at the fee shown and from the dApp's
    /// nonce, or the node's without one: chain-kit's own signature of the payload at them, which the
    /// request is asked about right before it would go out.
    func test_chainKitsSenderSignsAtTheShownFeeFromTheDAppsNonceOrElseTheNodes() async throws {
        let unlocked = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: Self.mnemonic)
        let transaction = transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a")
        let signable = try WalletConnectOperationFactory.evmTransaction(transaction, of: request(transaction), wallet: wallet(), fidelity: .exact)
        let account = try ChainKitOperationSender.account(signable.account, signedBy: unlocked)
        let payload = try XCTUnwrap(signable.operation.payloads.first)
        let fee = Self.shownFee.chainKitFee(chain: .eth)
        let mediator = client.blockchain.getMediator(network: account.chain.network.type)
        let nonces: [(dApp: BignumBigInteger?, node: BignumBigInteger?, signed: Int64)] = [
            (BignumBigInteger(long: 42), nil, 42),
            (nil, BignumBigInteger(long: 7), 7),
        ]

        for (dApp, node, signed) in nonces {
            let send = WalletConnectSigningService.sending(through: ChainKitOperationSender(client: client, readNonce: { _ in
                guard let node else {
                    XCTFail("the node was asked for a nonce the dApp gave")
                    return BignumBigInteger(long: 0)
                }
                return node
            }))
            var kept = [ChainKitSignedTransaction]()

            do throws(WalletConnectSigningError) {
                _ = try await send(signable.operation, account, unlocked, fee, dApp) {
                    kept.append($0)
                    // Asked right before it goes out: stopping here leaves the node out of the test.
                    throw Stopped()
                }
                XCTFail("expected the send to stop right before its broadcast")
            } catch {
                guard case .failedToSign = error else {
                    return XCTFail("expected the stop to fail the signing, never to read as a rejection, got \(error)")
                }
            }

            let atTheShownFee = try await mediator.operation.sign(payload: payload, account: account, fee: fee, nonce: BignumBigInteger(long: signed), wallet: unlocked).getOrNull()
            let expected = try mediator.operation.transactionHash(payload: XCTUnwrap(atTheShownFee)).getOrNull()
            XCTAssertNotNil(expected)
            XCTAssertEqual(kept.map(\.hash), [expected.map { $0 as String }], "\(signed)")
            XCTAssertEqual(kept.map(\.nonce), ["\(signed)"])
            XCTAssertEqual(kept.map(\.broadcastAttempted), [true], "the request was asked before the sender was about to broadcast")
            XCTAssertEqual(kept.map(\.acknowledged), [false])
        }
    }

    /// A transaction the dApp only wants signed is the operation the user accepted, signed at the fee shown
    /// and the dApp's nonce: the dApp gets its signed bytes, and nothing goes out or is recorded.
    func test_aTransactionToSignIsTheOperationTheUserAcceptedAndGoesNowhere() async throws {
        let check = Verdict { ValidationError.UnlistedAsset(payloadId: $0.operation.id, asset: Self.usdtAssetId, amount: nil, to: nil, approved: false) }
        let user = ConsentingUser(answering: true) { [taken] in await taken.take("ask") }
        let service = try await service(checks: [check], sending: taken.sending())
        let request = signRequest(transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a"))

        let response = try await service.sign(signer: mnemonic, wallet: wallet(), request: request, evmFee: Self.shownFee, consent: user.attempt(), isPending: { true })

        XCTAssertEqual(response, .string("0xsigned"))
        let steps = await taken.steps
        XCTAssertEqual(steps, ["ask", "passcode", "sign"])
        let reads = await check.reads.all
        let reviewed = try XCTUnwrap(reads.first)
        let handed = await taken.sent
        let signed = try XCTUnwrap(handed.first)
        XCTAssertEqual(reads.count, 1)
        XCTAssertTrue(signed.operation === reviewed.operation, "what is signed is the operation the user was asked about")
        XCTAssertEqual(reviewed.fidelity, .exact)
        XCTAssertEqual(reviewed.intent, .dapp)
        XCTAssertEqual(signed.account.addressDisplay.lowercased(), Self.sender)
        XCTAssertEqual(try WalletConnectEVMFee(fee: XCTUnwrap(signed.fee)), Self.shownFee)
        XCTAssertEqual(signed.nonce?.description, "42")
        let transactions = await recorded.all
        XCTAssertTrue(transactions.isEmpty)
    }

    /// The dApp gets the very bytes the SDK answers it with, for a coin transfer, a token's transfer, an
    /// approval and a contract call alike, at the same fee and nonce.
    func test_aSignedTransactionIsTheOneTheSDKAnswersWith() async throws {
        let asOperation = try await service(
            sending: taken.sending(),
            signing: WalletConnectSigningService.signing(through: ChainKitOperationSender(client: client))
        )
        let bySDK = try await service(signsDappOperations: false, sending: taken.sending())
        let transactions = [
            transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a"),
            transaction(to: Self.usdt, value: "0x0", data: Self.tokenTransfer, nonce: "0x2a"),
            transaction(to: Self.usdt, value: "0x0", data: Self.approval, nonce: "0x2a"),
            transaction(to: Self.weth, value: "0x3e8", data: Self.deposit, nonce: "0x2a"),
        ]

        for transaction in transactions {
            let request = signRequest(transaction)
            let signed = try await asOperation.sign(signer: mnemonic, wallet: wallet(), request: request, evmFee: Self.shownFee, consent: .refuse, isPending: { true })
            let expected = try await bySDK.sign(signer: mnemonic, wallet: wallet(), request: request, evmFee: Self.shownFee, consent: .refuse, isPending: { true })

            XCTAssertEqual(signed, expected, transaction.data)
            guard case let .string(raw) = signed else {
                return XCTFail("expected the signed transaction as a string, got \(signed)")
            }
            XCTAssertTrue(raw.hasPrefix("0x02"), "an EIP-1559 transaction, 0x and its type first: \(raw)")
        }
        let steps = await taken.steps
        XCTAssertFalse(steps.contains("send"))
        let recordedTransactions = await recorded.all
        XCTAssertTrue(recordedTransactions.isEmpty)
    }

    /// The sender the assembly signs with signs at the fee shown, from the dApp's nonce or else the node's,
    /// and answers with chain-kit's own signature of the payload.
    func test_chainKitsSenderSignsWithoutSendingAtTheShownFeeFromTheDAppsNonceOrElseTheNodes() async throws {
        let unlocked = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: Self.mnemonic)
        let transaction = transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a")
        let signable = try WalletConnectOperationFactory.evmTransaction(transaction, of: signRequest(transaction), wallet: wallet(), fidelity: .exact)
        let account = try ChainKitOperationSender.account(signable.account, signedBy: unlocked)
        let payload = try XCTUnwrap(signable.operation.payloads.first)
        let fee = Self.shownFee.chainKitFee(chain: .eth)
        let mediator = client.blockchain.getMediator(network: account.chain.network.type)
        let nonces: [(dApp: BignumBigInteger?, node: BignumBigInteger?, signed: Int64)] = [
            (BignumBigInteger(long: 42), nil, 42),
            (nil, BignumBigInteger(long: 7), 7),
        ]

        for (dApp, node, signed) in nonces {
            let sign = WalletConnectSigningService.signing(through: ChainKitOperationSender(client: client, readNonce: { _ in
                guard let node else {
                    XCTFail("the node was asked for a nonce the dApp gave")
                    return BignumBigInteger(long: 0)
                }
                return node
            }))

            let transactions = try await sign(signable.operation, account, unlocked, fee, dApp)

            let atTheShownFee = try await mediator.operation.sign(payload: payload, account: account, fee: fee, nonce: BignumBigInteger(long: signed), wallet: unlocked).getOrNull()
            let expected = try JSONDecoder().decode(String.self, from: Data(XCTUnwrap(atTheShownFee).data.description.utf8))
            XCTAssertEqual(transactions, [expected], "\(signed)")
        }
    }

    /// What the review finds is asked before the passcode, and a decline unlocks and signs nothing. A
    /// sender the dApp misstates is refused before anything is asked.
    func test_aTransactionToSignThatIsDeclinedOrMisstatedIsNeverUnlocked() async throws {
        let check = Verdict { ValidationError.ForeignRecipient(payloadId: $0.operation.id, expected: Self.recipient, actual: Self.foreign) }
        let user = ConsentingUser(answering: false) { [taken] in await taken.take("ask") }
        let service = try await service(checks: [check], sending: taken.sending())

        let declined = await signingError {
            try await service.sign(
                signer: self.mnemonic,
                wallet: self.wallet(),
                request: self.signRequest(self.transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a")),
                evmFee: Self.shownFee,
                consent: user.attempt(),
                isPending: { true }
            )
        }
        let misstated = await signingError {
            try await service.sign(
                signer: self.mnemonic,
                wallet: self.wallet(),
                request: self.signRequest(self.transaction(from: Self.foreign, to: Self.recipient, value: "0x3e8", nonce: "0x2a")),
                evmFee: Self.shownFee,
                consent: user.attempt(),
                isPending: { true }
            )
        }

        XCTAssertEqual(declined, .canceled)
        XCTAssertEqual(misstated, .senderAddressMismatch(expected: Self.sender, actual: Self.foreign))
        let steps = await taken.steps
        XCTAssertEqual(steps, ["ask"])
    }

    /// The dApp stops waiting while the transaction is signed: it gets no answer, and nothing was sent.
    func test_aTransactionToSignWhoseRequestEndsIsNeverAnswered() async throws {
        let pending = PendingRequest()
        let signing = TestGate()
        let service = try await service(sending: taken.sending(), signing: taken.signing(gate: signing))
        let signer = mnemonic
        let wallet = wallet()
        let request = signRequest(transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a"))

        let approval = Task {
            await self.signingError {
                try await service.sign(signer: signer, wallet: wallet, request: request, evmFee: Self.shownFee, consent: .refuse, isPending: { await pending.isPending })
            }
        }
        await waitUntil(taken.changes) { await self.taken.steps.contains("sign") }
        await pending.end()
        await signing.open()
        let error = await approval.value

        XCTAssertEqual(error, .canceled)
        let steps = await taken.steps
        XCTAssertEqual(steps, ["passcode", "sign"])
        let transactions = await recorded.all
        XCTAssertTrue(transactions.isEmpty)
    }

    /// chain-kit signs a TRON message into the very signature the SDK's own TIP-191 signer gives it.
    func test_chainKitSignsATronMessageAsTheSDKsSignerDoes() async throws {
        let unlocked = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: Self.mnemonic)
        let privateKey = unlocked.getPrivateKey(chain: MultichainChain.tron.asChainKitChain).data().asData
        let sender = ChainKitOperationSender(client: client)

        for message in Self.tronMessages {
            let signable = try WalletConnectOperationFactory.tronMessage(message, of: tronRequest(message), wallet: wallet(), fidelity: .exact)
            let account = try ChainKitOperationSender.account(signable.account, signedBy: unlocked)
            let payload = try XCTUnwrap(signable.operation.payloads.first, message)

            let signed = try await sender.signMessage(payload, account: account, wallet: unlocked)

            XCTAssertEqual(signed, try WalletConnectTronMessageSigner.sign(message: message, privateKeyData: privateKey), message)
        }
    }

    /// With the switch on, a TRON message is the operation the user accepted, asked about before the
    /// passcode and signed by chain-kit: the dApp gets the signature the SDK's signer answers with.
    func test_aTronMessageIsSignedAsTheMessageTheUserAccepted() async throws {
        let check = Verdict { ValidationError.UnlistedAsset(payloadId: $0.operation.id, asset: Self.usdtAssetId, amount: nil, to: nil, approved: false) }
        let user = ConsentingUser(answering: true) { [taken] in await taken.take("ask") }
        let asOperation = try await service(checks: [check], sending: taken.sending())
        let bySDK = try await service(signsDappOperations: false, sending: taken.sending())

        for message in Self.tronMessages {
            let request = tronRequest(message, address: Self.tronSender)

            let signed = try await asOperation.sign(signer: mnemonic, wallet: wallet(), request: request, evmFee: nil, consent: user.attempt(), isPending: { true })
            let expected = try await bySDK.sign(signer: mnemonic, wallet: wallet(), request: request, evmFee: nil, consent: .refuse, isPending: { true })

            XCTAssertEqual(signed, expected, message)
        }
        let steps = await taken.steps
        XCTAssertEqual(steps, Self.tronMessages.flatMap { _ in ["ask", "passcode", "passcode"] })
        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.fidelity), Self.tronMessages.map { _ in .exact })
        XCTAssertEqual(reads.map(\.intent), Self.tronMessages.map { _ in .dapp })
        let transactions = await recorded.all
        XCTAssertTrue(transactions.isEmpty)
    }

    /// A TRON message the dApp says is another address's is refused before anything is asked or unlocked;
    /// a declined one unlocks nothing.
    func test_aTronMessageFromAnotherAddressOrDeclinedIsNeverUnlocked() async throws {
        let check = Verdict { ValidationError.UnlistedAsset(payloadId: $0.operation.id, asset: Self.usdtAssetId, amount: nil, to: nil, approved: false) }
        let user = ConsentingUser(answering: false) { [taken] in await taken.take("ask") }
        let service = try await service(checks: [check], sending: taken.sending())

        let misstated = await signingError {
            try await service.sign(
                signer: self.mnemonic,
                wallet: self.wallet(),
                request: self.tronRequest("hello", address: Self.foreignTron),
                evmFee: nil,
                consent: user.attempt(),
                isPending: { true }
            )
        }
        let declined = await signingError {
            try await service.sign(signer: self.mnemonic, wallet: self.wallet(), request: self.tronRequest("hello"), evmFee: nil, consent: user.attempt(), isPending: { true })
        }

        XCTAssertEqual(misstated, .senderAddressMismatch(expected: Self.tronSender, actual: Self.foreignTron))
        XCTAssertEqual(declined, .canceled)
        let steps = await taken.steps
        XCTAssertEqual(steps, ["ask"])
    }

    /// The dApp's sender and nonce, and its call, are read before the review: a transaction that misstates
    /// them is refused for what it misstates, and nothing is asked, unlocked or signed. A review no check
    /// could read is no decline.
    func test_aTransactionTheDAppMisstatesOrNoCheckCouldReadIsNeverUnlocked() async throws {
        let check = Verdict { ValidationError.UnlistedAsset(payloadId: $0.operation.id, asset: Self.usdtAssetId, amount: nil, to: nil, approved: false) }
        let user = ConsentingUser(answering: true) { [taken] in await taken.take("ask") }
        let service = try await service(checks: [check], sending: taken.sending())
        let misstated: [(WalletConnectEVMTransaction, WalletConnectSigningError)] = [
            (transaction(from: Self.foreign, to: Self.recipient, value: "0x3e8", nonce: "0x2a"), .senderAddressMismatch(expected: Self.sender, actual: Self.foreign)),
            (transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2g"), .invalidTransaction(reason: "invalid EVM quantity nonce: 0x2g")),
            (transaction(to: nil, value: "0x3e8", nonce: "0x2a"), .missingRecipient),
        ]

        for (transaction, expected) in misstated {
            let error = await signingError {
                try await service.sign(signer: self.mnemonic, wallet: self.wallet(), request: self.request(transaction), evmFee: Self.shownFee, consent: user.attempt(), isPending: { true })
            }
            XCTAssertEqual(error, expected)
        }
        let unchecked = try await self.service(checks: [FailingCheck()], sending: taken.sending())
        let unreadable = await signingError {
            try await unchecked.sign(
                signer: self.mnemonic,
                wallet: self.wallet(),
                request: self.request(self.transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a")),
                evmFee: Self.shownFee,
                consent: user.attempt(),
                isPending: { true }
            )
        }

        guard case .unreviewable = unreadable else {
            return XCTFail("expected a review no check could read to fail the signing, got \(String(describing: unreadable))")
        }
        let steps = await taken.steps
        XCTAssertTrue(steps.isEmpty)
        let reads = await check.reads.all
        XCTAssertTrue(reads.isEmpty)
    }

    /// The SDK's signer reads the sender only once it unlocked the wallet; signed as its operation, the
    /// same transaction is refused before the passcode. So is one the dApp only wants signed.
    func test_whileTheSwitchIsOffTheSDKSignsTheTransaction() async throws {
        let service = try await service(signsDappOperations: false, sending: taken.sending())
        let transaction = transaction(from: Self.foreign, to: Self.recipient, value: "0x3e8", nonce: "0x2a")

        for request in [request(transaction), signRequest(transaction)] {
            let error = await signingError {
                try await service.sign(signer: self.mnemonic, wallet: self.wallet(), request: request, evmFee: Self.shownFee, consent: .refuse, isPending: { true })
            }

            XCTAssertEqual(error, .senderAddressMismatch(expected: Self.sender, actual: Self.foreign), request.method.rawValue)
        }
        let steps = await taken.steps
        XCTAssertEqual(steps, ["passcode", "passcode"])
    }

    func test_aHardwareWalletsTransactionKeepsItsDevice() async throws {
        let service = try await service(sending: taken.sending())
        let device = DeviceTransferSigner(
            evm: { [taken] _ in
                await taken.take("device")
                throw CancellationError()
            },
            tron: { _ in Data() },
            solana: { _ in Data() },
            bitcoin: { _ in [] },
            ton: { _ in [] },
            evmMessage: { _ in Data() },
            evmTypedData: { _, _ in Data() },
            tronMessage: { [taken] _ in
                await taken.take("device")
                throw CancellationError()
            }
        )

        let ledger = wallet(kind: .Ledger(
            TonSwift.PublicKey(data: Data(repeating: 1, count: 32)),
            .v4R2,
            KeeperCore.Wallet.LedgerDevice(deviceId: "device", deviceModel: "Ledger Stax", accountIndex: 0)
        ))
        let transaction = transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a")

        for request in [request(transaction), signRequest(transaction), tronRequest("hello")] {
            let error = await signingError {
                try await service.sign(signer: .device(device), wallet: ledger, request: request, evmFee: Self.shownFee, consent: .refuse, isPending: { true })
            }

            XCTAssertEqual(error, .canceled, request.method.rawValue)
        }
        let steps = await taken.steps
        XCTAssertEqual(steps, ["device", "device", "device"])
    }

    /// EVM messages and a transaction on a chain that is no EVM's go to their own signers, as before.
    func test_everyOtherRequestKeepsItsSigner() async throws {
        let service = try await service(sending: taken.sending())
        let typedData = try WalletConnectEthSignTypedDataV4Parser().canonicalTypedData(
            #"{"types":{"EIP712Domain":[{"name":"name","type":"string"}],"Mail":[{"name":"body","type":"string"}]},"primaryType":"Mail","domain":{"name":"dApp"},"message":{"body":"hi"}}"#,
            chain: .eth
        )
        let signed: [WalletConnectSessionRequest] = [
            request(.personalSign, payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal))),
            request(.ethSignTypedDataV4, payload: .signMessage(.init(address: nil, message: typedData, kind: .typedDataV4))),
        ]

        for request in signed {
            let response = try await service.sign(signer: mnemonic, wallet: wallet(), request: request, evmFee: Self.shownFee, consent: .refuse, isPending: { true })
            XCTAssertNotEqual(response, .null, request.method.rawValue)
        }
        let notEVM = await signingError {
            try await service.sign(
                signer: self.mnemonic,
                wallet: self.wallet(),
                request: self.request(.ethSendTransaction, chain: .tron, payload: .evmTransaction(self.transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a"), send: true)),
                evmFee: Self.shownFee,
                consent: .refuse,
                isPending: { true }
            )
        }

        guard case .invalidTransaction = notEVM else {
            return XCTFail("expected the SDK's signer to refuse a transaction on a chain that is no EVM's, got \(String(describing: notEVM))")
        }
        let steps = await taken.steps
        XCTAssertEqual(steps, Array(repeating: "passcode", count: signed.count))
        let transactions = await recorded.all
        XCTAssertTrue(transactions.isEmpty)
    }

    func test_aFailedSendIsNoDeclineAndRecordsNothing() async throws {
        let service = try await service(sending: taken.failing(with: .failedToSend(reason: "refused")))

        let error = await signingError {
            try await service.sign(
                signer: self.mnemonic,
                wallet: self.wallet(),
                request: self.request(self.transaction(to: Self.recipient, value: "0x3e8", nonce: "0x2a")),
                evmFee: Self.shownFee,
                consent: .refuse,
                isPending: { true }
            )
        }

        XCTAssertEqual(error, .failedToSend(reason: "refused"))
        let transactions = await recorded.all
        XCTAssertTrue(transactions.isEmpty)
    }

    /// Only a cancelled task, or the request found over, reads as the user's rejection.
    func test_chainKitsFailuresAreTheOnesTheDAppIsTold() {
        XCTAssertEqual(WalletConnectSigningService.failure(of: CancellationError()), .canceled)
        XCTAssertEqual(WalletConnectSigningService.failure(of: WalletConnectSigningError.canceled), .canceled)
        XCTAssertEqual(WalletConnectSigningService.failure(of: ChainKitOperationError.nonceUnavailable("timeout")), .failedToEstimateNonce(reason: "timeout"))
        XCTAssertEqual(
            WalletConnectSigningService.failure(of: ChainKitOperationError.feeUnavailable(payloadId: "request", reason: "reverted")),
            .failedToCalculateFee(reason: "reverted")
        )
        XCTAssertEqual(
            WalletConnectSigningService.failure(of: ChainKitOperationError.signingFailed(payloadId: "request", reason: "refused")),
            .failedToSign(reason: "refused")
        )
        XCTAssertEqual(
            WalletConnectSigningService.failure(of: ChainKitOperationError.insufficientFunds(payloadId: "request")),
            .failedToSend(reason: "the node refused the transaction for want of funds")
        )
        XCTAssertEqual(
            WalletConnectSigningService.failure(of: ChainKitOperationError.broadcastFailed(payloadId: "request", sent: [], reason: "nonce too low")),
            .failedToSend(reason: "nonce too low")
        )
        guard case .failedToSign = WalletConnectSigningService.failure(of: ChainKitOperationError.keyMismatch(expected: "a", unlocked: "b")) else {
            return XCTFail("expected anything else to fail the signing, never to read as a rejection")
        }
    }
}

private extension WalletConnectOperationSigningTests {
    /// Asks for the passcode the mnemonic was saved under.
    var mnemonic: MultichainTransferSigner {
        mnemonic(taken)
    }

    func mnemonic(_ taken: Taken) -> MultichainTransferSigner {
        .mnemonic(passcodeProvider: {
            await taken.take("passcode")
            return Self.passcode
        })
    }

    /// Asks for the passcode, and hands it back once `typed` opens or the approval is cancelled: what is
    /// typed for a request that is over must unlock nothing.
    func mnemonic(_ taken: Taken, typed: TestGate) -> MultichainTransferSigner {
        .mnemonic(passcodeProvider: {
            await taken.take("passcode")
            do {
                try await typed.wait()
            } catch {
                // The approval was cancelled while the passcode was typed: it is handed back all the same.
            }
            return Self.passcode
        })
    }

    /// Signs a transaction the dApp only wants signed through ``Taken/signing(_:gate:)``.
    func service(
        checks: [any OperationCheck] = [],
        signsDappOperations: Bool = true,
        sending send: @escaping WalletConnectSigningService.OperationSend
    ) async throws -> WalletConnectSigningService {
        try await service(checks: checks, signsDappOperations: signsDappOperations, sending: send, signing: taken.signing())
    }

    func service(
        checks: [any OperationCheck] = [],
        signsDappOperations: Bool = true,
        sending send: @escaping WalletConnectSigningService.OperationSend,
        signing sign: @escaping WalletConnectSigningService.OperationSign
    ) async throws -> WalletConnectSigningService {
        let mnemonicAccess = MnemonicAccess.inMemory(seed: "wallet-connect-operation")
        try await mnemonicAccess.saveMnemonic(
            CoreMnemonic(mnemonicWords: Self.mnemonic.components(separatedBy: " "), type: .bip39),
            wallet: wallet(),
            passcode: Self.passcode
        )
        return WalletConnectSigningService(
            mnemonicAccess: mnemonicAccess,
            client: client,
            pendingTransactionsService: recorded,
            gate: OperationGate { checks },
            signsDappOperations: signsDappOperations,
            sendOperation: send,
            signOperation: sign
        )
    }

    func signingError(_ sign: () async throws -> WalletConnectResponseValue) async -> WalletConnectSigningError? {
        do {
            let response = try await sign()
            XCTFail("expected the request to fail, got \(response)")
        } catch let error as WalletConnectSigningError {
            return error
        } catch {
            XCTFail("expected a signing error, got \(error)")
        }
        return nil
    }

    func request(_ transaction: WalletConnectEVMTransaction, id: String = "request") -> WalletConnectSessionRequest {
        request(.ethSendTransaction, payload: .evmTransaction(transaction, send: true), id: id)
    }

    /// `transaction` the dApp only wants signed, `eth_signTransaction`.
    func signRequest(_ transaction: WalletConnectEVMTransaction) -> WalletConnectSessionRequest {
        request(.ethSignTransaction, payload: .evmTransaction(transaction, send: false))
    }

    /// `tron_signMessage` of `message`, naming `address` as its signer or none.
    func tronRequest(_ message: String, address: String? = nil) -> WalletConnectSessionRequest {
        request(.tronSignMessage, chain: .tron, payload: .signMessage(.init(address: address, message: message, kind: .tron)))
    }

    func request(
        _ method: KeeperCore.WalletConnectMethod,
        chain: WalletConnectChain = .eth,
        payload: WalletConnectRequestPayload,
        id: String = "request"
    ) -> WalletConnectSessionRequest {
        WalletConnectSessionRequest(
            id: id,
            topic: "topic",
            chain: chain,
            method: method,
            dapp: WalletConnectDapp(name: "dApp", url: "https://example.com", description: "", iconURL: nil),
            payload: payload,
            source: nil,
            walletId: "wallet"
        )
    }

    func transaction(from: String? = WalletConnectOperationSigningTests.sender, to: String?, value: String, data: String = "0x", nonce: String?) -> WalletConnectEVMTransaction {
        WalletConnectEVMTransaction(
            from: from,
            to: to,
            data: data,
            value: value,
            nonce: nonce,
            gas: "0x5208",
            gasPrice: "0x3b9aca00",
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil
        )
    }

    func wallet(kind: KeeperCore.WalletKind = .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)) -> KeeperCore.Wallet {
        KeeperCore.Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: kind),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(
                walletId: "wallet",
                addresses: [
                    MultichainWalletAddress(chain: .eth, address: Self.sender, publicKey: Self.storedKey),
                    MultichainWalletAddress(chain: .tron, address: Self.tronSender, publicKey: nil),
                ],
                syncState: .synced
            ))
        )
    }
}

/// What a request went through, in order: the user's question, the passcode or the device, the send of
/// its operation, with what that was signed from and at, and its broadcast.
private actor Taken {
    struct Sent {
        let operation: ChainKit.Operation
        let account: ChainKit.Account
        let wallet: MnemonicWallet
        let fee: (any Fee)?
        let nonce: BignumBigInteger?
    }

    /// What the send shows its request right before the broadcast, none of which the request reads.
    private static let outgoing = ChainKitSignedTransaction(payloadId: "request", nonce: "42", data: "0x", hash: "0xsent", acknowledged: false, broadcastAttempted: true)

    nonisolated let changes = TestSignal()
    private(set) var steps = [String]()
    private(set) var sent = [Sent]()

    func take(_ step: String) {
        steps.append(step)
        changes.send()
    }

    /// A send that keeps what it is handed, signs it once `signing` opens and broadcasts it once its
    /// request let it go out, answering with its hash once `broadcasting` opens. As chain-kit's sender
    /// does, it stops where a cancellation reaches it before the broadcast.
    nonisolated func sending(signing: TestGate? = nil, broadcasting: TestGate? = nil) -> WalletConnectSigningService.OperationSend {
        { operation, account, wallet, fee, nonce, beforeBroadcast throws(WalletConnectSigningError) in
            await self.keep(Sent(operation: operation, account: account, wallet: wallet, fee: fee, nonce: nonce))
            do {
                try await signing?.wait()
                try Task.checkCancellation()
                try await beforeBroadcast(Self.outgoing)
                await self.take("broadcast")
                try await broadcasting?.wait()
            } catch {
                throw WalletConnectSigningService.failure(of: error)
            }
            return ["0xsent"]
        }
    }

    nonisolated func failing(with error: WalletConnectSigningError) -> WalletConnectSigningService.OperationSend {
        { operation, account, wallet, fee, nonce, _ in
            await self.keep(Sent(operation: operation, account: account, wallet: wallet, fee: fee, nonce: nonce))
            throw error
        }
    }

    /// A signature that keeps what it is handed and answers with `signed` once `gate` opens. As
    /// chain-kit's sender does, it stops where a cancellation reaches it.
    nonisolated func signing(_ signed: String = "0xsigned", gate: TestGate? = nil) -> WalletConnectSigningService.OperationSign {
        { operation, account, wallet, fee, nonce throws(WalletConnectSigningError) in
            await self.keep(Sent(operation: operation, account: account, wallet: wallet, fee: fee, nonce: nonce), as: "sign")
            do {
                try await gate?.wait()
                try Task.checkCancellation()
            } catch {
                throw WalletConnectSigningService.failure(of: error)
            }
            return [signed]
        }
    }

    private func keep(_ sent: Sent, as step: String = "send") {
        self.sent.append(sent)
        take(step)
    }
}

/// chain-kit answering `error` about what it reads, rated as the check rates that answer, and what it
/// read.
private struct Verdict: OperationCheck {
    actor Reads {
        private(set) var all = [SignableOperation]()

        func append(_ signable: SignableOperation) {
            all.append(signable)
        }
    }

    let reads = Reads()
    let error: @Sendable (SignableOperation) -> ValidationError

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        await reads.append(signable)
        return try ChainKitValidationCheck.findings([error(signable)], of: signable, intent: ChainKitValidationCheck.intent(of: signable))
    }
}

/// Finds nothing to ask about, and the request ends while it reads.
private struct EndingCheck: OperationCheck {
    let end: @Sendable () async -> Void

    func findings(of _: SignableOperation) async throws -> [OperationFinding] {
        await end()
        return []
    }
}

/// A request the dApp waits for until it ends.
private actor PendingRequest {
    private(set) var isPending = true

    func end() {
        isPending = false
    }
}

/// The transactions reported pending, and whether the task each was reported from was cancelled, as a
/// write of it to the backend would be.
private actor RecordedTransactions: PendingTransactionsService {
    private(set) var all = [MultichainPendingTransaction]()
    private(set) var cancelled = [Bool]()

    func report(_ transaction: MultichainPendingTransaction) async {
        all.append(transaction)
        cancelled.append(Task.isCancelled)
    }

    func flushRetained() async {}
}

private struct Stopped: Error {}
