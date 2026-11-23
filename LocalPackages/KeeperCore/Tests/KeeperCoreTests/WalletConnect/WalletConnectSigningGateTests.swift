import ChainKit
@testable import KeeperCore
@testable import KeeperCoreComponents
import KeeperCoreSensitive
import OperationReviewModels
import TKLogging
import TonSwift
import XCTest

/// The dApp gate in front of a request's signer: it reads the request before the passcode or the
/// device is asked for, and what it refuses is never unlocked or signed.
final class WalletConnectSigningGateTests: XCTestCase {
    private static let evmAddress = "0x9858effd232b4033e47d90003d41ec34ecaeda94"
    private static let evmKey = MultichainPublicKey(defaultHex: "0x0237b0bb7a8288d38ed49a524b5dc98cff3eb5ca824c9f9dc0dfdb3d9cd600f299", segWit: "")

    private let unlocks = Unlocks()
    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    /// A request without a recipient cannot be read, so only a review that was built would fail on it.
    func test_withoutChecksNothingIsBuiltAndTheSignerUnlocksAsBefore() async {
        let request = request(payload: .evmTransaction(transaction(to: nil), send: true), method: .ethSendTransaction)

        let error = await signingError {
            try await self.service(checks: []).sign(signer: self.mnemonic, wallet: self.wallet(), request: request, evmFee: nil, consent: .refuse, isPending: { true })
        }

        XCTAssertEqual(error, .canceled)
        let taken = await unlocks.all
        XCTAssertEqual(taken, ["passcode"])
    }

    func test_aRequestTheReviewCannotReadIsNeverUnlocked() async {
        let unreadable = request(payload: .evmTransaction(transaction(to: nil), send: true), method: .ethSendTransaction)
        let unchecked = request(payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal)), method: .personalSign)

        let unreadableError = await signingError {
            try await self.service(checks: [WarningCheck()]).sign(signer: self.mnemonic, wallet: self.wallet(), request: unreadable, evmFee: nil, consent: .refuse, isPending: { true })
        }
        let uncheckedError = await signingError {
            try await self.service(checks: [FailingCheck()]).sign(signer: self.mnemonic, wallet: self.wallet(), request: unchecked, evmFee: nil, consent: .refuse, isPending: { true })
        }

        XCTAssertEqual(unreadableError, .missingRecipient, "a payload the review cannot build fails for what is wrong with it")
        guard case .unreviewable = uncheckedError else {
            return XCTFail("expected the review failure, got \(String(describing: uncheckedError))")
        }
        let taken = await unlocks.all
        XCTAssertTrue(taken.isEmpty)
    }

    func test_aRefusalIsACancelThatNeverUnlocksTheWalletOrReachesTheDevice() async {
        let check = WarningCheck()
        let user = ConsentingUser(answering: false)
        let message = request(payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal)), method: .personalSign)

        let mnemonicError = await signingError {
            try await self.service(checks: [check]).sign(signer: self.mnemonic, wallet: self.wallet(), request: message, evmFee: nil, consent: user.attempt(), isPending: { true })
        }
        let deviceError = await signingError {
            try await self.service(checks: [check]).sign(signer: .device(self.device), wallet: self.ledgerWallet(), request: message, evmFee: nil, consent: user.attempt(), isPending: { true })
        }

        XCTAssertEqual(mnemonicError, .canceled)
        XCTAssertEqual(deviceError, .canceled)
        let taken = await unlocks.all
        XCTAssertTrue(taken.isEmpty)
        let asked = await user.asked
        XCTAssertEqual(asked.count, 2)
        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.address), [Self.evmAddress, Self.evmAddress])
        XCTAssertEqual(reads.map(\.intent), [.dapp, .dapp])
    }

    func test_theReviewIsAskedBeforeThePasscode() async {
        let user = ConsentingUser(answering: true) { [unlocks] in await unlocks.take("ask") }

        let error = await signingError {
            try await self.service(checks: [WarningCheck()]).sign(
                signer: self.mnemonic,
                wallet: self.wallet(),
                request: self.request(payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal)), method: .personalSign),
                evmFee: nil,
                consent: user.attempt(),
                isPending: { true }
            )
        }

        XCTAssertEqual(error, .canceled)
        let taken = await unlocks.all
        XCTAssertEqual(taken, ["ask", "passcode"])
    }

    /// The checks can take seconds, and a review with nothing to ask passes without the user: the
    /// request is held to still be pending only once they are done.
    func test_aRequestThatEndedWhileItWasReviewedIsNeverUnlocked() async {
        let message = request(payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal)), method: .personalSign)
        let pending = PendingRequest()
        let service = service(checks: [EndingCheck(end: { await pending.end() })])

        let mnemonicError = await signingError {
            try await service.sign(signer: self.mnemonic, wallet: self.wallet(), request: message, evmFee: nil, consent: .refuse, isPending: { await pending.isPending })
        }
        let deviceError = await signingError {
            try await service.sign(signer: .device(self.device), wallet: self.ledgerWallet(), request: message, evmFee: nil, consent: .refuse, isPending: { await pending.isPending })
        }

        XCTAssertEqual(mnemonicError, .canceled)
        XCTAssertEqual(deviceError, .canceled)
        let taken = await unlocks.all
        XCTAssertTrue(taken.isEmpty)
        let stillPending = await signingError {
            try await service.sign(signer: self.mnemonic, wallet: self.wallet(), request: message, evmFee: nil, consent: .refuse, isPending: { true })
        }
        XCTAssertEqual(stillPending, .canceled)
        let takenWhilePending = await unlocks.all
        XCTAssertEqual(takenWhilePending, ["passcode"])
    }

    func test_expiryDuringPasscodeDiscardsTheReturnedPasscode() async throws {
        try await assertPasscodeInterrupted(expire: true)
    }

    func test_cancellationDuringPasscodeStopsAStillPendingRequest() async throws {
        try await assertPasscodeInterrupted(expire: false)
    }

    func test_expiryDuringSigningNeverBroadcastsTheSignedTransaction() async {
        await assertSigningInterrupted(expire: true)
    }

    func test_cancellationDuringSigningNeverBroadcastsAStillPendingRequest() async {
        await assertSigningInterrupted(expire: false)
    }

    func test_expiryDuringBroadcastStillRecordsTheTransactionButDiscardsTheResponse() async {
        let pending = PendingRequest()
        let recorded = RecordedTransactions()
        let context = context(pending: pending, recorded: recorded)

        let error = await signingError {
            try await WalletConnectEVMTransactionSigningUtilities().signAndRespond(
                send: true, chain: .eth, activityType: .contractCall, context: context,
                sign: { () throws(WalletConnectSigningError) in Data([1]).asKotlinByteArray },
                broadcast: { _ throws(WalletConnectSigningError) in
                    await pending.end()
                    return "0xsent"
                }
            )
        }

        XCTAssertEqual(error, .requestEndedAfterBroadcast)
        let count = await recorded.count
        XCTAssertEqual(count, 1, "a broadcast already in flight must remain tracked")
    }

    func test_postBroadcastExpiryRemainsKnownToSubsequentSigningGuards() async {
        for chain in [WalletConnectChain.eth, .sol] {
            let pending = PendingRequest()
            let recorded = RecordedTransactions()
            let context = context(pending: pending, recorded: recorded)
            await context.reportPendingTransaction(chain: chain, txHash: "submitted", activityType: .contractCall)
            await pending.end()

            for _ in 0 ..< 2 {
                let error = await signingError {
                    try await context.checkRequestIsPending()
                    return .null
                }
                XCTAssertEqual(error, .requestEndedAfterBroadcast)
            }
            let count = await recorded.count
            XCTAssertEqual(count, 1)
        }
    }

    func test_aPendingRequestCanSignBroadcastAndRecordItsTransaction() async throws {
        let recorded = RecordedTransactions()
        let context = context(pending: PendingRequest(), recorded: recorded)

        let response = try await WalletConnectEVMTransactionSigningUtilities().signAndRespond(
            send: true, chain: .eth, activityType: .contractCall, context: context,
            sign: { () throws(WalletConnectSigningError) in Data([1]).asKotlinByteArray },
            broadcast: { _ throws(WalletConnectSigningError) in "0xsent" }
        )

        XCTAssertEqual(response, .string("0xsent"))
        let count = await recorded.count
        XCTAssertEqual(count, 1)
    }

    func test_whatEarnSignsIsReviewedButNeverAsked() async throws {
        let check = WarningCheck()
        let log = RecordedLog()
        defer { log.stop() }

        let error = await signingError {
            try await self.service(checks: [check]).signWithoutAsking(
                signer: self.mnemonic,
                wallet: self.wallet(),
                request: self.request(payload: .evmTransaction(self.transaction(to: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"), send: true), method: .ethSendTransaction)
            )
        }
        _ = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)

        XCTAssertEqual(error, .canceled)
        let taken = await unlocks.all
        XCTAssertEqual(taken, ["passcode"])
        let reads = await check.reads.all
        XCTAssertEqual(reads.map(\.intent), [.dapp])
    }

    @MainActor
    func test_theAssemblyValidatesDappRequestsAndReadsTheFlagOnEveryAttempt() async {
        let configuration = KeeperCore.Configuration.review(thenValidates: false)
        let service = assembly(configuration: configuration).walletConnectSigningService
        let message = request(payload: .signMessage(.init(address: nil, message: "0x1234", kind: .personal)), method: .personalSign)
        let user = ConsentingUser(answering: false)
        let preview = await service.review(wallet: wallet(), request: message)

        XCTAssertEqual(preview?.severity, .warning)
        let refused = await signingError {
            try await service.sign(signer: self.mnemonic, wallet: self.wallet(), request: message, evmFee: nil, consent: user.attempt(), isPending: { true })
        }
        XCTAssertEqual(refused, .canceled)
        let before = await unlocks.all
        XCTAssertTrue(before.isEmpty)
        let asked = await user.asked
        XCTAssertEqual(asked.count, 1)
        XCTAssertEqual(asked.first?.findings, preview?.findings)

        _ = await configuration.loadConfigurations()
        let disabledPreview = await service.review(wallet: wallet(), request: message)
        XCTAssertNil(disabledPreview)
        _ = await signingError {
            try await service.sign(signer: self.mnemonic, wallet: self.wallet(), request: message, evmFee: nil, consent: .refuse, isPending: { true })
        }
        let after = await unlocks.all
        XCTAssertEqual(after, ["passcode"])
    }

    /// A transaction without a recipient is no operation: signed as one, it is refused before the
    /// passcode, while the SDK's signer finds out only once it asked for it.
    @MainActor
    func test_theAssemblySignsATransactionAsItsOperationOnlyWhileTheSwitchIsOn() async {
        let sdkService = assembly(configuration: .review(validates: false)).walletConnectSigningService
        let operationService = assembly(configuration: .review(ReviewFlags(signsOperations: true), validates: false)).walletConnectSigningService
        let request = request(payload: .evmTransaction(transaction(to: nil), send: true), method: .ethSendTransaction)

        let bySDK = await signingError {
            try await sdkService.sign(signer: self.mnemonic, wallet: self.wallet(), request: request, evmFee: nil, consent: .refuse, isPending: { true })
        }
        let asOperation = await signingError {
            try await operationService.sign(signer: self.mnemonic, wallet: self.wallet(), request: request, evmFee: nil, consent: .refuse, isPending: { true })
        }

        XCTAssertEqual(bySDK, .canceled)
        XCTAssertEqual(asOperation, .missingRecipient)
        let taken = await unlocks.all
        XCTAssertEqual(taken, ["passcode"])
    }

    func test_aValidationTimeoutReturnsAnUnknownWarningAndLogsTheLimit() async throws {
        let entered = expectation(description: "validation started")
        let finished = expectation(description: "review stopped waiting")
        let pause = Pause()
        let log = RecordedLog()
        defer { log.stop() }
        let service = service(checks: [DappValidationCheck(check: PausedValidation(entered: entered, pause: pause), timeLimit: 0.01)])
        let message = request(payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal)), method: .personalSign)
        let wallet = wallet()
        let work = Task {
            let review = await service.review(wallet: wallet, request: message)
            finished.fulfill()
            return review
        }
        defer { work.cancel() }
        await fulfillment(of: [entered, finished], timeout: 3)
        await pause.release()
        let reviewed = await work.value
        let review = try XCTUnwrap(reviewed)

        XCTAssertEqual(review.severity, .warning)
        XCTAssertTrue(review.requiresConsent)
        XCTAssertEqual(review.findings.count, 1)
        XCTAssertTrue(review.findings[0].kind.contains("Unknown"))
        XCTAssertTrue(review.findings[0].failure?.contains("exceeded 0.01 s") == true)
        let records = try await log.records("Operation validation read nothing", count: 1)
        XCTAssertEqual(records.first?.severity, .error)
    }

    func test_aTimedOutValidationAsksBeforeUnlockAndARefusalSignsNothing() async {
        let entered = expectation(description: "validation started")
        let finished = expectation(description: "refused before late validation")
        let pause = Pause()
        let service = service(checks: [DappValidationCheck(check: PausedValidation(entered: entered, pause: pause), timeLimit: 0.01)])
        let user = ConsentingUser(answering: false)
        let message = request(payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal)), method: .personalSign)
        let wallet = wallet()
        let signer = mnemonic
        let work = Task {
            let error = await signingError {
                try await service.sign(signer: signer, wallet: wallet, request: message, evmFee: nil, consent: user.attempt(), isPending: { true })
            }
            finished.fulfill()
            return error
        }
        defer { work.cancel() }
        await fulfillment(of: [entered, finished], timeout: 3)
        await pause.release()
        let error = await work.value
        XCTAssertEqual(error, .canceled)
        let asked = await user.asked
        XCTAssertEqual(asked.map(\.severity), [.warning])
        let taken = await unlocks.all
        XCTAssertTrue(taken.isEmpty)
    }

    func test_cancellingValidationDoesNotWaitForTheLookupOrAskTheUser() async {
        let entered = expectation(description: "validation started")
        let finished = expectation(description: "cancelled before late validation")
        let pause = Pause()
        let service = service(checks: [DappValidationCheck(check: PausedValidation(entered: entered, pause: pause), timeLimit: 60)])
        let user = ConsentingUser(answering: false)
        let message = request(payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal)), method: .personalSign)
        let wallet = wallet()
        let signer = mnemonic
        let work = Task {
            let error = await signingError {
                try await service.sign(signer: signer, wallet: wallet, request: message, evmFee: nil, consent: user.attempt(), isPending: { true })
            }
            finished.fulfill()
            return error
        }
        await fulfillment(of: [entered], timeout: 3)
        work.cancel()
        await fulfillment(of: [finished], timeout: 3)
        await pause.release()
        let error = await work.value
        XCTAssertEqual(error, .canceled)
        let asked = await user.asked
        XCTAssertTrue(asked.isEmpty)
        let taken = await unlocks.all
        XCTAssertTrue(taken.isEmpty)
    }

    func test_aValidationFailureBeforeTheLimitStillBlocksUnlock() async {
        let service = service(checks: [DappValidationCheck(check: FailingCheck(), timeLimit: 5)])
        let message = request(payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal)), method: .personalSign)
        let error = await signingError {
            try await service.sign(signer: self.mnemonic, wallet: self.wallet(), request: message, evmFee: nil, consent: .refuse, isPending: { true })
        }
        guard case .unreviewable = error else {
            return XCTFail("a failed validation must not become an optional warning: \(String(describing: error))")
        }
        let taken = await unlocks.all
        XCTAssertTrue(taken.isEmpty)
    }

    func test_EarnDoesNotWaitForAnUnfinishedValidation() async throws {
        let entered = expectation(description: "validation started")
        let finished = expectation(description: "Earn reached passcode before validation ended")
        let pause = Pause()
        let log = RecordedLog()
        defer { log.stop() }
        let service = service(checks: [DappValidationCheck(check: PausedValidation(entered: entered, pause: pause), timeLimit: 60)])
        let message = request(payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal)), method: .personalSign)
        let wallet = wallet()
        let signer = mnemonic
        let work = Task {
            let error = await signingError {
                try await service.signWithoutAsking(signer: signer, wallet: wallet, request: message)
            }
            finished.fulfill()
            return error
        }
        defer { work.cancel() }
        await fulfillment(of: [entered, finished], timeout: 3)
        await pause.release()
        let error = await work.value
        XCTAssertEqual(error, .canceled)
        let taken = await unlocks.all
        XCTAssertEqual(taken, ["passcode"])
        _ = try await log.records("Operation review found what would ask in a flow it only logs", count: 1)
    }

    func test_aReviewAcceptedOnThePreviewIsNotAskedAgainWhenSigned() async throws {
        let service = service(checks: [WarningCheck()])
        let request = request(payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal)), method: .personalSign)
        let user = ConsentingUser(answering: true)
        let consent = user.attempt()
        let previewed = await service.review(wallet: wallet(), request: request)
        let preview = try XCTUnwrap(previewed)
        _ = await consent(preview)

        let error = await signingError {
            try await service.sign(signer: self.mnemonic, wallet: self.wallet(), request: request, evmFee: nil, consent: consent, isPending: { true })
        }

        XCTAssertEqual(error, .canceled)
        let asked = await user.asked
        XCTAssertEqual(asked, [preview])
        let taken = await unlocks.all
        XCTAssertEqual(taken, ["passcode"])
    }

    func test_withoutChecksThereIsNoReviewToTintBy() async {
        let request = request(payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal)), method: .personalSign)

        let review = await service(checks: []).review(wallet: wallet(), request: request)

        XCTAssertNil(review)
    }
}

private extension WalletConnectSigningGateTests {
    struct PausedValidation: OperationCheck {
        let entered: XCTestExpectation
        let pause: Pause

        func findings(of signable: SignableOperation) async -> [OperationFinding] {
            entered.fulfill()
            await pause.wait()
            return [OperationFinding(id: signable.operation.id, kind: "LateDanger", severity: .danger, title: "Late result")]
        }
    }

    func assembly(configuration: KeeperCore.Configuration) -> WalletConnectAssembly {
        let cache = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return WalletConnectAssembly(
            mnemonicAccess: makeMnemonicAccess(),
            coreAssembly: CoreAssembly(cacheURL: cache, sharedCacheURL: cache, appInfoProvider: DappAppInfo(), seedProvider: { "dapp-validation" }),
            walletsStore: WalletsStore(keeperInfoStore: KeeperInfoStore(keeperInfoRepository: EmptyKeeperInfoRepositoryStub())),
            chainKitClient: client,
            pendingTransactionsService: IgnoredPendingTransactions(),
            configuration: configuration
        )
    }

    /// What unlocked the wallet, in order: the passcode asked for and the device asked to sign.
    actor Unlocks {
        private(set) var all = [String]()

        func take(_ step: String) {
            all.append(step)
        }
    }

    actor Pause {
        private var continuation: CheckedContinuation<Void, Never>?
        private var released = false

        func wait() async {
            guard !released else { return }
            await withCheckedContinuation { continuation = $0 }
        }

        func release() {
            released = true
            continuation?.resume()
            continuation = nil
        }
    }

    actor RecordedTransactions: PendingTransactionsService {
        private(set) var count = 0

        func report(_: MultichainPendingTransaction) async {
            count += 1
        }

        func flushRetained() async {}
    }

    func context(pending: PendingRequest, recorded: RecordedTransactions) -> WalletConnectSigningContext {
        WalletConnectSigningContext(
            signer: mnemonic, wallet: wallet(), mnemonicAccess: makeMnemonicAccess(), client: client,
            pendingTransactionsService: recorded, evmFee: nil, isPending: { await pending.isPending }
        )
    }

    func assertPasscodeInterrupted(expire: Bool) async throws {
        let pending = PendingRequest()
        let pause = Pause()
        let entered = expectation(description: "passcode requested")
        let wallet = wallet()
        let access = makeMnemonicAccess()
        try await access.saveMnemonic(
            CoreMnemonic(mnemonicWords: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about".components(separatedBy: " "), type: .bip39),
            wallet: wallet, passcode: "1234"
        )
        let service = service(checks: [], mnemonicAccess: access)
        let message = request(payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal)), method: .personalSign)
        let work = Task {
            await signingError {
                try await service.sign(
                    signer: .mnemonic(passcodeProvider: {
                        entered.fulfill()
                        await pause.wait()
                        return "1234"
                    }),
                    wallet: wallet, request: message, evmFee: nil, consent: .refuse,
                    isPending: { await pending.isPending }
                )
            }
        }
        defer { work.cancel() }
        await fulfillment(of: [entered], timeout: 3)
        if expire { await pending.end() } else { work.cancel() }
        await pause.release()

        let error = await work.value
        XCTAssertEqual(error, .canceled)
    }

    func assertSigningInterrupted(expire: Bool) async {
        let pending = PendingRequest()
        let pause = Pause()
        let entered = expectation(description: "signer started")
        let recorded = RecordedTransactions()
        let context = context(pending: pending, recorded: recorded)
        let steps = Unlocks()
        let work = Task {
            await signingError {
                try await WalletConnectEVMTransactionSigningUtilities().signAndRespond(
                    send: true, chain: .eth, activityType: .contractCall, context: context,
                    sign: { () throws(WalletConnectSigningError) in
                        await steps.take("sign")
                        entered.fulfill()
                        await pause.wait()
                        return Data([1]).asKotlinByteArray
                    },
                    broadcast: { _ throws(WalletConnectSigningError) in
                        await steps.take("broadcast")
                        return "0xsent"
                    }
                )
            }
        }
        defer { work.cancel() }
        await fulfillment(of: [entered], timeout: 3)
        if expire { await pending.end() } else { work.cancel() }
        await pause.release()

        let error = await work.value
        let taken = await steps.all
        let count = await recorded.count
        XCTAssertEqual(error, .canceled)
        XCTAssertEqual(taken, ["sign"])
        XCTAssertEqual(count, 0)
    }

    /// A request the dApp waits for until it expires or its session ends.
    actor PendingRequest {
        private(set) var isPending = true

        func end() {
            isPending = false
        }
    }

    /// Finds only what is never asked about, and the request ends while it reads it.
    struct EndingCheck: OperationCheck {
        let end: @Sendable () async -> Void

        func findings(of signable: SignableOperation) async throws -> [OperationFinding] {
            await end()
            return [OperationFinding(id: signable.operation.id, kind: "StubInfo", severity: .info, title: "Finding")]
        }
    }

    /// Gives no passcode, so a signer the gate let through stops right after asking for it.
    var mnemonic: MultichainTransferSigner {
        .mnemonic(passcodeProvider: { [unlocks] in
            await unlocks.take("passcode")
            return nil
        })
    }

    var device: DeviceTransferSigner {
        let refuse: @Sendable () async throws -> Data = { [unlocks] in
            await unlocks.take("device")
            throw CancellationError()
        }
        return DeviceTransferSigner(
            evm: { _ in try await refuse() },
            tron: { _ in try await refuse() },
            solana: { _ in try await refuse() },
            bitcoin: { _ in try [await refuse()] },
            ton: { _ in try [await refuse()] },
            evmMessage: { _ in try await refuse() },
            evmTypedData: { _, _ in try await refuse() },
            tronMessage: { _ in try await refuse() }
        )
    }

    func signingError(_ sign: () async throws -> WalletConnectResponseValue) async -> WalletConnectSigningError? {
        do {
            let response = try await sign()
            XCTFail("expected the request to stop before it is signed, got \(response)")
        } catch let error as WalletConnectSigningError {
            return error
        } catch {
            XCTFail("expected a signing error, got \(error)")
        }
        return nil
    }

    func makeMnemonicAccess() -> MnemonicAccess {
        .inMemory(seed: "wallet-connect-gate")
    }

    func service(checks: [any OperationCheck], mnemonicAccess: MnemonicAccess? = nil) -> WalletConnectSigningService {
        WalletConnectSigningService(
            mnemonicAccess: mnemonicAccess ?? makeMnemonicAccess(),
            client: client,
            pendingTransactionsService: IgnoredPendingTransactions(),
            gate: OperationGate { checks },
            signsDappOperations: false,
            sendOperation: { _, _, _, _, _, _ in
                XCTFail("a request the SDK signs was sent as its operation")
                return []
            },
            signOperation: { _, _, _, _, _ in
                XCTFail("a request the SDK signs was signed as its operation")
                return []
            }
        )
    }

    func request(payload: WalletConnectRequestPayload, method: KeeperCore.WalletConnectMethod) -> WalletConnectSessionRequest {
        WalletConnectSessionRequest(
            id: "request",
            topic: "topic",
            chain: .eth,
            method: method,
            dapp: WalletConnectDapp(name: "dApp", url: "https://example.com", description: "", iconURL: nil),
            payload: payload,
            source: nil,
            walletId: "wallet"
        )
    }

    func transaction(to: String?) -> WalletConnectEVMTransaction {
        WalletConnectEVMTransaction(
            from: nil,
            to: to,
            data: "0x",
            value: "0x3e8",
            nonce: "0x0",
            gas: nil,
            gasPrice: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil
        )
    }

    func wallet() -> KeeperCore.Wallet {
        makeWallet(kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1))
    }

    func ledgerWallet() -> KeeperCore.Wallet {
        makeWallet(kind: .Ledger(
            TonSwift.PublicKey(data: Data(repeating: 1, count: 32)),
            .v4R2,
            KeeperCore.Wallet.LedgerDevice(deviceId: "device", deviceModel: "Ledger Stax", accountIndex: 0)
        ))
    }

    func makeWallet(kind: KeeperCore.WalletKind) -> KeeperCore.Wallet {
        KeeperCore.Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: kind),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(
                walletId: "wallet",
                addresses: [MultichainWalletAddress(chain: .eth, address: Self.evmAddress, publicKey: Self.evmKey)],
                syncState: .synced
            ))
        )
    }
}

private struct IgnoredPendingTransactions: PendingTransactionsService {
    func report(_: MultichainPendingTransaction) async {}

    func flushRetained() async {}
}

private struct DappAppInfo: AppInfoProvider {
    let version = "1.0"
    let userAgent = "Keeper/1.0"
    let platform = "ios"
    let language = "en"
    let storeCountryCode: String? = nil
    let deviceCountryCode: String? = nil
    let isVPNActive = false
    let timeZoneIdentifier = "UTC"
}
