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

/// Recovers the device session on a 401 and replays the request once.
///
/// Sits innermost so it sees the credentials the middlewares above already applied and can overwrite
/// them: those hold the access token captured when the client was built, so re-running them would
/// only re-apply the token that was just rejected.
///
/// The recovery lives here rather than in `MultichainClientAPI` because only the raffle operations
/// declare a 401: everywhere else the generated client surfaces it as `undocumented(statusCode: 401)`.
/// Concurrent 401s cost one renewal, not one each: `DeviceAuthService` joins them onto a single
/// in-flight refresh.
struct WalletAuthRecoveryMiddleware: ClientMiddleware {
    private static let walletIdHeader = HTTPField.Name("X-Wallet-ID")!
    private static let walletAuthorization = HTTPField.Name("X-Wallet-Authorization")!

    let walletId: String
    /// The token the stack above put in `Authorization`, and the one a 401 invalidates.
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
        let (response, responseBody) = try await next(request, body, baseURL)
        guard response.status.code == 401,
              let accessToken,
              !accessToken.isEmpty,
              isReplayable(body)
        else {
            return (response, responseBody)
        }

        guard let recovered = try? await deviceAuth.recoverSession(invalidating: accessToken),
              !recovered.accessToken.isEmpty,
              recovered.accessToken != accessToken
        else {
            return (response, responseBody)
        }

        // The swallowed 401 never reaches the logging middleware, which is outermost, so the
        // recovery is only visible if it is logged here.
        Log.i("🪵 Multichain: recovered the device session after a 401 on \(operationID)")

        var retried = request
        retried.headerFields[.authorization] = "Bearer \(recovered.accessToken)"
        // A credential signed over the retired access token would not verify against the new one, so
        // it is reminted or removed — never carried over. A wallet this install has no app key for
        // retries with the device session alone, exactly as its first attempt did.
        let walletAuthToken = await walletAuthTokenProvider.token(
            walletId: walletId,
            accessToken: recovered.accessToken
        )
        retried.headerFields[Self.walletIdHeader] = walletAuthToken == nil ? nil : walletId
        retried.headerFields[Self.walletAuthorization] = walletAuthToken

        // A rotated device may not be bound to this wallet yet, so the replay can legitimately fail
        // again. Rebinding belongs to the bindings reconcile, which demotes the wallet to `pending`.
        return try await next(retried, body, baseURL)
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
        recovery: MultichainWalletAuthDependencies
    ) -> [any ClientMiddleware] {
        var middlewares: [any ClientMiddleware] = []
        if let deviceJWT, !deviceJWT.isEmpty {
            middlewares.append(BearerTokenMiddleware(token: deviceJWT))
        }
        middlewares.append(
            WalletAuthHeaderMiddleware(walletId: walletId, walletAuthToken: walletAuthToken)
        )
        middlewares.append(
            WalletAuthRecoveryMiddleware(
                walletId: walletId,
                accessToken: deviceJWT,
                deviceAuth: recovery.deviceAuth,
                walletAuthTokenProvider: recovery.walletAuthTokenProvider
            )
        )
        return middlewares
    }
}
