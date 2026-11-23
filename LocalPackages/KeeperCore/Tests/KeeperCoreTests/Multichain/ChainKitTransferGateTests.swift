@preconcurrency import BigInt
import ChainKit
@testable import KeeperCore
@testable import KeeperCoreComponents
import KeeperCoreSensitive
import OperationReviewModels
import XCTest

/// The review of a send the SDK signs, a copy built from the inputs its intent is: the preview the
/// emulation makes and the gate right before the signature read it, and what they find is only
/// logged, under the send's name. Nothing they find or fail at asks, or stops the transfer.
final class ChainKitTransferGateTests: XCTestCase {
    private static let sender = "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
    private static let recipient = "0x8ba1f109551bd432803012645ac136ddd64dba72"
    private static let foreign = "0x00000000000000000000000000000000000000aa"
    /// The key the wallet stored for the address, and another one standing for the unlocked key.
    private static let storedKey = PubKey(defaultHex: "0x0237b0bb7a8288d38ed49a524b5dc98cff3eb5ca824c9f9dc0dfdb3d9cd600f299", segWit: "")
    private static let unlockedKey = PubKey(defaultHex: "0x03aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", segWit: "")
    private static let eth = MultichainAssetDetails(assetId: "eth/mainnet/coin", name: "Ethereum", symbol: "ETH", decimals: 18, image: "")
    private static let intent = OperationIntent.send(1_000_000_000, of: eth, to: recipient)
    private static let file = "KeeperCore/ChainKitServiceImplementation.swift"

    private var checks = [any OperationCheck]()
    private let steps = TakenSteps()
    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    func test_withoutChecksNothingIsReviewedAndTheTransferIsSignedAndSent() async throws {
        let service = makeService()
        let transfer = try transfer(amount: 1_000_000_000, key: Self.unlockedKey)

        let preview = await service.preview(transfer, from: sender, to: Self.recipient, intent: Self.intent)
        let hashes = try await service.signAndSend(transfer, from: sender, to: Self.recipient, intent: Self.intent, consent: .refuse, steps: steps.taken)

        XCTAssertNil(preview)
        XCTAssertEqual(hashes, ["0xsent"])
        let taken = await steps.all
        XCTAssertEqual(taken, [.nonce, .sign(amount: "1000000000"), .broadcast])
    }

    /// chain-kit holds the copy to another recipient than the one it pays: the danger it finds tints
    /// nothing, asks nothing and stops nothing, and both reviews log it as the send's.
    func test_aCopyChainKitFlagsIsOnlyLoggedAndTheTransferIsSignedAndSent() async throws {
        checks = [ChainKitValidationCheck(client: client)]
        let service = makeService()
        let agreed = OperationIntent.send(1_000_000_000, of: Self.eth, to: Self.foreign)
        let user = ConsentingUser(answering: false)
        let log = RecordedLog()
        defer { log.stop() }

        let preview = try await service.preview(transfer(amount: 1_000_000_000, key: Self.storedKey), from: sender, to: Self.recipient, intent: agreed)
        let hashes = try await service.signAndSend(
            transfer(amount: 1_000_000_000, key: Self.unlockedKey),
            from: sender,
            to: Self.recipient,
            intent: agreed,
            consent: user.attempt(),
            steps: steps.taken
        )
        let logged = try await log.records("Operation review found what would ask in a flow it only logs", count: 2)

        XCTAssertNil(preview)
        let asked = await user.asked
        XCTAssertEqual(asked, [])
        XCTAssertEqual(hashes, ["0xsent"])
        let taken = await steps.all
        XCTAssertEqual(taken, [.nonce, .sign(amount: "1000000000"), .broadcast])
        XCTAssertEqual(logged.map(\.severity), [.error, .error])
        XCTAssertEqual(logged.map { $0.extraInfo["findings"] }, Array(repeating: "danger:ChainKitValidationErrorForeignRecipient", count: 2))
        XCTAssertEqual(logged.map { $0.extraInfo["assets"] }, ["eth/mainnet/coin", "eth/mainnet/coin"])
        XCTAssertEqual(logged.map { $0.extraInfo["fidelity"] }, ["converted", "converted"])
        XCTAssertEqual(logged.map(\.file), [Self.file, Self.file])
    }

    /// chain-kit answers that it read nothing: in the wallet's own send that is info no one sees, so
    /// the log names the send it failed for.
    func test_aValidatorThatReadNothingIsLoggedAsTheSends() async throws {
        checks = [UnsupportedChainCheck()]
        let service = makeService()
        let log = RecordedLog()
        defer { log.stop() }

        _ = try await service.signAndSend(
            transfer(amount: 1_000_000_000, key: Self.unlockedKey),
            from: sender,
            to: Self.recipient,
            intent: Self.intent,
            consent: .refuse,
            steps: steps.taken
        )
        _ = try await log.records("Operation validation read nothing", count: 1)

        XCTAssertEqual(log.errors.map(\.message), ["Operation validation read nothing"])
        XCTAssertEqual(log.errors.map(\.file), [Self.file])
        XCTAssertEqual(log.errors.map { $0.extraInfo["operation"] }, ["transfer"])
        XCTAssertEqual(log.errors.map { $0.extraInfo["asset"] }, ["eth/mainnet/coin"])
        let taken = await steps.all
        XCTAssertEqual(taken, [.nonce, .sign(amount: "1000000000"), .broadcast])
    }

    /// The copy is read from the account of the address it is sent from, with the key that address
    /// stored rather than the one unlocked to sign: once ChainKit sends ask, the preview and the gate
    /// read one transfer as one review. It is held to the intent, and a consent that would refuse is
    /// never asked.
    func test_theCopyIsReadFromTheKeyTheSendersAddressStoredAndNoOneIsAsked() async throws {
        let check = WarningCheck()
        let keys = KeyCheck()
        checks = [check, keys]
        let service = makeService()
        let user = ConsentingUser(answering: false) { [steps] in await steps.take(.ask) }
        let log = RecordedLog()
        defer { log.stop() }

        _ = try await service.preview(transfer(amount: 1_000_000_000, key: Self.storedKey), from: sender, to: Self.recipient, intent: Self.intent)
        _ = try await service.signAndSend(
            transfer(amount: 1_000_000_000, key: Self.unlockedKey),
            from: sender,
            to: Self.recipient,
            intent: Self.intent,
            consent: user.attempt(),
            steps: steps.taken
        )
        _ = try await log.records("Operation review found what would ask in a flow it only logs", count: 2)

        let taken = await steps.all
        XCTAssertEqual(taken, [.nonce, .sign(amount: "1000000000"), .broadcast])
        let reads = await check.reads.all
        let coin = MultichainChain.eth.asChainKitChain.toAsset().id
        let read = WarningCheck.Read(address: Self.sender.lowercased(), assetId: coin, intent: Self.intent)
        XCTAssertEqual(reads, [read, read], "the preview's and the gate's")
        let keysRead = await keys.read.all
        XCTAssertEqual(keysRead, [Self.storedKey.defaultHex, Self.storedKey.defaultHex])
    }

    func test_aTransferNoCheckCouldReadIsLoggedAndStillSignedAndSent() async throws {
        checks = [FailingCheck()]
        let service = makeService()
        let log = RecordedLog()
        defer { log.stop() }

        let hashes = try await service.signAndSend(
            transfer(amount: 1_000_000_000, key: Self.unlockedKey),
            from: sender,
            to: Self.recipient,
            intent: Self.intent,
            consent: ConsentingUser(answering: true).attempt(),
            steps: steps.taken
        )
        _ = try await log.records("Operation review could not check what is signed", count: 1)

        XCTAssertEqual(hashes, ["0xsent"])
        let taken = await steps.all
        XCTAssertEqual(taken, [.nonce, .sign(amount: "1000000000"), .broadcast])
        XCTAssertEqual(log.errors.map(\.message), ["Operation review could not check what is signed"])
        XCTAssertEqual(log.errors.map(\.file), [Self.file])
    }

    /// A gate that validates with chain-kit reads the boot configuration at every review: while it
    /// turns validation off no copy is built, so not even one that cannot be built is noticed.
    func test_whileValidationIsOffNoCopyIsBuilt() async throws {
        let configuration = KeeperCore.Configuration.review(validates: false, thenValidates: true)
        let service = makeService(gate: OperationGate(configuration: configuration, validatingWith: client))
        let log = RecordedLog()
        defer { log.stop() }
        // No copy can be built of a send to it, and a copy that fails to build is logged.
        let unreadable = "not an address"

        let preview = try await service.preview(transfer(amount: 1_000_000_000, key: Self.storedKey), from: sender, to: unreadable, intent: Self.intent)
        _ = try await service.signAndSend(
            transfer(amount: 1_000_000_000, key: Self.unlockedKey),
            from: sender,
            to: unreadable,
            intent: Self.intent,
            consent: .refuse,
            steps: steps.taken
        )
        XCTAssertNil(preview)
        XCTAssertEqual(log.records.map(\.message), [])

        _ = await configuration.loadConfigurations()
        _ = try await service.preview(transfer(amount: 1_000_000_000, key: Self.storedKey), from: sender, to: unreadable, intent: Self.intent)
        XCTAssertEqual(log.errors.map(\.message), ["Operation review could not build what is signed"])
    }
}

private extension ChainKitTransferGateTests {
    var sender: MultichainWalletAddress {
        MultichainWalletAddress(
            chain: .eth,
            address: Self.sender,
            publicKey: MultichainPublicKey(defaultHex: Self.storedKey.defaultHex, segWit: Self.storedKey.segWit)
        )
    }

    func makeService(gate: OperationGate? = nil) -> ChainKitServiceImplementation {
        ChainKitServiceImplementation(
            supportedChains: [.eth],
            mnemonicAccess: .inMemory(seed: "chain-kit-transfer-gate"),
            client: client,
            gate: gate ?? OperationGate { [checks] in checks }
        )
    }

    /// The transfer as the SDK takes it, held by an account with `key`.
    func transfer(amount: BigUInt, key: PubKey) throws -> TransactionTransfer {
        let chain = MultichainChain.eth.asChainKitChain
        let address = try XCTUnwrap(Address.Companion.shared.from(value: Self.sender, chain: chain, type: .default_))
        let recipient = try XCTUnwrap(Address.Companion.shared.from(value: Self.recipient, chain: chain, type: .default_))
        return TransactionTransfer(
            account: ChainKit.Account(address: address, asset: chain.toAsset(), derivation: DerivationDefaultPath.shared, publicKey: key),
            amount: BignumBigInteger.Companion.shared.parseString(string: amount.description, base: 10),
            isMax: false,
            to: recipient,
            memo: nil,
            payload: nil
        )
    }
}

/// chain-kit answering that it has no validator for the chain, as the check reads that answer.
private struct UnsupportedChainCheck: OperationCheck {
    func findings(of signable: SignableOperation) throws -> [OperationFinding] {
        try ChainKitValidationCheck.findings(
            [ValidationError.UnsupportedChain(chain: "eth/mainnet")],
            of: signable,
            intent: ChainKitValidationCheck.intent(of: signable)
        )
    }
}

/// Finds nothing, and keeps the key of the account it read each operation from.
private struct KeyCheck: OperationCheck {
    actor Keys {
        private(set) var all = [String?]()

        func append(_ key: String?) {
            all.append(key)
        }
    }

    let read = Keys()

    func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
        await read.append(signable.account.publicKey?.defaultHex)
        return []
    }
}

/// The steps a transfer took after its review, in order, the user's question among them: the node's
/// nonce, the signature of the amount signed and the broadcast, recorded instead of taken.
private actor TakenSteps {
    enum Step: Equatable {
        case ask
        case nonce
        case sign(amount: String)
        case broadcast
    }

    private(set) var all = [Step]()

    nonisolated var taken: ChainKitServiceImplementation.TransferSteps {
        ChainKitServiceImplementation.TransferSteps(
            nonce: { _ in
                await self.take(.nonce)
                return BignumBigInteger.Companion.shared.parseString(string: "7", base: 10)
            },
            sign: { transfer, _ in
                await self.take(.sign(amount: transfer.amount.description))
                return [KotlinByteArray(size: 1)]
            },
            broadcast: { _, _ in
                await self.take(.broadcast)
                return "0xsent"
            }
        )
    }

    func take(_ step: Step) {
        all.append(step)
    }
}
