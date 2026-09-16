@testable import KeeperCore
import TKKeychain
import XCTest

final class DeviceAuthServiceTests: XCTestCase {
    func test_session_concurrentCallersShareOneRegistration() async {
        let context = Context()
        let gate = AsyncGate()
        context.api.registerGate = gate
        let service = context.makeService()

        let sessions = await withTaskGroup(of: DeviceAuthSession?.self) { group in
            for _ in 0 ..< 8 {
                group.addTask { try? await service.session() }
            }
            gate.open()
            return await group.reduce(into: [DeviceAuthSession?]()) { $0.append($1) }
        }

        XCTAssertEqual(context.api.registerCount, 1)
        XCTAssertEqual(Set(sessions.compactMap { $0?.accessToken }), ["jwt-1"])
        XCTAssertEqual(sessions.compactMap { $0?.deviceId }.count, 8)
    }

    func test_session_reusesCachedTokenAndRenewsWithinLeeway() async throws {
        let context = Context()
        context.api.expiresIn = 120
        let service = context.makeService()

        _ = try await service.session()
        _ = try await service.session()
        XCTAssertEqual(context.api.registerCount, 1)

        // Inside the 60s leeway the cached token is treated as spent.
        context.now = context.now.addingTimeInterval(70)
        let renewed = try await service.session()

        XCTAssertEqual(context.api.refreshCount, 1)
        XCTAssertEqual(renewed.accessToken, "jwt-2")
    }

    func test_session_refreshesStoredPairInsteadOfRegistering() async throws {
        let context = Context()
        try? context.certificateStore.save(Data([1, 2, 3]))
        context.tokenStore.save(.init(deviceId: "device-1", refreshToken: "refresh-1"))
        let service = context.makeService()

        let session = try await service.session()

        XCTAssertEqual(context.api.refreshCount, 1)
        XCTAssertEqual(context.api.registerCount, 0)
        XCTAssertEqual(context.api.refreshedTokens, ["refresh-1"])
        XCTAssertEqual(session.deviceId, "device-1")
        XCTAssertEqual(context.tokenStore.load()?.refreshToken, "rotated-refresh-1")
    }

    func test_session_reregistersWithSameCertificateWhenRefreshRejected() async throws {
        let context = Context()
        let certificate = Data([9, 9, 9])
        try? context.certificateStore.save(certificate)
        context.tokenStore.save(.init(deviceId: "device-1", refreshToken: "refresh-1"))
        context.api.refreshError = .unauthorized(message: "refresh_reused")
        let service = context.makeService()

        _ = try await service.session()

        XCTAssertEqual(context.api.registerCount, 1)
        XCTAssertEqual(context.signer.generateCount, 0)
        XCTAssertEqual(context.certificateStore.load(), certificate)
    }

    func test_session_regeneratesCertificateWhenDeviceRevoked() async throws {
        let context = Context()
        let certificate = Data([9, 9, 9])
        try? context.certificateStore.save(certificate)
        context.tokenStore.save(.init(deviceId: "device-1", refreshToken: "refresh-1"))
        context.api.refreshError = .unauthorized(message: "device_revoked")
        let service = context.makeService()

        _ = try await service.session()

        XCTAssertEqual(context.signer.generateCount, 1)
        XCTAssertEqual(context.api.registerCount, 1)
        XCTAssertNotEqual(context.certificateStore.load(), certificate)
    }

    func test_session_doesNotRegisterWhenRefreshHitsServerError() async throws {
        let context = Context()
        try? context.certificateStore.save(Data([1]))
        context.tokenStore.save(.init(deviceId: "device-1", refreshToken: "refresh-1"))
        context.api.refreshError = .badStatus(message: "service unavailable")
        let service = context.makeService()

        do {
            _ = try await service.session()
            XCTFail("expected a server error")
        } catch {
            XCTAssertEqual(error, .failed(message: "service unavailable"))
        }
        // A 5xx says nothing about the session: no challenge spent, no new registration.
        XCTAssertEqual(context.api.registerCount, 0)
        XCTAssertEqual(context.signer.generateCount, 0)
        XCTAssertEqual(context.tokenStore.load()?.refreshToken, "refresh-1")
    }

    func test_session_reportsDeviceChangeWhenRegistrationReplacesTheDevice() async throws {
        let context = Context()
        try? context.certificateStore.save(Data([9]))
        context.tokenStore.save(.init(deviceId: "device-1", refreshToken: "refresh-1"))
        context.api.refreshError = .unauthorized(message: "device_revoked")
        let service = context.makeService()

        _ = try await service.session()

        XCTAssertEqual(context.deviceChangeCount, 1)
    }

    /// A launch that happened offline used to leave the install unregistered for the whole run.
    func test_session_registersAfterADroppedConnection() async throws {
        let context = Context()
        context.api.registerError = .connectionError(underlying: nil)
        let service = context.makeService()

        let session = try await service.session()

        XCTAssertEqual(context.api.registerCount, 2)
        XCTAssertEqual(session.deviceId, "device-registered")
    }

    /// The renewal is shared, and an unstructured task inherits task locals, so a renewal started
    /// from inside another retry would take its budget from that caller — registering once and
    /// handing every joiner a failure it is not retrying itself.
    func test_session_keepsItsRetryBudgetWhenStartedFromInsideAnotherRetry() async throws {
        let context = Context()
        context.api.registerError = .connectionError(underlying: nil)
        let service = context.makeService()

        let session = try await MultichainRetry.run(
            attempts: 1,
            sleep: { _ in }
        ) { () async throws(DeviceAuthError) -> DeviceAuthSession in
            try await service.session()
        }

        XCTAssertEqual(context.api.registerCount, 2)
        XCTAssertEqual(session.deviceId, "device-registered")
    }

    func test_session_reportsDeviceChangeAfterAnEarlierRegisterFailure() async throws {
        let context = Context()
        try? context.certificateStore.save(Data([9]))
        context.tokenStore.save(.init(deviceId: "device-1", refreshToken: "refresh-1"))
        context.api.refreshError = .unauthorized(message: "device_revoked")
        context.api.registerError = .connectionError(underlying: nil)
        // Every pass of the first call has to fail, otherwise the retry recovers inside it and
        // there is no "earlier failure" left to carry the replaced device id across.
        context.api.registerErrorRepeats = MultichainRetry.defaultAttempts
        let service = context.makeService()

        do {
            _ = try await service.session()
            XCTFail("expected the first registration to fail")
        } catch {
            XCTAssertEqual(error, .connectionError)
        }
        // The revoked pair went away with the certificate, so only the service still knows which
        // device the next registration replaces.
        XCTAssertNil(context.tokenStore.load())
        XCTAssertEqual(context.deviceChangeCount, 0)

        _ = try await service.session()

        XCTAssertEqual(context.deviceChangeCount, 1)
    }

    func test_session_doesNotReportDeviceChangeOnFirstRegistration() async throws {
        let context = Context()
        let service = context.makeService()

        _ = try await service.session()
        _ = try await service.session()

        XCTAssertEqual(context.deviceChangeCount, 0)
    }

    func test_session_keepsStoredPairOnConnectionError() async throws {
        let context = Context()
        try? context.certificateStore.save(Data([1]))
        context.tokenStore.save(.init(deviceId: "device-1", refreshToken: "refresh-1"))
        context.api.refreshError = .connectionError(underlying: nil)
        let service = context.makeService()

        do {
            _ = try await service.session()
            XCTFail("expected a connection error")
        } catch {
            XCTAssertEqual(error, .connectionError)
        }
        XCTAssertEqual(context.api.registerCount, 0)
        XCTAssertEqual(context.tokenStore.load()?.refreshToken, "refresh-1")
    }

    func test_recoverSession_doesNotRenewWhenSessionAlreadyMovedOn() async throws {
        let context = Context()
        let service = context.makeService()
        _ = try await service.session()

        let recovered = try await service.recoverSession(invalidating: "some-older-jwt")

        XCTAssertEqual(context.api.registerCount, 1)
        XCTAssertEqual(recovered.accessToken, "jwt-1")
    }

    func test_recoverSession_renewsWhenRejectedTokenIsCurrent() async throws {
        let context = Context()
        let service = context.makeService()
        let session = try await service.session()

        let recovered = try await service.recoverSession(invalidating: session.accessToken)

        XCTAssertEqual(context.api.refreshCount, 1)
        XCTAssertEqual(recovered.accessToken, "jwt-2")
    }

    func test_session_failsWhenPushAppIdIsMissing() async throws {
        let context = Context()
        context.appId = nil
        let service = context.makeService()

        do {
            _ = try await service.session()
            XCTFail("expected a failure")
        } catch {
            XCTAssertEqual(error, .failed(message: "missing push app id"))
        }
        XCTAssertEqual(context.api.registerCount, 0)
    }
}

private final class Context {
    let vault = InMemoryKeychainVault()
    let api = DeviceAuthAPIFake()
    let signer = DeviceCertificateSignerFake()
    var appId: Int64? = 695_609_596_302
    var now = Date(timeIntervalSince1970: 1_000_000)
    private(set) var deviceChangeCount = 0

    lazy var certificateStore = DeviceCertificateStore(keychainVault: vault)
    lazy var tokenStore = DeviceTokenStore(keychainVault: vault)

    func makeService() -> DeviceAuthService {
        DeviceAuthService(
            api: api,
            signer: signer,
            certificateStore: certificateStore,
            tokenStore: tokenStore,
            platform: "ios",
            clientVersion: "1.2.3",
            appIdProvider: { [self] in appId },
            didChangeDevice: { [self] in deviceChangeCount += 1 },
            now: { [self] in now },
            // The backoff is real time in production; a suite only cares about the passes.
            sleep: { _ in }
        )
    }
}

private final class DeviceAuthAPIFake: DeviceAuthAPI, @unchecked Sendable {
    var expiresIn = 900
    var refreshError: MultichainClientAPIError?
    /// Consumed by the first attempts, so a later one can succeed. `registerErrorRepeats` is how
    /// many passes it survives — a whole `session()` call is worth `MultichainRetry.defaultAttempts`.
    var registerError: MultichainClientAPIError?
    var registerErrorRepeats = 1
    var registerGate: AsyncGate?
    private(set) var registerCount = 0
    private(set) var refreshCount = 0
    private(set) var registeredPublicKeys = [String]()
    private(set) var refreshedTokens = [String]()
    private var issuedTokens = 0

    func getDeviceChallenge() async throws(MultichainClientAPIError) -> MultichainWalletChallenge {
        MultichainWalletChallenge(challenge: "challenge", expiresAt: Date())
    }

    func registerDevice(
        devicePublicKey: String,
        deviceProof _: String,
        challenge _: String,
        platform _: String,
        appId _: Int64,
        clientVersion _: String
    ) async throws(MultichainClientAPIError) -> DeviceTokenPair {
        registerCount += 1
        if let registerError, registerErrorRepeats > 0 {
            registerErrorRepeats -= 1
            if registerErrorRepeats == 0 {
                self.registerError = nil
            }
            throw registerError
        }
        registeredPublicKeys.append(devicePublicKey)
        if let registerGate {
            await registerGate.wait()
        }
        return makeTokens(deviceId: "device-registered")
    }

    func refreshDevice(
        deviceId: String,
        refreshToken: String,
        deviceProof _: String
    ) async throws(MultichainClientAPIError) -> DeviceTokenPair {
        refreshCount += 1
        refreshedTokens.append(refreshToken)
        if let refreshError {
            throw refreshError
        }
        return makeTokens(deviceId: deviceId, refreshToken: "rotated-\(refreshToken)")
    }

    private func makeTokens(deviceId: String, refreshToken: String? = nil) -> DeviceTokenPair {
        issuedTokens += 1
        return DeviceTokenPair(
            deviceId: deviceId,
            accessToken: "jwt-\(issuedTokens)",
            refreshToken: refreshToken ?? "refresh-\(issuedTokens)",
            expiresIn: expiresIn
        )
    }
}

private final class DeviceCertificateSignerFake: DeviceCertificateSigner, @unchecked Sendable {
    private(set) var generateCount = 0

    func generateCertificate() -> Data {
        generateCount += 1
        return Data([0xAA, UInt8(generateCount)])
    }

    func registerProof(
        privateKey: Data,
        platform _: String,
        appId _: Int64,
        clientVersion _: String,
        challenge _: String
    ) -> DeviceProof {
        DeviceProof(publicKey: "pub-\(privateKey.map { String($0) }.joined())", signature: "sig")
    }

    func refreshProof(privateKey: Data, deviceId _: String, refreshToken _: String) -> DeviceProof {
        DeviceProof(publicKey: "pub-\(privateKey.map { String($0) }.joined())", signature: "sig")
    }
}

/// Blocks the first network call so every concurrent caller has to join the in-flight renewal.
private final class AsyncGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations = [UnsafeContinuation<Void, Never>]()
    private var isOpen = false

    func wait() async {
        await withUnsafeContinuation { continuation in
            lock.lock()
            guard !isOpen else {
                lock.unlock()
                continuation.resume()
                return
            }
            continuations.append(continuation)
            lock.unlock()
        }
    }

    func open() {
        lock.lock()
        isOpen = true
        let pending = continuations
        continuations = []
        lock.unlock()
        pending.forEach { $0.resume() }
    }
}
