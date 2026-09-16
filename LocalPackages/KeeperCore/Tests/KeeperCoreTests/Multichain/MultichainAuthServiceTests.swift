import Foundation
@testable import KeeperCore
import XCTest

final class MultichainAuthServiceTests: XCTestCase {
    func test_unregisterWallets_clearsPendingRecordOnSuccess() async throws {
        let context = Context()

        try await context.service.unregisterWallets(walletIds: ["a", "b"])

        XCTAssertEqual(context.api.unregisteredBatches, [["a", "b"]])
        XCTAssertEqual(context.pendingStore.load(), [])
    }

    func test_unregisterWallets_keepsUnconfirmedBatchesPending() async throws {
        let context = Context()
        let walletIds = (0 ..< 40).map { "wallet-\($0)" }
        context.api.failAfterBatches = 1

        do {
            try await context.service.unregisterWallets(walletIds: walletIds)
            XCTFail("expected the second batch to fail")
        } catch {}

        // Chunked by 32, so only the confirmed chunk may leave the pending record.
        XCTAssertEqual(context.api.unregisteredBatches.count, 1)
        XCTAssertEqual(context.pendingStore.load(), Array(walletIds[32...]).sorted())
    }

    func test_unregisterWallets_retriesWhenRecoveryKeepsTheDevice() async throws {
        let context = Context()
        context.api.unregisterErrors = [.unauthorized(message: "token_expired")]

        try await context.service.unregisterWallets(walletIds: ["wallet"])

        XCTAssertEqual(context.api.unregisterJWTs, ["jwt-1", "jwt-2"])
        XCTAssertEqual(context.pendingStore.load(), [])
    }

    func test_unregisterWallets_keepsPendingRecordWhenRecoveryRotatesTheDevice() async throws {
        let context = Context()
        context.deviceAuth.recoveredDeviceId = "device-2"
        context.api.unregisterErrors = [.unauthorized(message: "device_revoked")]

        do {
            try await context.service.unregisterWallets(walletIds: ["wallet"])
            XCTFail("expected the detach to remain unconfirmed")
        } catch {
            guard case .apiError = error else {
                XCTFail("expected an API error, got \(error)")
                return
            }
        }

        XCTAssertEqual(context.api.unregisterJWTs, ["jwt-1"])
        XCTAssertEqual(context.pendingStore.load(), ["wallet"])
    }

    func test_flushPendingUnregisters_retriesRecordedDetaches() async {
        let context = Context()
        context.api.failAfterBatches = 0
        try? await context.service.unregisterWallets(walletIds: ["a"])
        XCTAssertEqual(context.pendingStore.load(), ["a"])

        context.api.failAfterBatches = nil
        await context.service.flushPendingUnregisters()

        XCTAssertEqual(context.api.unregisteredBatches.last, ["a"])
        XCTAssertEqual(context.pendingStore.load(), [])
    }

    func test_flushPendingUnregisters_doesNothingWithoutRecords() async {
        let context = Context()

        await context.service.flushPendingUnregisters()

        XCTAssertTrue(context.api.unregisteredBatches.isEmpty)
    }

    func test_registerWallets_detachesPersistedUnregisterBeforeRegistering() async throws {
        let context = Context()
        context.pendingStore.add(["wallet"])
        context.api.registerResults = [.init(index: 0, walletId: "wallet", error: nil)]

        _ = try await context.service.registerWallets(walletId: "wallet") { _ in
            (challenge: "challenge", wallets: [])
        }
        await context.service.flushPendingUnregisters()

        XCTAssertEqual(context.api.operations, [.unregister(["wallet"]), .register])
        XCTAssertEqual(context.pendingStore.load(), [])
    }

    func test_unregisterWallets_supersedesInFlightRegister() async throws {
        let gate = RegisterGate()
        let context = Context(registerGate: gate)
        context.api.registerResults = [.init(index: 0, walletId: "wallet", error: nil)]
        let registerTask = Task {
            try await context.service.registerWallets(walletId: "wallet") { _ in
                (challenge: "challenge", wallets: [])
            }
        }
        await gate.waitUntilEntered()

        let unregisterTask = Task {
            try await context.service.unregisterWallets(walletIds: ["wallet"])
        }
        while context.pendingStore.load() != ["wallet"] {
            await Task.yield()
        }
        await gate.open()

        do {
            _ = try await registerTask.value
            XCTFail("expected the stale register to be cancelled")
        } catch let error as MultichainServiceError {
            guard case .cancelled = error else {
                XCTFail("expected cancellation, got \(error)")
                return
            }
        }
        try await unregisterTask.value

        XCTAssertEqual(context.api.operations, [.register, .unregister(["wallet"])])
        XCTAssertEqual(context.pendingStore.load(), [])
    }
}

private final class Context {
    let vault = InMemoryKeychainVault()
    let api: MultichainAuthClientAPIFake
    private let fallbackSuiteName = "MultichainAuthServiceTests.\(UUID().uuidString)"

    init(registerGate: RegisterGate? = nil) {
        api = MultichainAuthClientAPIFake(registerGate: registerGate)
    }

    private lazy var fallbackDefaults = UserDefaults(suiteName: fallbackSuiteName)!
    lazy var pendingStore = MultichainPendingUnregisterStore(
        keychainVault: vault,
        fallbackDefaults: fallbackDefaults
    )
    lazy var service: MultichainAuthService = MultichainAuthServiceImplementation(
        clientAPI: api,
        deviceAuth: deviceAuth,
        pendingUnregisterStore: pendingStore
    )
    let deviceAuth = DeviceAuthFake()

    deinit {
        fallbackDefaults.removePersistentDomain(forName: fallbackSuiteName)
    }
}

private final class DeviceAuthFake: DeviceAuthProviding, @unchecked Sendable {
    var recoveredDeviceId = "device-1"

    func session() async throws(DeviceAuthError) -> DeviceAuthSession {
        DeviceAuthSession(deviceId: "device-1", accessToken: "jwt-1")
    }

    func recoverSession(invalidating _: String) async throws(DeviceAuthError) -> DeviceAuthSession {
        DeviceAuthSession(deviceId: recoveredDeviceId, accessToken: "jwt-2")
    }

    func isDeviceKnown() async -> Bool {
        true
    }
}

private final class MultichainAuthClientAPIFake: MultichainAuthClientAPI, @unchecked Sendable {
    enum Operation: Equatable {
        case register
        case unregister([String])
    }

    /// Number of batches that succeed before the fake starts failing; `nil` never fails.
    var failAfterBatches: Int?
    var unregisterErrors = [MultichainClientAPIError]()
    var registerResults = [MultichainWalletRegisterResult]()

    private let registerGate: RegisterGate?
    private let lock = NSLock()
    private var storedOperations = [Operation]()
    private var storedUnregisteredBatches = [[String]]()
    private var storedUnregisterJWTs = [String]()

    var operations: [Operation] {
        lock.withLock { storedOperations }
    }

    var unregisteredBatches: [[String]] {
        lock.withLock { storedUnregisteredBatches }
    }

    var unregisterJWTs: [String] {
        lock.withLock { storedUnregisterJWTs }
    }

    init(registerGate: RegisterGate? = nil) {
        self.registerGate = registerGate
    }

    func getDeviceChallenge() async throws(MultichainClientAPIError) -> MultichainWalletChallenge {
        MultichainWalletChallenge(challenge: "challenge", expiresAt: Date())
    }

    func registerDevice(
        devicePublicKey _: String,
        deviceProof _: String,
        challenge _: String,
        platform _: String,
        appId _: Int64,
        clientVersion _: String
    ) async throws(MultichainClientAPIError) -> DeviceTokenPair {
        DeviceTokenPair(deviceId: "device-1", accessToken: "jwt-1", refreshToken: "refresh-1", expiresIn: 900)
    }

    func refreshDevice(
        deviceId: String,
        refreshToken _: String,
        deviceProof _: String
    ) async throws(MultichainClientAPIError) -> DeviceTokenPair {
        DeviceTokenPair(deviceId: deviceId, accessToken: "jwt-2", refreshToken: "refresh-2", expiresIn: 900)
    }

    func getDeviceBindings(
        walletIds _: [String],
        deviceJWT _: String
    ) async throws(MultichainClientAPIError) -> DeviceBindings {
        DeviceBindings(known: [], unknown: [], extra: [])
    }

    func registerWallets(
        challenge _: String,
        wallets _: [MultichainWalletRegisterItem],
        deviceJWT _: String
    ) async throws(MultichainClientAPIError) -> [MultichainWalletRegisterResult] {
        lock.withLock {
            storedOperations.append(.register)
        }
        if let registerGate {
            await registerGate.enterAndWait()
        }
        return registerResults
    }

    func unregisterWallets(
        walletIds: [String],
        deviceJWT: String
    ) async throws(MultichainClientAPIError) -> [String] {
        let scriptedError = lock.withLock {
            storedUnregisterJWTs.append(deviceJWT)
            return unregisterErrors.isEmpty ? nil : unregisterErrors.removeFirst()
        }
        if let scriptedError {
            throw scriptedError
        }
        if let failAfterBatches, lock.withLock({ storedUnregisteredBatches.count }) >= failAfterBatches {
            throw .connectionError(underlying: nil)
        }
        lock.withLock {
            storedOperations.append(.unregister(walletIds))
            storedUnregisteredBatches.append(walletIds)
        }
        return walletIds
    }

    func subscribeWalletPush(
        pushToken _: String,
        locale _: String?,
        walletIds _: [String],
        deviceJWT _: String
    ) async throws(MultichainClientAPIError) {}

    func unsubscribeWalletPush(deviceJWT _: String) async throws(MultichainClientAPIError) {}
}

private actor RegisterGate {
    private var didEnter = false
    private var isOpen = false
    private var enteredWaiters = [CheckedContinuation<Void, Never>]()
    private var openWaiters = [CheckedContinuation<Void, Never>]()

    func enterAndWait() async {
        didEnter = true
        enteredWaiters.forEach { $0.resume() }
        enteredWaiters.removeAll()
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            openWaiters.append(continuation)
        }
    }

    func waitUntilEntered() async {
        guard !didEnter else { return }
        await withCheckedContinuation { continuation in
            enteredWaiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        openWaiters.forEach { $0.resume() }
        openWaiters.removeAll()
    }
}
