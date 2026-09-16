import Foundation
import TKLogging

protocol DeviceAuthProviding: Sendable {
    /// Cached session, refreshed or re-registered when the access token is close to expiry.
    func session() async throws(DeviceAuthError) -> DeviceAuthSession
    /// Called after a 401. `accessToken` is the token that got rejected: if the session has
    /// already moved on, the caller just gets the newer one instead of a second renewal.
    func recoverSession(invalidating accessToken: String) async throws(DeviceAuthError) -> DeviceAuthSession
    /// Whether this install already has a device id. `false` means the backend cannot hold any
    /// binding for it yet, so a caller must not authenticate just to look.
    func isDeviceKnown() async -> Bool
}

/// Sole owner of the device session: one renewal at a time, and the only place that
/// touches the certificate and token stores.
actor DeviceAuthService: DeviceAuthProviding {
    fileprivate struct Session {
        let deviceId: String
        let accessToken: String
        let expiresAt: Date
    }

    private let api: DeviceAuthAPI
    private let signer: DeviceCertificateSigner
    private let certificateStore: DeviceCertificateStore
    private let tokenStore: DeviceTokenStore
    private let platform: String
    private let clientVersion: String
    private let appIdProvider: @Sendable () -> Int64?
    private let didChangeDevice: () -> Void
    private let now: @Sendable () -> Date
    private let sleep: MultichainRetry.Sleep

    private var current: Session?
    private var inFlight: Task<Session, Error>?
    /// Device id the next successful session replaces. Regenerating the certificate drops the
    /// stored pair, so a register that fails in between would erase the only trace of it and the
    /// rotation would go unreported.
    private var replacedDeviceId: String?

    init(
        api: DeviceAuthAPI,
        signer: DeviceCertificateSigner,
        certificateStore: DeviceCertificateStore,
        tokenStore: DeviceTokenStore,
        platform: String,
        clientVersion: String,
        appIdProvider: @escaping @Sendable () -> Int64?,
        didChangeDevice: @escaping () -> Void = {},
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping MultichainRetry.Sleep = MultichainRetry.defaultSleep
    ) {
        self.api = api
        self.signer = signer
        self.certificateStore = certificateStore
        self.tokenStore = tokenStore
        self.platform = platform
        self.clientVersion = clientVersion
        self.appIdProvider = appIdProvider
        self.didChangeDevice = didChangeDevice
        self.now = now
        self.sleep = sleep
    }

    func session() async throws(DeviceAuthError) -> DeviceAuthSession {
        if let session = validSession() {
            return session
        }
        return try await renewedSession()
    }

    func recoverSession(invalidating accessToken: String) async throws(DeviceAuthError) -> DeviceAuthSession {
        if let current, current.accessToken != accessToken {
            return DeviceAuthSession(deviceId: current.deviceId, accessToken: current.accessToken)
        }
        current = nil
        return try await renewedSession()
    }

    func isDeviceKnown() -> Bool {
        current != nil || tokenStore.load() != nil
    }
}

private extension DeviceAuthService {
    static let expiryLeeway: TimeInterval = 60

    func validSession() -> DeviceAuthSession? {
        guard let current, current.expiresAt.timeIntervalSince(now()) > Self.expiryLeeway else {
            return nil
        }
        return DeviceAuthSession(deviceId: current.deviceId, accessToken: current.accessToken)
    }

    /// Joins the renewal already in flight, or starts one. Concurrent callers share a
    /// single register/refresh round trip and re-read the state it produced.
    func renewedSession() async throws(DeviceAuthError) -> DeviceAuthSession {
        let task: Task<Session, Error>
        if let inFlight {
            task = inFlight
        } else {
            task = Task {
                defer { inFlight = nil }
                let previousDeviceId = replacedDeviceId ?? current?.deviceId ?? tokenStore.load()?.deviceId
                replacedDeviceId = previousDeviceId
                let session = try await establishedSession()
                current = session
                replacedDeviceId = nil
                notifyIfDeviceChanged(from: previousDeviceId, to: session.deviceId)
                return session
            }
            inFlight = task
        }

        do {
            let session = try await task.value
            return DeviceAuthSession(deviceId: session.deviceId, accessToken: session.accessToken)
        } catch {
            throw Self.authError(from: error)
        }
    }

    /// A new device id leaves the previous one's wallet bindings and push subscription behind,
    /// so whoever owns that state has to rebuild it. Fires after the new session is published,
    /// and the handler is expected to hand the work off rather than run it here.
    func notifyIfDeviceChanged(from previousDeviceId: String?, to deviceId: String) {
        guard let previousDeviceId, previousDeviceId != deviceId else {
            return
        }
        Log.w("🪵 DeviceAuth: device id changed, bindings and push need a resync")
        didChangeDevice()
    }

    /// A dropped connection on startup used to leave the install without a session for the whole
    /// run, so the whole ladder is repeated: each pass starts from a fresh challenge, which is the
    /// only thing a repeat can spend.
    ///
    /// The budget is the ladder's own rather than the enclosing call's: this runs inside the shared
    /// `inFlight` task, which other callers join. Inheriting would make the number of attempts
    /// depend on who won the race to create it, and a ChainKit request joining a renewal started
    /// from a retrying business call would get one attempt and fall back to an unauthenticated
    /// request — which the nodes now reject themselves.
    func establishedSession() async throws -> Session {
        try await MultichainRetry.run(owningBudget: true, sleep: sleep) { () async throws(DeviceAuthError) -> Session in
            do {
                return try await self.establishSessionOnce()
            } catch {
                throw Self.authError(from: error)
            }
        }
    }

    func establishSessionOnce() async throws -> Session {
        var privateKey = try certificate()

        if let stored = tokenStore.load() {
            do {
                return try await refresh(privateKey: privateKey, stored: stored)
            } catch let error as DeviceAuthError {
                switch error {
                case .cancelled, .connectionError, .failed:
                    // Only an explicit rejection says the pair is unusable; a transport or
                    // server failure must not spend a challenge on a pointless register.
                    throw error
                case .unauthorized:
                    Log.w("🪵 DeviceAuth: refresh rejected, re-registering: \(error)")
                    if error.isDeviceRevoked {
                        privateKey = try regeneratedCertificate()
                    }
                }
            }
        }

        do {
            return try await register(privateKey: privateKey)
        } catch let error as DeviceAuthError where error.isDeviceRevoked {
            return try await register(privateKey: regeneratedCertificate())
        }
    }

    func certificate() throws -> Data {
        if let existing = certificateStore.load() {
            return existing
        }
        return try regeneratedCertificate()
    }

    func regeneratedCertificate() throws -> Data {
        let privateKey = signer.generateCertificate()
        do {
            try certificateStore.save(privateKey)
        } catch {
            throw DeviceAuthError.failed(message: "failed to store device certificate: \(error)")
        }
        // The stored pair belongs to the previous certificate and can no longer be proven.
        tokenStore.delete()
        return privateKey
    }

    func register(privateKey: Data) async throws -> Session {
        guard let appId = appIdProvider() else {
            throw DeviceAuthError.failed(message: "missing push app id")
        }
        let challenge = try await apiCall(await api.getDeviceChallenge()).challenge
        let proof = signer.registerProof(
            privateKey: privateKey,
            platform: platform,
            appId: appId,
            clientVersion: clientVersion,
            challenge: challenge
        )
        let pair = try await apiCall(
            await api.registerDevice(
                devicePublicKey: proof.publicKey,
                deviceProof: proof.signature,
                challenge: challenge,
                platform: platform,
                appId: appId,
                clientVersion: clientVersion
            )
        )
        return persisted(pair)
    }

    func refresh(privateKey: Data, stored: DeviceTokenStore.Record) async throws -> Session {
        let proof = signer.refreshProof(
            privateKey: privateKey,
            deviceId: stored.deviceId,
            refreshToken: stored.refreshToken
        )
        let pair = try await apiCall(
            await api.refreshDevice(
                deviceId: stored.deviceId,
                refreshToken: stored.refreshToken,
                deviceProof: proof.signature
            )
        )
        return persisted(pair)
    }

    func persisted(_ pair: DeviceTokenPair) -> Session {
        tokenStore.save(
            DeviceTokenStore.Record(deviceId: pair.deviceId, refreshToken: pair.refreshToken)
        )
        return Session(
            deviceId: pair.deviceId,
            accessToken: pair.accessToken,
            expiresAt: now().addingTimeInterval(TimeInterval(pair.expiresIn))
        )
    }

    func apiCall<T>(
        _ block: @autoclosure () async throws(MultichainClientAPIError) -> T
    ) async throws -> T {
        do {
            return try await block()
        } catch {
            throw Self.authError(from: error)
        }
    }

    static func authError(from error: Error) -> DeviceAuthError {
        switch error {
        case let error as DeviceAuthError:
            return error
        case is CancellationError:
            return .cancelled
        case let error as MultichainClientAPIError:
            switch error {
            case .cancelled:
                return .cancelled
            case .connectionError:
                return .connectionError
            case let .unauthorized(message):
                return .unauthorized(reason: message)
            case let .forbidden(message):
                return .failed(message: message)
            case let .badStatus(message):
                return .failed(message: message)
            case let .badResponse(underlying):
                return .failed(message: "bad response: \(underlying?.localizedDescription ?? "unknown")")
            case let .undocumented(statusCode):
                return .failed(message: "unexpected status \(statusCode)")
            }
        default:
            return .failed(message: "\(error)")
        }
    }
}
