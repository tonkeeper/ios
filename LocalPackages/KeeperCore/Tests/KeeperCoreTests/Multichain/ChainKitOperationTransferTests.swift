@preconcurrency import BigInt
@preconcurrency import ChainKit
@testable import KeeperCore
@testable import KeeperCoreComponents
import KeeperCoreSensitive
import OperationReviewModels
import TonSwift
import XCTest

/// A wallet's own send signed as chain-kit's operation for it: the operation `transfer()` builds is
/// priced, reviewed and shown, and that operation is signed at that fee from the account the review
/// read. The gate asks before the passcode, and a refusal unlocks, signs and sends nothing.
final class ChainKitOperationTransferTests: XCTestCase {
    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    /// m/44'/60'/0'/0/0 of the phrase above, and the key it stored.
    private static let sender = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
    private static let storedKey = MultichainPublicKey(
        defaultHex: "0x0437b0bb7a8288d38ed49a524b5dc98cff3eb5ca824c9f9dc0dfdb3d9cd600f299a6179912b7451c09896c4098eca7ce6b2e58330672795e847c4d6af44e024230",
        segWit: ""
    )
    private static let recipient = "0x8ba1f109551bd432803012645ac136ddd64dba72"
    private static let foreign = "0x00000000000000000000000000000000000000aa"
    private static let otherForeign = "0x00000000000000000000000000000000000000bb"
    private static let tonSender = "UQBcmqkZxhc81WNeFFzq9ZX6qBlP28B-MuYeSxpS_-YMIDNl"
    private static let tonRecipient = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
    private static let eth = MultichainAssetDetails(assetId: "eth/mainnet/coin", name: "Ethereum", symbol: "ETH", decimals: 18, image: "")
    private static let usdt = MultichainAssetDetails(
        assetId: "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
        name: "Tether USD",
        symbol: "USDT",
        decimals: 6,
        image: ""
    )
    private static let ton = MultichainAssetDetails(assetId: "ton/mainnet/coin", name: "Toncoin", symbol: "TON", decimals: 9, image: "")
    /// Another phrase, whose TON key an encrypted comment goes to.
    private static let recipientMnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
    private static let tonFee = FeeValue(asset: MultichainChain.ton.asChainKitChain.toAsset(), amount: BignumBigInteger(long: 4_000_000))
    /// What the chain priced a send at: 21000 gas at 5 gwei.
    private static let fee = FeeEip1559(
        asset: MultichainChain.eth.asChainKitChain.toAsset(),
        limit: BignumBigInteger(long: 21000),
        networkPrice: BignumBigInteger(long: 3_000_000_000),
        maxPrice: BignumBigInteger(long: 5_000_000_000),
        minerPrice: BignumBigInteger(long: 1_000_000_000),
        amount: BignumBigInteger(long: 105_000_000_000_000)
    )

    private var checks = [any OperationCheck]()
    private let taken = OperationTaken()
    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    func test_aCoinSendIsSignedAsTheOperationItWasPricedAtThatFee() async throws {
        let service = makeService()
        let priced = PricingRecord()

        let emulation = try await service.operationEmulation(
            of: transfer(of: chainKitAsset(Self.eth), amount: 1_000_000_000),
            feeAsset: MultichainChain.eth.asChainKitChain.toAsset(),
            from: sender(),
            to: Self.recipient,
            intent: .send(1_000_000_000, of: Self.eth, to: Self.recipient),
            wallet: wallet()
        ) { payload, account in
            await priced.record(payload: payload.id, account: account.addressDisplay.lowercased(), asset: account.asset.id, value: Self.value(of: payload))
            return (Self.fee, Self.reserve(1_000_000_000))
        }
        let operation = try XCTUnwrap(emulation.operation)
        let hashes = try await service.send(operation, consent: .refuse, steps: taken.steps(unlocking: unlocked()))

        XCTAssertEqual(emulation.fee, 105_000_000_000_000)
        XCTAssertNil(emulation.adjustedAmount)
        XCTAssertNil(emulation.review)
        let pricedFor = await priced.all
        XCTAssertEqual(pricedFor, [PricingRecord.Priced(payload: "main", account: Self.sender.lowercased(), asset: Self.eth.assetId, value: "1000000000")])
        XCTAssertEqual(operation.signable.fidelity, .exact)
        let meta = try XCTUnwrap(operation.signable.operation.payloads.first?.meta as? PayloadMetaEvmMain)
        XCTAssertEqual(meta.to.display.lowercased(), Self.recipient)
        XCTAssertEqual(meta.value.description, "1000000000")
        XCTAssertNil(meta.data)
        XCTAssertEqual(hashes, ["0xsent"])
        let steps = await taken.all
        XCTAssertEqual(steps, try [.unlock, sent(operation, asset: Self.eth.assetId)])
    }

    /// The token's own account prices and signs its send, the call of its contract.
    func test_anERC20SendIsSignedAsItsContractsCallFromTheTokensAccount() async throws {
        let service = makeService()
        let priced = PricingRecord()

        let emulation = try await service.operationEmulation(
            of: transfer(of: chainKitAsset(Self.usdt), amount: 1_000_000),
            feeAsset: MultichainChain.eth.asChainKitChain.toAsset(),
            from: sender(),
            to: Self.recipient,
            intent: .send(1_000_000, of: Self.usdt, to: Self.recipient),
            wallet: wallet()
        ) { payload, account in
            await priced.record(payload: payload.id, account: account.addressDisplay.lowercased(), asset: account.asset.id, value: Self.value(of: payload))
            return (Self.fee, Self.reserve(1_000_000))
        }
        let operation = try XCTUnwrap(emulation.operation)
        let hashes = try await service.send(operation, consent: .refuse, steps: taken.steps(unlocking: unlocked()))

        let pricedFor = await priced.all
        XCTAssertEqual(pricedFor, [PricingRecord.Priced(payload: "main", account: Self.sender.lowercased(), asset: Self.usdt.assetId, value: "0")])
        let meta = try XCTUnwrap(operation.signable.operation.payloads.first?.meta as? PayloadMetaEvmMain)
        XCTAssertEqual(meta.to.display.lowercased(), "0xdac17f958d2ee523a2206206994597c13d831ec7")
        XCTAssertEqual(meta.value.description, "0")
        XCTAssertEqual(meta.data?.lowercased(), "0xa9059cbb" + String(repeating: "0", count: 24) + Self.recipient.dropFirst(2) + String(repeating: "0", count: 59) + "f4240")
        XCTAssertEqual(hashes, ["0xsent"])
        let steps = await taken.all
        XCTAssertEqual(steps, try [.unlock, sent(operation, asset: Self.usdt.assetId)])
    }

    /// chain-kit holds the operation to the intent it was priced for and finds nothing the user is
    /// asked about: the send goes out on a consent that would refuse.
    func test_chainKitFindsNothingToAskAboutInAnOwnSend() async throws {
        checks = [ChainKitValidationCheck(client: client)]
        let service = makeService()

        for (asset, amount) in [(Self.eth, BigUInt(1_000_000_000)), (Self.usdt, BigUInt(1_000_000))] {
            let emulation = try await emulation(of: asset, amount: amount, service: service)
            let review = try XCTUnwrap(emulation.review)

            let hashes = try await service.send(XCTUnwrap(emulation.operation), consent: .refuse, steps: taken.steps(unlocking: unlocked()))

            XCTAssertFalse(review.requiresConsent, "\(review.findings)")
            XCTAssertEqual(hashes, ["0xsent"])
        }
    }

    /// A danger chain-kit finds is put to the user before the passcode: refused, the wallet is not
    /// unlocked and nothing is signed or sent.
    func test_aDangerIsAskedAboutBeforeTheUnlockAndARefusalSignsNothing() async throws {
        checks = [Verdict { ValidationError.ForeignRecipient(payloadId: $0.operation.id, expected: Self.recipient, actual: Self.foreign) }]
        let service = makeService()
        let operation = try await priced(Self.eth, amount: 1_000_000_000, service: service)
        let user = ConsentingUser(answering: false) { [taken] in await taken.take(.ask) }
        let steps = try taken.steps(unlocking: unlocked())

        do {
            _ = try await service.send(operation, consent: user.attempt(), steps: steps)
            XCTFail("expected the refusal to cancel the send")
        } catch {
            guard case .canceled = error else {
                return XCTFail("expected a cancellation, got \(error.logDescription)")
            }
        }

        let asked = await user.asked
        XCTAssertEqual(asked.flatMap(\.findings).map(\.severity), [.danger])
        let took = await taken.all
        XCTAssertEqual(took, [.ask])
    }

    func test_aDangerTheUserAcceptsIsUnlockedForAndSigned() async throws {
        checks = [Verdict { ValidationError.ForeignRecipient(payloadId: $0.operation.id, expected: Self.recipient, actual: Self.foreign) }]
        let service = makeService()
        let operation = try await priced(Self.eth, amount: 1_000_000_000, service: service)
        let user = ConsentingUser(answering: true) { [taken] in await taken.take(.ask) }

        let hashes = try await service.send(operation, consent: user.attempt(), steps: taken.steps(unlocking: unlocked()))

        XCTAssertEqual(hashes, ["0xsent"])
        let steps = await taken.all
        XCTAssertEqual(steps, try [.ask, .unlock, sent(operation, asset: Self.eth.assetId)])
    }

    /// What chain-kit rates a warning is information in the wallet's own send: nobody is asked.
    func test_aWarningAsksNothingInTheWalletsOwnSend() async throws {
        checks = [Verdict { ValidationError.UnlistedAsset(payloadId: $0.operation.id, asset: Self.usdt.assetId, amount: nil, to: nil, approved: false) }]
        let service = makeService()
        let emulation = try await emulation(of: Self.eth, amount: 1_000_000_000, service: service)
        let operation = try XCTUnwrap(emulation.operation)
        let review = try XCTUnwrap(emulation.review)
        let user = ConsentingUser(answering: false) { [taken] in await taken.take(.ask) }

        let hashes = try await service.send(operation, consent: user.attempt(), steps: taken.steps(unlocking: unlocked()))

        XCTAssertEqual(review.findings.map(\.severity), [.info])
        XCTAssertEqual(hashes, ["0xsent"])
        let steps = await taken.all
        XCTAssertEqual(steps, try [.unlock, sent(operation, asset: Self.eth.assetId)])
    }

    /// The emulation reviews the very operation the send signs: what the swipe accepted is not asked
    /// about again.
    func test_anOperationAcceptedOnTheSwipeIsSignedWithoutAskingAgain() async throws {
        checks = [WarningCheck()]
        let service = makeService()
        let user = ConsentingUser(answering: true) { [taken] in await taken.take(.ask) }
        let consent = user.attempt()
        let emulation = try await emulation(of: Self.eth, amount: 1_000_000_000, service: service)
        let operation = try XCTUnwrap(emulation.operation)
        let review = try XCTUnwrap(emulation.review)
        _ = await consent(review)

        _ = try await service.send(operation, consent: consent, steps: taken.steps(unlocking: unlocked()))

        let asked = await user.asked
        XCTAssertEqual(asked, [review])
        let steps = await taken.all
        XCTAssertEqual(steps, try [.ask, .unlock, sent(operation, asset: Self.eth.assetId)])
    }

    func test_anOperationNoCheckCouldReadIsNeitherUnlockedForNorSignedAndIsNoCancellation() async throws {
        checks = [FailingCheck()]
        let service = makeService()
        let operation = try await priced(Self.eth, amount: 1_000_000_000, service: service)
        let steps = try taken.steps(unlocking: unlocked())

        do {
            _ = try await service.send(operation, consent: ConsentingUser(answering: true).attempt(), steps: steps)
            XCTFail("expected the unreviewed operation to fail")
        } catch {
            guard case .internal = error else {
                return XCTFail("expected an internal failure, got \(error.logDescription)")
            }
        }
        let took = await taken.all
        XCTAssertEqual(took, [])
    }

    /// An address that stored another key or none is reviewed with what it stored, and signed with the
    /// unlocked key, the address being that key's own.
    func test_anAddressThatStoredAnotherKeyOrNoneIsSignedWithTheUnlockedOne() async throws {
        let service = makeService()
        let compressed = MultichainPublicKey(defaultHex: "0x0237b0bb7a8288d38ed49a524b5dc98cff3eb5ca824c9f9dc0dfdb3d9cd600f299", segWit: "")

        for stored in [nil, compressed] {
            let operation = try await priced(Self.eth, amount: 1_000_000_000, from: sender(storing: stored), service: service)

            _ = try await service.send(operation, consent: .refuse, steps: taken.steps(unlocking: unlocked()))

            XCTAssertEqual(operation.signable.account.publicKey?.defaultHex, stored?.defaultHex)
            let steps = await taken.all
            XCTAssertEqual(steps.last, try sent(operation, asset: Self.eth.assetId))
        }
    }

    func test_anAddressTheUnlockedKeysDoNotHoldIsNeverSigned() async throws {
        let service = makeService()
        let address = MultichainWalletAddress(chain: .eth, address: Self.recipient)
        let operation = try await priced(Self.eth, amount: 1_000_000_000, from: address, to: Self.foreign, service: service)
        let steps = try taken.steps(unlocking: unlocked())

        do {
            _ = try await service.send(operation, consent: .refuse, steps: steps)
            XCTFail("expected the send of another address to fail")
        } catch {
            guard case .internal = error else {
                return XCTFail("expected an internal failure, got \(error.logDescription)")
            }
        }
        let took = await taken.all
        XCTAssertEqual(took, [.unlock])
    }

    /// The whole balance less what the gas reserve keeps is shown, built into the operation and signed,
    /// priced once for the whole amount. Its tip is the whole max fee, as the SDK signs a whole balance,
    /// so what the reserve kept for gas is spent rather than left on the address.
    func test_anEVMCoinMaxSendSignsWhatTheReserveLeavesAndSpendsTheReserve() async throws {
        let service = makeService()
        let priced = PricingRecord()

        let emulation = try await service.operationEmulation(
            of: transfer(of: chainKitAsset(Self.eth), amount: 1_000_000_000_000_000_000, isMax: true),
            feeAsset: MultichainChain.eth.asChainKitChain.toAsset(),
            from: sender(),
            to: Self.recipient,
            intent: .send(1_000_000_000_000_000_000, of: Self.eth, to: Self.recipient),
            wallet: wallet()
        ) { payload, account in
            await priced.record(payload: payload.id, account: account.addressDisplay.lowercased(), asset: account.asset.id, value: Self.value(of: payload))
            return (Self.fee, Self.reserve(999_895_000_000_000_000, adjusted: true))
        }
        let operation = try XCTUnwrap(emulation.operation)
        _ = try await service.send(operation, consent: .refuse, steps: taken.steps(unlocking: unlocked()))

        XCTAssertEqual(emulation.adjustedAmount, 999_895_000_000_000_000)
        XCTAssertTrue(emulation.isMaxAmount)
        XCTAssertEqual(emulation.fee, 105_000_000_000_000)
        let pricedFor = await priced.all
        XCTAssertEqual(pricedFor, [PricingRecord.Priced(payload: "main", account: Self.sender.lowercased(), asset: Self.eth.assetId, value: "1000000000000000000")])
        let meta = try XCTUnwrap(operation.signable.operation.payloads.first?.meta as? PayloadMetaEvmMain)
        XCTAssertEqual(meta.value.description, "999895000000000000")
        let signedAt = try XCTUnwrap(operation.fee as? FeeEip1559)
        XCTAssertEqual(
            [signedAt.limit, signedAt.networkPrice, signedAt.maxPrice, signedAt.minerPrice, signedAt.amount].map(\.description),
            ["21000", "3000000000", "5000000000", "5000000000", "105000000000000"]
        )
        let steps = await taken.all
        XCTAssertEqual(steps, try [.unlock, sent(operation, asset: Self.eth.assetId, fee: signedAt)])
    }

    /// The comment is signed with the TON it rides on, as an exchange credits a deposit by it. TON sends a
    /// whole balance in a mode of its own, whatever the gas reserve left of the amount.
    func test_aTonCoinSendSignsItsCommentAndAMaxSendTheWholeBalance() async throws {
        let service = makeService()
        let ton = MultichainChain.ton.asChainKitChain

        for isMax in [false, true] {
            let emulation = try await service.operationEmulation(
                of: tonTransfer(amount: 5_000_000_000, isMax: isMax, memo: "deposit 42"),
                feeAsset: ton.toAsset(),
                from: MultichainWalletAddress(chain: .ton, address: Self.tonSender, type: .tonV4R2),
                to: Self.tonRecipient,
                intent: .send(5_000_000_000, of: Self.ton, to: Self.tonRecipient),
                wallet: wallet()
            ) { _, _ in
                (FeeValue(asset: ton.toAsset(), amount: BignumBigInteger(long: 4_000_000)), Self.reserve(isMax ? 4_996_000_000 : 5_000_000_000, adjusted: isMax))
            }

            let meta = try XCTUnwrap(emulation.operation?.signable.operation.payloads.first?.meta as? PayloadMetaTonMain)
            XCTAssertEqual(meta.comment, "deposit 42")
            XCTAssertEqual(meta.mode?.intValue, isMax ? Int(128) : nil)
            XCTAssertEqual(meta.value.description, isMax ? "0" : "5000000000")
            XCTAssertEqual(emulation.adjustedAmount, isMax ? BigUInt(4_996_000_000) : nil)
        }
    }

    /// An emulation the gas reserve found short is never unlocked for or signed, whatever operation it
    /// carries: the SDK's send refuses the same shortage.
    func test_anOperationPricedShortOfItsFeeIsNeitherUnlockedForNorSigned() async throws {
        let service = makeService()
        let operation = try await priced(Self.eth, amount: 1_000_000_000, service: service)
        let short = MultichainTransactionEmulationResult(
            fee: 105_000_000_000_000,
            asset: Self.eth,
            adjustedAmount: nil,
            isMaxAmount: false,
            isInsufficientBalance: true,
            review: nil,
            operation: operation
        )

        do {
            _ = try await service.sendOperationTransfer(short, wallet: wallet(), passcodeProvider: { [taken] in
                await taken.take(.unlock)
                return nil
            }, consent: .refuse)
            XCTFail("expected the shortage to stop the send")
        } catch {
            guard case .emulationFailure(.chainError(.insufficientBalance, _)) = error else {
                return XCTFail("expected a shortage, got \(error.logDescription)")
            }
        }
        let took = await taken.all
        XCTAssertEqual(took, [])
    }

    /// Once the passcode released the payment, closing the screen does not stop it: the send runs to its
    /// end out of reach of the cancellation, as the SDK's send does.
    func test_aPaymentTheUnlockReleasedIsSentWhenTheScreenIsClosed() async throws {
        let service = makeService()
        let operation = try await priced(Self.eth, amount: 1_000_000_000, service: service)
        let wallet = try unlocked()
        let steps = ChainKitServiceImplementation.OperationSteps(
            unlock: {
                _ = withUnsafeCurrentTask { $0?.cancel() }
                return wallet
            },
            send: { _, _, _, _ in
                Task.isCancelled ? [] : ["0xsent"]
            }
        )

        let sending = Task {
            try await service.send(operation, consent: .refuse, steps: steps)
        }
        let hashes = try await sending.value

        XCTAssertEqual(hashes, ["0xsent"], "the send ran cancelled")
    }

    /// An encrypted comment is priced and reviewed as chain-kit's stand-in of its size; once the wallet is
    /// unlocked the comment is encrypted into its place, and the recipient reads what went out.
    func test_anEncryptedCommentIsPricedAsItsStandInAndSignedEncrypted() async throws {
        let service = makeService()
        let unlocked = try unlocked()
        let (comment, recipientKeys) = try encryptedComment("deposit 42")
        let priced = BodyRecord()

        let emulation = try await service.operationEmulation(
            of: tonTransfer(amount: 5_000_000_000, isMax: false, memo: nil, from: tonSender(unlocked)),
            feeAsset: MultichainChain.ton.asChainKitChain.toAsset(),
            from: tonAddress(unlocked),
            to: Self.tonRecipient,
            intent: .send(5_000_000_000, of: Self.ton, to: Self.tonRecipient),
            wallet: wallet(),
            encryptedComment: comment
        ) { payload, _ in
            await priced.record((payload.meta as? PayloadMetaTonMain)?.body)
            return (Self.tonFee, Self.reserve(5_000_000_000))
        }
        let operation = try XCTUnwrap(emulation.operation)
        let standIn = try XCTUnwrap(operation.signable.operation.payloads.first?.meta as? PayloadMetaTonMain)
        let signed = BodyRecord()
        let hashes = try await service.send(operation, consent: .refuse, steps: ChainKitServiceImplementation.OperationSteps(
            unlock: { unlocked },
            send: { operation, _, _, _ in
                await signed.record(operation)
                return ["0xsent"]
            }
        ))

        XCTAssertEqual(hashes, ["0xsent"])
        XCTAssertNil(standIn.comment)
        XCTAssertNotNil(standIn.body)
        let pricedBodies = await priced.bodies
        XCTAssertEqual(pricedBodies, [standIn.body], "the fee is priced for the stand-in")
        let sent = await signed.operations
        let main = try XCTUnwrap(sent.first?.payloads.first?.meta as? PayloadMetaTonMain)
        XCTAssertNil(main.comment)
        XCTAssertNotEqual(main.body, standIn.body)
        XCTAssertEqual(main.to.display, standIn.to.display)
        XCTAssertEqual(main.value.description, "5000000000")
        XCTAssertEqual(sent.first?.id, operation.signable.operation.id)
        let read = try CommentDecryptor(
            privateKey: recipientKeys.privateKey,
            publicKey: recipientKeys.publicKey,
            cipherText: Self.cipherText(of: XCTUnwrap(main.body)),
            senderAddress: TonSwift.Address.parse(tonSender(unlocked))
        ).decrypt()
        XCTAssertEqual(read, "deposit 42")
    }

    /// What the comment encrypts into is held to what the user read on the stand-in: a danger of a kind
    /// that review did not show stops the send once unlocked, and nothing is signed.
    func test_anEncryptedCommentThatShowsAnUnreadDangerIsNeverSigned() async throws {
        let standInBody = StandInBody()
        checks = [DangerOnceEncrypted(standIn: standInBody)]
        let service = makeService()
        let unlocked = try unlocked()
        let operation = try await encryptedPriced(service: service, unlocked: unlocked)
        await standInBody.hold((operation.signable.operation.payloads.first?.meta as? PayloadMetaTonMain)?.body)

        do {
            _ = try await service.send(operation, consent: .refuse, steps: taken.steps(unlocking: unlocked))
            XCTFail("expected the unread danger to stop the send")
        } catch {
            guard case .internal = error else {
                return XCTFail("expected the danger to fail the send as no cancellation, got \(error.logDescription)")
            }
        }

        let took = await taken.all
        XCTAssertEqual(took, [.unlock])
    }

    /// A danger the user read on the stand-in and accepted on the swipe is the danger the encrypted comment
    /// shows too: the send goes out without asking again.
    func test_aDangerReadOnTheStandInLetsTheEncryptedCommentGoOut() async throws {
        checks = [Verdict { ValidationError.ForeignRecipient(payloadId: $0.operation.id, expected: Self.tonRecipient, actual: Self.foreign) }]
        let service = makeService()
        let unlocked = try unlocked()
        let operation = try await encryptedPriced(service: service, unlocked: unlocked)
        let user = ConsentingUser(answering: true) { [taken] in await taken.take(.ask) }

        let hashes = try await service.send(operation, consent: user.attempt(), steps: taken.steps(unlocking: unlocked))

        XCTAssertEqual(hashes, ["0xsent"])
        let asked = await user.asked
        XCTAssertEqual(asked.count, 1, "asked once, on the swipe")
        let took = await taken.all
        XCTAssertEqual(took.first, .ask)
        XCTAssertEqual(took.count, 3)
    }

    /// What the encrypted comment is held to is what the user accepted on the swipe, even where the preview
    /// before it missed the danger: it goes out without asking again.
    func test_aDangerAcceptedOnTheSwipeLetsTheEncryptedCommentGoOutThoughThePreviewMissedIt() async throws {
        checks = [DangerAfterFirstRead(expected: Self.tonRecipient, actual: Self.foreign)]
        let service = makeService()
        let unlocked = try unlocked()
        let operation = try await encryptedPriced(service: service, unlocked: unlocked)
        let user = ConsentingUser(answering: true) { [taken] in await taken.take(.ask) }

        let hashes = try await service.send(operation, consent: user.attempt(), steps: taken.steps(unlocking: unlocked))

        XCTAssertEqual(hashes, ["0xsent"])
        let asked = await user.asked
        XCTAssertEqual(asked.count, 1, "asked once, on the swipe")
    }

    /// Another danger of a kind the user accepted on the swipe, here another foreign recipient, is not what
    /// the user accepted: the encrypted comment stops the send once unlocked, and nothing is signed.
    func test_anotherDangerOfAnAcceptedKindStopsTheEncryptedComment() async throws {
        let standInBody = StandInBody()
        checks = [ForeignRecipientByBody(standIn: standInBody, expected: Self.tonRecipient, standInRecipient: Self.foreign, encryptedRecipient: Self.otherForeign)]
        let service = makeService()
        let unlocked = try unlocked()
        let operation = try await encryptedPriced(service: service, unlocked: unlocked)
        await standInBody.hold((operation.signable.operation.payloads.first?.meta as? PayloadMetaTonMain)?.body)
        let user = ConsentingUser(answering: true) { [taken] in await taken.take(.ask) }

        do {
            _ = try await service.send(operation, consent: user.attempt(), steps: taken.steps(unlocking: unlocked))
            XCTFail("expected another foreign recipient to stop the send")
        } catch {
            guard case .internal = error else {
                return XCTFail("expected the danger to fail the send as no cancellation, got \(error.logDescription)")
            }
        }

        let took = await taken.all
        XCTAssertEqual(took, [.ask, .unlock])
    }

    func test_chainKitsFailuresAreTheOnesTheSendShows() {
        guard case .canceled = ChainKitServiceImplementation.sendFailure(CancellationError()) else {
            return XCTFail("expected a cancelled task to be the user's cancellation")
        }
        guard case .failedToSendSigned(.insufficientBalance, _) = ChainKitServiceImplementation.sendFailure(ChainKitOperationError.insufficientFunds(payloadId: "main")) else {
            return XCTFail("expected a refusal for want of funds to read as a shortage")
        }
        guard case .failedToEstimateNonce(.unknown, _) = ChainKitServiceImplementation.sendFailure(ChainKitOperationError.nonceUnavailable("timeout")) else {
            return XCTFail("expected an unread nonce to fail the preparation")
        }
        guard case .failedToSign(.unknown, _) = ChainKitServiceImplementation.sendFailure(ChainKitOperationError.signingFailed(payloadId: "main", reason: "refused")) else {
            return XCTFail("expected a refused signature to fail the signing")
        }
        guard case .failedToSendSigned(.unknown, _) = ChainKitServiceImplementation.sendFailure(
            ChainKitOperationError.broadcastFailed(payloadId: "main", sent: [], reason: "nonce too low")
        ) else {
            return XCTFail("expected a refused broadcast to fail the send")
        }
        guard case .internal = ChainKitServiceImplementation.sendFailure(ChainKitOperationError.keyMismatch(expected: "a", unlocked: "b")) else {
            return XCTFail("expected anything else to fail as no cancellation")
        }
    }

    /// The node's or the signer's own kind of failure is what the send shows, as the SDK's send shows it.
    func test_chainKitsKindOfFailureIsKept() {
        guard case .failedToEstimateNonce(.networkError, _) = ChainKitServiceImplementation.sendFailure(
            ChainKitOperationError.nonceUnavailable("offline", kind: .networkError)
        ) else {
            return XCTFail("expected an unreachable node to read as a network failure")
        }
        guard case .failedToSign(.verificationFailed, _) = ChainKitServiceImplementation.sendFailure(
            ChainKitOperationError.signingFailed(payloadId: "main", reason: "refused", kind: .verificationFailed)
        ) else {
            return XCTFail("expected the signer's kind of refusal")
        }
        guard case .failedToSendSigned(.noAvailableNodes, _) = ChainKitServiceImplementation.sendFailure(
            ChainKitOperationError.broadcastFailed(payloadId: "main", sent: [], reason: "no nodes", kind: .noAvailableNodes)
        ) else {
            return XCTFail("expected a broadcast with no node to read as such")
        }
    }
}

private extension ChainKitOperationTransferTests {
    static func reserve(_ amount: BigUInt, adjusted: Bool = false) -> GasReserveResult {
        GasReserveResult(
            amount: BignumBigInteger.Companion.shared.parseString(string: amount.description, base: 10),
            isAmountAdjusted: adjusted,
            error: nil
        )
    }

    func makeService() -> ChainKitServiceImplementation {
        ChainKitServiceImplementation(
            supportedChains: [.eth, .ton],
            mnemonicAccess: .inMemory(seed: "chain-kit-operation-transfer"),
            client: client,
            gate: OperationGate { [checks] in checks }
        )
    }

    func sender(storing key: MultichainPublicKey? = ChainKitOperationTransferTests.storedKey) -> MultichainWalletAddress {
        MultichainWalletAddress(chain: .eth, address: Self.sender, publicKey: key)
    }

    func unlocked() throws -> MnemonicWallet {
        try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: Self.mnemonic)
    }

    func wallet() -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: .init(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)),
            metaData: .init(label: "Test wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: .init(isSetupFinished: true),
            batterySettings: .init(),
            multichain: .multichain(MultichainWalletState(walletId: "multichain-wallet-id", addresses: [sender()]))
        )
    }

    func chainKitAsset(_ asset: MultichainAssetDetails) throws -> ChainKit.Asset {
        try XCTUnwrap(AssetCompanion.shared.fromString(
            assetId: asset.assetId,
            name: asset.name,
            symbol: asset.symbol,
            decimals: Int32(asset.decimals)
        ))
    }

    /// The transfer as the SDK takes it, from `address` holding `asset` with the key it stored.
    func transfer(
        of asset: ChainKit.Asset,
        amount: BigUInt,
        isMax: Bool = false,
        from address: MultichainWalletAddress? = nil,
        to recipient: String = ChainKitOperationTransferTests.recipient
    ) throws -> TransactionTransfer {
        let chain = MultichainChain.eth.asChainKitChain
        let source = address ?? sender()
        return try TransactionTransfer(
            account: ChainKit.Account(
                address: XCTUnwrap(Address.Companion.shared.from(value: source.address, chain: chain, type: .default_)),
                asset: asset,
                derivation: DerivationDefaultPath.shared,
                publicKey: source.publicKey?.chainKitPubKey
            ),
            amount: BignumBigInteger.Companion.shared.parseString(string: amount.description, base: 10),
            isMax: isMax,
            to: XCTUnwrap(Address.Companion.shared.from(value: recipient, chain: chain, type: .default_)),
            memo: nil,
            payload: nil
        )
    }

    func emulation(
        of asset: MultichainAssetDetails,
        amount: BigUInt,
        from address: MultichainWalletAddress? = nil,
        to recipient: String = ChainKitOperationTransferTests.recipient,
        service: ChainKitServiceImplementation
    ) async throws -> MultichainTransactionEmulationResult {
        let source = address ?? sender()
        return try await service.operationEmulation(
            of: transfer(of: chainKitAsset(asset), amount: amount, from: source, to: recipient),
            feeAsset: MultichainChain.eth.asChainKitChain.toAsset(),
            from: source,
            to: recipient,
            intent: .send(amount, of: asset, to: recipient),
            wallet: wallet()
        ) { _, _ in
            (Self.fee, Self.reserve(amount))
        }
    }

    /// `asset` sent as chain-kit's operation, priced at `fee`.
    func priced(
        _ asset: MultichainAssetDetails,
        amount: BigUInt,
        from address: MultichainWalletAddress? = nil,
        to recipient: String = ChainKitOperationTransferTests.recipient,
        service: ChainKitServiceImplementation
    ) async throws -> PricedOperation {
        let emulation = try await emulation(of: asset, amount: amount, from: address, to: recipient, service: service)
        return try XCTUnwrap(emulation.operation)
    }

    /// The send of `operation` from the sender's account of `asset`, holding the unlocked key, at `fee`:
    /// the very fee the chain priced, unless a test names the one it expects instead.
    func sent(_ operation: PricedOperation, asset: String, fee: AnyObject = ChainKitOperationTransferTests.fee) throws -> OperationTaken.Step {
        try .send(
            meta: operation.signable.operation.meta,
            address: Self.sender.lowercased(),
            asset: asset,
            key: unlocked().getPublicKey(chain: MultichainChain.eth.asChainKitChain).defaultHex,
            fee: ObjectIdentifier(fee)
        )
    }

    /// The TON coin sent from the wallet's v4R2 address, as the SDK takes it.
    func tonTransfer(amount: BigUInt, isMax: Bool, memo: String?, from sender: String = ChainKitOperationTransferTests.tonSender) throws -> TransactionTransfer {
        let ton = MultichainChain.ton.asChainKitChain
        return try TransactionTransfer(
            account: ChainKit.Account(
                address: XCTUnwrap(Address.Companion.shared.from(value: sender, chain: ton, type: .tonv4r2)),
                asset: ton.toAsset(),
                derivation: DerivationDefaultPath.shared,
                publicKey: nil
            ),
            amount: BignumBigInteger.Companion.shared.parseString(string: amount.description, base: 10),
            isMax: isMax,
            to: XCTUnwrap(Address.Companion.shared.from(value: Self.tonRecipient, chain: ton, type: .default_)),
            memo: memo,
            payload: nil
        )
    }

    /// The v4R2 address the phrase holds its TON at.
    func tonSender(_ unlocked: MnemonicWallet) -> String {
        unlocked.getAddress(chain: MultichainChain.ton.asChainKitChain, type: .tonv4r2).display
    }

    /// That address with the key the wallet stored for it, which the encrypted comment's stand-in reads.
    func tonAddress(_ unlocked: MnemonicWallet) -> MultichainWalletAddress {
        let key = unlocked.getPublicKey(chain: MultichainChain.ton.asChainKitChain)
        return MultichainWalletAddress(
            chain: .ton,
            address: tonSender(unlocked),
            type: .tonV4R2,
            publicKey: MultichainPublicKey(defaultHex: key.defaultHex, segWit: key.segWit)
        )
    }

    /// `text` encrypted to the keys the app derives for another phrase, and those keys.
    func encryptedComment(_ text: String) throws -> (MultichainEncryptedComment, TonSwift.KeyPair) {
        let keys = try CoreMnemonic(mnemonicWords: Self.recipientMnemonic.components(separatedBy: " "), type: .bip39).toKeyPair()
        return try (XCTUnwrap(MultichainEncryptedComment(text: text, key: keys.publicKey.data.hexDigits)), keys)
    }

    /// 5 TON with an encrypted comment, priced as its stand-in.
    func encryptedPriced(service: ChainKitServiceImplementation, unlocked: MnemonicWallet) async throws -> PricedOperation {
        let (comment, _) = try encryptedComment("deposit 42")
        let emulation = try await service.operationEmulation(
            of: tonTransfer(amount: 5_000_000_000, isMax: false, memo: nil, from: tonSender(unlocked)),
            feeAsset: MultichainChain.ton.asChainKitChain.toAsset(),
            from: tonAddress(unlocked),
            to: Self.tonRecipient,
            intent: .send(5_000_000_000, of: Self.ton, to: Self.tonRecipient),
            wallet: wallet(),
            encryptedComment: comment
        ) { _, _ in
            (Self.tonFee, Self.reserve(5_000_000_000))
        }
        return try XCTUnwrap(emulation.operation)
    }

    /// The hex the history reads an encrypted comment as, `cipher_text` as tonapi reads it: the bytes that
    /// follow the opcode, down the chain of cells however full each one is.
    static func cipherText(of body: String) throws -> String {
        let slice = try TonSwift.Cell.fromBase64(src: body).beginParse()
        XCTAssertEqual(try slice.loadUint(bits: 32), 0x2167_DA4B, "the encrypted comment's opcode")
        return try bytes(of: slice).hexDigits
    }

    static func bytes(of slice: TonSwift.Slice) throws -> Data {
        var data = try slice.loadBytes(slice.remainingBits / 8)
        if slice.remainingRefs > 0 {
            try data.append(bytes(of: slice.loadRef().beginParse()))
        }
        return data
    }

    /// The coin an EVM payload moves, which is what its amount is for a coin send.
    static func value(of payload: Payload) -> String? {
        (payload.meta as? PayloadMetaEvmMain)?.value.description
    }
}

/// chain-kit answering `error` about what it reads, rated as the check rates that answer.
private struct Verdict: OperationCheck {
    let error: @Sendable (SignableOperation) -> ValidationError

    func findings(of signable: SignableOperation) throws -> [OperationFinding] {
        try ChainKitValidationCheck.findings([error(signable)], of: signable, intent: ChainKitValidationCheck.intent(of: signable))
    }
}

/// The payloads priced, the accounts they were priced from and the coin they move.
private actor PricingRecord {
    struct Priced: Equatable {
        let payload: String
        let account: String
        let asset: String
        let value: String?
    }

    private(set) var all = [Priced]()

    func record(payload: String, account: String, asset: String, value: String?) {
        all.append(Priced(payload: payload, account: account, asset: asset, value: value))
    }
}

/// What a reviewed operation went through, in order, the user's question among them: the unlock and
/// the send, recorded instead of taken.
private actor OperationTaken {
    enum Step: Equatable {
        case ask
        case unlock
        /// The operation's payloads, the address, asset and key of the account and the fee it was signed from and at.
        case send(meta: String, address: String, asset: String, key: String?, fee: ObjectIdentifier)
    }

    private(set) var all = [Step]()

    nonisolated func steps(unlocking wallet: MnemonicWallet) -> ChainKitServiceImplementation.OperationSteps {
        ChainKitServiceImplementation.OperationSteps(
            unlock: {
                await self.take(.unlock)
                return wallet
            },
            send: { operation, account, _, fee in
                await self.take(.send(
                    meta: operation.meta,
                    address: account.addressDisplay.lowercased(),
                    asset: account.asset.id,
                    key: account.publicKey?.defaultHex,
                    fee: ObjectIdentifier(fee as AnyObject)
                ))
                return ["0xsent"]
            }
        )
    }

    func take(_ step: Step) {
        all.append(step)
    }
}

/// The bodies of the TON sends priced, and the operations signed.
private actor BodyRecord {
    private(set) var bodies = [String?]()
    private(set) var operations = [ChainKit.Operation]()

    func record(_ body: String?) {
        bodies.append(body)
    }

    func record(_ operation: ChainKit.Operation) {
        operations.append(operation)
    }
}

/// The stand-in's body, once the test knows it.
private actor StandInBody {
    private(set) var body: String?

    func hold(_ body: String?) {
        self.body = body
    }
}

/// Finds a danger in a TON send that carries a body other than the stand-in's, and nothing before the
/// stand-in is known.
private struct DangerOnceEncrypted: OperationCheck {
    let standIn: StandInBody

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        guard let standInBody = await standIn.body,
              let body = (signable.operation.payloads.first?.meta as? PayloadMetaTonMain)?.body,
              body != standInBody
        else {
            return []
        }
        let danger = ValidationError.ForeignRecipient(payloadId: signable.operation.id, expected: "stand-in", actual: "encrypted")
        return try ChainKitValidationCheck.findings([danger], of: signable, intent: ChainKitValidationCheck.intent(of: signable))
    }
}

/// Finds nothing the first time it reads, as a preview that missed the danger, and a foreign recipient
/// every time after.
private struct DangerAfterFirstRead: OperationCheck {
    private actor Reads {
        private var count = 0

        func next() -> Int {
            count += 1
            return count
        }
    }

    let expected: String
    let actual: String
    private let reads = Reads()

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        guard await reads.next() > 1 else {
            return []
        }
        let danger = ValidationError.ForeignRecipient(payloadId: signable.operation.id, expected: expected, actual: actual)
        return try ChainKitValidationCheck.findings([danger], of: signable, intent: ChainKitValidationCheck.intent(of: signable))
    }
}

/// Finds a foreign recipient in a TON send: `standInRecipient` while it carries the stand-in's body or
/// before that body is known, `encryptedRecipient` once it carries another.
private struct ForeignRecipientByBody: OperationCheck {
    let standIn: StandInBody
    let expected: String
    let standInRecipient: String
    let encryptedRecipient: String

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        let body = (signable.operation.payloads.first?.meta as? PayloadMetaTonMain)?.body
        let standInBody = await standIn.body
        let actual = standInBody == nil || body == standInBody ? standInRecipient : encryptedRecipient
        let danger = ValidationError.ForeignRecipient(payloadId: signable.operation.id, expected: expected, actual: actual)
        return try ChainKitValidationCheck.findings([danger], of: signable, intent: ChainKitValidationCheck.intent(of: signable))
    }
}

private extension Data {
    var hexDigits: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
