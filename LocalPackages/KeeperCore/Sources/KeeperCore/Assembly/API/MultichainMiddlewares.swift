import Foundation
import HTTPTypes
import OpenAPIRuntime
import TKLogging

struct FirebaseUserIdHeaderMiddleware: ClientMiddleware {
    static let headerName = "F"

    let firebaseUserIdProvider: @Sendable () -> String?
    let operationIDs: Set<String>?

    init(
        firebaseUserIdProvider: @escaping @Sendable () -> String?,
        operationIDs: Set<String>? = nil
    ) {
        self.firebaseUserIdProvider = firebaseUserIdProvider
        self.operationIDs = operationIDs
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard
            operationIDs?.contains(operationID) ?? true,
            let firebaseUserId = firebaseUserIdProvider(),
            !firebaseUserId.isEmpty,
            let name = HTTPField.Name(Self.headerName)
        else {
            return try await next(request, body, baseURL)
        }

        var request = request
        request.headerFields[name] = firebaseUserId
        return try await next(request, body, baseURL)
    }
}

/// Resolves the current device session, attaches it to a globally protected request, and recovers
/// once when the backend rejects it. Session resolution is part of the request so a mandatory
/// operation never falls back to going out unauthenticated.
struct DeviceSessionMiddleware: ClientMiddleware {
    let deviceAuth: DeviceAuthProviding

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let session = try await deviceAuth.session()
        guard !session.accessToken.isEmpty else {
            throw DeviceAuthError.failed(message: "empty device access token")
        }

        var authenticated = request
        authenticated.headerFields[.authorization] = "Bearer \(session.accessToken)"
        let (response, responseBody) = try await next(authenticated, body, baseURL)
        guard response.status.code == 401, isReplayable(body) else {
            return (response, responseBody)
        }

        let recovered = try await deviceAuth.recoverSession(invalidating: session.accessToken)
        guard !recovered.accessToken.isEmpty, recovered.accessToken != session.accessToken else {
            return (response, responseBody)
        }

        Log.i("🪵 Multichain: recovered the device session after a 401 on \(operationID)")
        authenticated.headerFields[.authorization] = "Bearer \(recovered.accessToken)"
        return try await next(authenticated, body, baseURL)
    }

    private func isReplayable(_ body: HTTPBody?) -> Bool {
        guard let body else {
            return true
        }
        return body.iterationBehavior == .multiple
    }
}

/// Attaches the wallet-scoped credential the spec declares as `walletAuth` + `xWalletId`. The
/// generator emits nothing for `security`, so both headers are set here.
///
/// `X-Wallet-ID` travels even on routes that already name the wallet in the path: the backend
/// verifies the credential without resolving a route template, and reads the format and kind bytes
/// from the header to recompute the id from the key recovered out of the signature.
struct WalletAuthHeaderMiddleware: ClientMiddleware {
    private static let walletId = HTTPField.Name("X-Wallet-ID")!
    private static let walletAuthorization = HTTPField.Name("X-Wallet-Authorization")!

    let walletId: String
    let walletAuthToken: String?

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard let walletAuthToken else {
            return try await next(request, body, baseURL)
        }
        var request = request
        request.headerFields[Self.walletId] = walletId
        request.headerFields[Self.walletAuthorization] = walletAuthToken
        return try await next(request, body, baseURL)
    }
}

/// Repairs the credentials of a wallet-scoped request and replays it once.
///
/// Sits innermost so it sees the credentials the middlewares above already applied and can overwrite
/// them: those hold the access token captured when the client was built, so re-running them would
/// only re-apply what was just rejected.
///
/// The recovery lives here rather than in `MultichainClientAPI` because only the raffle operations
/// declare a 401: everywhere else the generated client surfaces it as `undocumented(statusCode: 401)`.
/// Concurrent 401s cost one renewal, not one each: `DeviceAuthService` joins them onto a single
/// in-flight refresh.
///
/// Credentials the middlewares above could not apply are resolved here instead, before the first
/// attempt: they are captured when the client is built, and at that point the device session can
/// still be unresolved — the access token is memory-only, so every cold launch has to reach the
/// backend before one exists, and a locked Keychain hides the certificate that would mint it. Both
/// settle within the run, so the request is credentialed at the moment it is sent rather than sent
/// bare and left to a 403.
///
/// A 401 is the device session's rejection and a 403 the wallet credential's, so they are repaired
/// differently — but a request that still carried no credentials takes the 403 path either way:
/// nothing was rejected, so there is nothing to invalidate.
struct WalletAuthRecoveryMiddleware: ClientMiddleware {
    private static let walletIdHeader = HTTPField.Name("X-Wallet-ID")!
    private static let walletAuthorization = HTTPField.Name("X-Wallet-Authorization")!

    let walletId: String
    /// The token the stack above put in `Authorization`, or `nil`/empty when it had none to apply.
    let accessToken: String?
    let deviceAuth: DeviceAuthProviding
    let walletAuthTokenProvider: WalletAuthTokenProviding

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (request, sentAccessToken) = await credentialed(request)
        let attempt = try await next(request, body, baseURL)
        guard isReplayable(body) else {
            return attempt
        }
        switch attempt.0.status.code {
        case 401:
            return try await replayWithRecoveredSession(
                request,
                sentAccessToken: sentAccessToken,
                body: body,
                baseURL: baseURL,
                operationID: operationID,
                rejected: attempt,
                next: next
            )
        case 403:
            return try await replayWithRemintedCredential(
                request,
                body: body,
                baseURL: baseURL,
                operationID: operationID,
                rejected: attempt,
                next: next
            )
        default:
            return attempt
        }
    }

    /// The request as it goes out, plus the access token it carries — which a 401 invalidates, so it
    /// has to be the one actually sent rather than the one captured at build time.
    private func credentialed(_ request: HTTPRequest) async -> (HTTPRequest, String?) {
        guard request.headerFields[.authorization] == nil else {
            return (request, accessToken)
        }
        guard let session = try? await deviceAuth.session(), !session.accessToken.isEmpty else {
            return (request, nil)
        }
        let walletAuthToken = await walletAuthTokenProvider.token(
            walletId: walletId,
            accessToken: session.accessToken
        )
        let request = credentialed(
            request,
            accessToken: session.accessToken,
            walletAuthToken: walletAuthToken
        )
        return (request, session.accessToken)
    }

    private func replayWithRecoveredSession(
        _ request: HTTPRequest,
        sentAccessToken: String?,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        rejected: (HTTPResponse, HTTPBody?),
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        // Empty means the request went out bare because no session could be resolved for it, here
        // or above. That is not a verdict on the wallet — there is nothing to invalidate, just
        // credentials to acquire, which is the 403 path's job.
        guard let accessToken = sentAccessToken, !accessToken.isEmpty else {
            return try await replayWithRemintedCredential(
                request,
                body: body,
                baseURL: baseURL,
                operationID: operationID,
                rejected: rejected,
                next: next
            )
        }
        guard let recovered = try? await deviceAuth.recoverSession(invalidating: accessToken),
              !recovered.accessToken.isEmpty,
              recovered.accessToken != accessToken
        else {
            return rejected
        }

        // The swallowed 401 never reaches the logging middleware, which is outermost, so the
        // recovery is only visible if it is logged here.
        Log.i("🪵 Multichain: recovered the device session after a 401 on \(operationID)")

        // A credential signed over the retired access token would not verify against the new one, so
        // it is reminted or removed — never carried over. A wallet this install has no app key for
        // retries with the device session alone, exactly as its first attempt did.
        let walletAuthToken = await walletAuthTokenProvider.token(
            walletId: walletId,
            accessToken: recovered.accessToken
        )

        // A rotated device may not be bound to this wallet yet, so the replay can legitimately fail
        // again. Rebinding belongs to the bindings reconcile, which demotes the wallet to `pending`.
        return try await next(
            credentialed(request, accessToken: recovered.accessToken, walletAuthToken: walletAuthToken),
            body,
            baseURL
        )
    }

    /// A 403 says the device session was accepted and the wallet credential was not: the backend
    /// answers `wallet_proof_required` when the header is absent, and rejects one it cannot verify.
    /// Neither is something a session refresh fixes, so the credential itself is dropped and
    /// reminted — which is also how a request that went out without one, because the Keychain was
    /// still locked or the session still unresolved when the client was built, gets its first.
    ///
    /// The replay only happens when the credentials actually changed, so a wallet this install has
    /// no app key for — or one the device is simply not bound to — spends no extra round trip.
    private func replayWithRemintedCredential(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        rejected: (HTTPResponse, HTTPBody?),
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard let session = try? await deviceAuth.session(), !session.accessToken.isEmpty else {
            return rejected
        }
        await walletAuthTokenProvider.invalidateToken(walletId: walletId)
        let walletAuthToken = await walletAuthTokenProvider.token(
            walletId: walletId,
            accessToken: session.accessToken
        )
        let retried = credentialed(
            request,
            accessToken: session.accessToken,
            walletAuthToken: walletAuthToken
        )
        guard retried.headerFields != request.headerFields else {
            return rejected
        }

        Log.i("🪵 Multichain: reminted the wallet credential after a 403 on \(operationID)")
        return try await next(retried, body, baseURL)
    }

    /// The wallet id travels only alongside a credential: on its own it asserts nothing the backend
    /// can verify.
    private func credentialed(
        _ request: HTTPRequest,
        accessToken: String,
        walletAuthToken: String?
    ) -> HTTPRequest {
        var request = request
        request.headerFields[.authorization] = "Bearer \(accessToken)"
        request.headerFields[Self.walletIdHeader] = walletAuthToken == nil ? nil : walletId
        request.headerFields[Self.walletAuthorization] = walletAuthToken
        return request
    }

    /// A single-pass body cannot be sent twice, so a request carrying one is never replayed. Every
    /// generated JSON body is backed by `Data` and reports `.multiple`.
    private func isReplayable(_ body: HTTPBody?) -> Bool {
        guard let body else {
            return true
        }
        return body.iterationBehavior == .multiple
    }
}

struct BearerTokenMiddleware: ClientMiddleware {
    let token: String

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID _: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(token)"
        return try await next(request, body, baseURL)
    }
}

/// Wallet-scoped stack shared by Multichain and tk-perps: credentials first, recovery innermost
/// so a 401 can overwrite the Bearer and remint `X-Wallet-Authorization`.
enum WalletAuthClientMiddlewares {
    static func make(
        deviceJWT: String?,
        walletId: String,
        walletAuthToken: String?,
        recovery: MultichainWalletAuthDependencies?
    ) -> [any ClientMiddleware] {
        var middlewares: [any ClientMiddleware] = []
        if let deviceJWT, !deviceJWT.isEmpty {
            middlewares.append(BearerTokenMiddleware(token: deviceJWT))
        }
        middlewares.append(
            WalletAuthHeaderMiddleware(walletId: walletId, walletAuthToken: walletAuthToken)
        )
        // No recovery without the graph that owns the session: a 401 then stands instead of being
        // retried, which is all that is left to do once nothing can mint a fresh credential.
        if let recovery {
            middlewares.append(
                WalletAuthRecoveryMiddleware(
                    walletId: walletId,
                    accessToken: deviceJWT,
                    deviceAuth: recovery.deviceAuth,
                    walletAuthTokenProvider: recovery.walletAuthTokenProvider
                )
            )
        }
        return middlewares
    }
}
