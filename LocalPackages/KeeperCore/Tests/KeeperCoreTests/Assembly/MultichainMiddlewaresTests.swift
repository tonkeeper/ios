import Foundation
import HTTPTypes
@testable import KeeperCore
import MultichainAPI
import OpenAPIRuntime
import XCTest

final class MultichainMiddlewaresTests: XCTestCase {
    func test_deviceSessionMiddleware_attachesTheCurrentAccessToken() async throws {
        let request = try await send(
            middlewares: [
                DeviceSessionMiddleware(
                    deviceAuth: DeviceAuthRecoveryFake(
                        recovered: .init(deviceId: "device-1", accessToken: "fresh-jwt")
                    )
                ),
            ],
            operationID: MultichainAPI.Operations.searchAssets.id
        )

        XCTAssertEqual(request.headerFields[.authorization], "Bearer stale-jwt")
    }

    func test_deviceSessionMiddleware_unauthorizedRecoversAndReplaysOnce() async throws {
        let deviceAuth = DeviceAuthRecoveryFake(
            recovered: .init(deviceId: "device-1", accessToken: "fresh-jwt")
        )
        let attempts = try await attempts(
            middlewares: [DeviceSessionMiddleware(deviceAuth: deviceAuth)],
            operationID: MultichainAPI.Operations.broadcastTx.id,
            body: HTTPBody(Data("{}".utf8)),
            responses: [HTTPResponse(status: .unauthorized), HTTPResponse(status: .ok)]
        )

        XCTAssertEqual(attempts.requests.map { $0.headerFields[.authorization] }, [
            "Bearer stale-jwt",
            "Bearer fresh-jwt",
        ])
        XCTAssertEqual(deviceAuth.invalidated, ["stale-jwt"])
        XCTAssertEqual(attempts.response.status, .ok)
    }

    func test_deviceSessionMiddleware_recoveryFailureIsReported() async {
        let deviceAuth = DeviceAuthRecoveryFake(recovered: nil)

        do {
            _ = try await attempts(
                middlewares: [DeviceSessionMiddleware(deviceAuth: deviceAuth)],
                responses: [HTTPResponse(status: .unauthorized)]
            )
            XCTFail("expected recovery to fail")
        } catch let error as DeviceAuthError {
            XCTAssertEqual(error, .unauthorized(reason: DeviceAuthRevocation.revokedReason))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_deviceSessionMiddleware_repeatedUnauthorizedStopsAfterOneReplay() async throws {
        let attempts = try await attempts(
            middlewares: [
                DeviceSessionMiddleware(
                    deviceAuth: DeviceAuthRecoveryFake(
                        recovered: .init(deviceId: "device-1", accessToken: "fresh-jwt")
                    )
                ),
            ],
            responses: [HTTPResponse(status: .unauthorized)]
        )

        XCTAssertEqual(attempts.requests.count, 2)
        XCTAssertEqual(attempts.response.status, .unauthorized)
    }

    func test_deviceSessionMiddleware_doesNotReplayASinglePassBody() async throws {
        let deviceAuth = DeviceAuthRecoveryFake(
            recovered: .init(deviceId: "device-1", accessToken: "fresh-jwt")
        )
        let attempts = try await attempts(
            middlewares: [DeviceSessionMiddleware(deviceAuth: deviceAuth)],
            body: HTTPBody(
                AsyncStream<[UInt8]> { continuation in
                    continuation.yield(Array("{}".utf8))
                    continuation.finish()
                },
                length: .unknown,
                iterationBehavior: .single
            ),
            responses: [HTTPResponse(status: .unauthorized)]
        )

        XCTAssertEqual(attempts.requests.count, 1)
        XCTAssertEqual(deviceAuth.invalidated, [])
    }

    func test_deviceSessionMiddleware_rejectsAnEmptySessionWithoutSendingTheRequest() async {
        let deviceAuth = DeviceAuthRecoveryFake(
            session: .init(deviceId: "device-1", accessToken: ""),
            recovered: nil
        )

        do {
            _ = try await attempts(middlewares: [DeviceSessionMiddleware(deviceAuth: deviceAuth)])
            XCTFail("expected the empty session to fail")
        } catch let error as DeviceAuthError {
            XCTAssertEqual(error, .failed(message: "empty device access token"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_deviceSessionMiddleware_reportsSessionResolutionFailure() async {
        let deviceAuth = DeviceAuthRecoveryFake(
            recovered: nil,
            sessionError: .connectionError
        )

        do {
            _ = try await attempts(middlewares: [DeviceSessionMiddleware(deviceAuth: deviceAuth)])
            XCTFail("expected session resolution to fail")
        } catch let error as DeviceAuthError {
            XCTAssertEqual(error, .connectionError)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_walletAuthStack_sendsBearerAndWalletCredentialTogether() async throws {
        let request = try await send(
            middlewares: [
                BearerTokenMiddleware(token: "device-jwt"),
                WalletAuthHeaderMiddleware(walletId: "wallet-id", walletAuthToken: "wallet-auth-token"),
            ],
            operationID: MultichainAPI.Operations.getWalletActivities.id
        )

        XCTAssertEqual(request.headerFields[.authorization], "Bearer device-jwt")
        XCTAssertEqual(try request.headerFields[XCTUnwrap(.init("X-Wallet-ID"))], "wallet-id")
        XCTAssertEqual(
            try request.headerFields[XCTUnwrap(.init("X-Wallet-Authorization"))],
            "wallet-auth-token"
        )
    }

    /// Without a credential the wallet id says nothing the backend can verify, so neither header
    /// travels and the request looks exactly as it did before wallet auth existed.
    func test_walletAuthMiddleware_withoutToken_sendsNeitherHeader() async throws {
        let request = try await send(
            middlewares: [WalletAuthHeaderMiddleware(walletId: "wallet-id", walletAuthToken: nil)],
            operationID: MultichainAPI.Operations.getWalletActivities.id
        )

        XCTAssertNil(try request.headerFields[XCTUnwrap(.init("X-Wallet-ID"))])
        XCTAssertNil(try request.headerFields[XCTUnwrap(.init("X-Wallet-Authorization"))])
    }

    /// An extension can drop the graph that owns the session before a client is built from it.
    /// The request still goes out with whatever was resolved, and a rejection stands: nothing is
    /// left that could mint a fresh credential to replay with.
    func test_walletAuthStack_withoutRecovery_sendsTheRequestAndDoesNotRetry() async throws {
        let attempts = try await attempts(
            middlewares: WalletAuthClientMiddlewares.make(
                deviceJWT: "device-jwt",
                walletId: "wallet-id",
                walletAuthToken: "wallet-auth-token",
                recovery: nil
            ),
            operationID: MultichainAPI.Operations.getWalletActivities.id,
            responses: [HTTPResponse(status: .unauthorized), HTTPResponse(status: .ok)]
        )

        XCTAssertEqual(attempts.requests.count, 1)
        XCTAssertEqual(attempts.response.status, .unauthorized)
        XCTAssertEqual(attempts.requests.first?.headerFields[.authorization], "Bearer device-jwt")
    }

    /// The access token these operations carry lives 15 minutes, so a rejected one has to be
    /// refreshed and the request replayed rather than surfaced as a failed load.
    func test_unauthorized_refreshesTheSessionAndReplaysTheRequest() async throws {
        let deviceAuth = DeviceAuthRecoveryFake(recovered: .init(deviceId: "device-1", accessToken: "fresh-jwt"))
        let attempts = try await attempts(
            middlewares: recoveringStack(deviceAuth: deviceAuth),
            responses: [HTTPResponse(status: .unauthorized), HTTPResponse(status: .ok)]
        )

        XCTAssertEqual(attempts.requests.count, 2)
        XCTAssertEqual(attempts.response.status, .ok)
        XCTAssertEqual(deviceAuth.invalidated, ["stale-jwt"])
        let retried = try XCTUnwrap(attempts.requests.last)
        XCTAssertEqual(retried.headerFields[.authorization], "Bearer fresh-jwt")
        // The credential is reminted for the token it now travels with, not carried over.
        XCTAssertEqual(
            try retried.headerFields[XCTUnwrap(.init("X-Wallet-Authorization"))],
            "signed(wallet-id,fresh-jwt)"
        )
        XCTAssertEqual(try retried.headerFields[XCTUnwrap(.init("X-Wallet-ID"))], "wallet-id")
    }

    /// A credential signed over the retired access token cannot verify against the new one, so a
    /// wallet whose key is unavailable retries with the device session alone — never with the stale
    /// header the first attempt carried.
    func test_unauthorized_whenTheCredentialCannotBeReminted_dropsTheWalletHeaders() async throws {
        let attempts = try await attempts(
            middlewares: recoveringStack(
                deviceAuth: DeviceAuthRecoveryFake(recovered: .init(deviceId: "device-1", accessToken: "fresh-jwt")),
                walletAuth: WalletAuthTokenFake(hasAppKey: false)
            ),
            responses: [HTTPResponse(status: .unauthorized), HTTPResponse(status: .ok)]
        )

        XCTAssertEqual(attempts.requests.count, 2)
        let first = try XCTUnwrap(attempts.requests.first)
        try XCTAssertEqual(
            first.headerFields[XCTUnwrap(.init("X-Wallet-Authorization"))],
            "signed(wallet-id,stale-jwt)"
        )
        let retried = try XCTUnwrap(attempts.requests.last)
        XCTAssertEqual(retried.headerFields[.authorization], "Bearer fresh-jwt")
        XCTAssertNil(try retried.headerFields[XCTUnwrap(.init("X-Wallet-Authorization"))])
        XCTAssertNil(try retried.headerFields[XCTUnwrap(.init("X-Wallet-ID"))])
    }

    func test_successfulRequest_isNotRetriedAndNeedsNoRefresh() async throws {
        let deviceAuth = DeviceAuthRecoveryFake(recovered: .init(deviceId: "device-1", accessToken: "fresh-jwt"))
        let attempts = try await attempts(
            middlewares: recoveringStack(deviceAuth: deviceAuth),
            responses: [HTTPResponse(status: .ok)]
        )

        XCTAssertEqual(attempts.requests.count, 1)
        XCTAssertEqual(deviceAuth.invalidated, [])
    }

    /// Recovery buys one replay, not a loop: the second rejection is the caller's answer.
    func test_unauthorizedTwice_retriesOnceAndReportsTheSecondRejection() async throws {
        let attempts = try await attempts(
            middlewares: recoveringStack(
                deviceAuth: DeviceAuthRecoveryFake(recovered: .init(deviceId: "device-1", accessToken: "fresh-jwt"))
            ),
            responses: [HTTPResponse(status: .unauthorized)]
        )

        XCTAssertEqual(attempts.requests.count, 2)
        XCTAssertEqual(attempts.response.status, .unauthorized)
    }

    /// Nothing to replay with: a failed recovery, or one that hands back the token that was just
    /// rejected, leaves the 401 as it was.
    func test_unauthorized_withoutAUsableFreshToken_isNotRetried() async throws {
        for recovered in [nil, DeviceAuthSession(deviceId: "device-1", accessToken: "stale-jwt")] {
            let attempts = try await attempts(
                middlewares: recoveringStack(deviceAuth: DeviceAuthRecoveryFake(recovered: recovered)),
                responses: [HTTPResponse(status: .unauthorized)]
            )

            XCTAssertEqual(attempts.requests.count, 1)
            XCTAssertEqual(attempts.response.status, .unauthorized)
        }
    }

    /// Every generated JSON body is `Data`-backed and replayable, but a streamed one could only be
    /// sent once — so it is left alone rather than half-resent.
    func test_unauthorized_withASinglePassBody_isNotRetried() async throws {
        let attempts = try await attempts(
            middlewares: recoveringStack(
                deviceAuth: DeviceAuthRecoveryFake(recovered: .init(deviceId: "device-1", accessToken: "fresh-jwt"))
            ),
            body: HTTPBody(
                AsyncStream<[UInt8]> { continuation in
                    continuation.yield(Array("{}".utf8))
                    continuation.finish()
                },
                length: .unknown,
                iterationBehavior: .single
            ),
            responses: [HTTPResponse(status: .unauthorized)]
        )

        XCTAssertEqual(attempts.requests.count, 1)
    }

    func test_replayableBody_isRetried() async throws {
        let attempts = try await attempts(
            middlewares: recoveringStack(
                deviceAuth: DeviceAuthRecoveryFake(recovered: .init(deviceId: "device-1", accessToken: "fresh-jwt"))
            ),
            body: HTTPBody(Data("{}".utf8)),
            responses: [HTTPResponse(status: .unauthorized), HTTPResponse(status: .ok)]
        )

        XCTAssertEqual(attempts.requests.count, 2)
    }

    /// The credentials are captured when the client is built, and on a cold launch the device
    /// session is not resolved yet — the access token is memory-only. Rather than go out bare and
    /// collect a `wallet_proof_required`, the request picks both up here, at the moment it is sent.
    func test_missingCredentials_areResolvedBeforeTheFirstAttempt() async throws {
        let deviceAuth = DeviceAuthRecoveryFake(recovered: nil)
        let attempts = try await attempts(
            middlewares: stack(deviceJWT: "", walletAuthToken: nil, deviceAuth: deviceAuth)
        )

        XCTAssertEqual(attempts.requests.count, 1)
        // Nothing was rejected, so the session is read rather than renewed.
        XCTAssertEqual(deviceAuth.invalidated, [])
        let sent = try XCTUnwrap(attempts.requests.first)
        XCTAssertEqual(sent.headerFields[.authorization], "Bearer stale-jwt")
        XCTAssertEqual(
            try sent.headerFields[XCTUnwrap(.init("X-Wallet-Authorization"))],
            "signed(wallet-id,stale-jwt)"
        )
        XCTAssertEqual(try sent.headerFields[XCTUnwrap(.init("X-Wallet-ID"))], "wallet-id")
    }

    /// A session resolved here is the one a 401 then invalidates, so the recovery works for a
    /// request the stack above could not credential at all.
    func test_unauthorized_afterResolvingTheSessionHere_recoversAndReplays() async throws {
        let deviceAuth = DeviceAuthRecoveryFake(recovered: .init(deviceId: "device-1", accessToken: "fresh-jwt"))
        let attempts = try await attempts(
            middlewares: stack(deviceJWT: "", walletAuthToken: nil, deviceAuth: deviceAuth),
            responses: [HTTPResponse(status: .unauthorized), HTTPResponse(status: .ok)]
        )

        XCTAssertEqual(attempts.requests.count, 2)
        XCTAssertEqual(attempts.response.status, .ok)
        XCTAssertEqual(deviceAuth.invalidated, ["stale-jwt"])
        let retried = try XCTUnwrap(attempts.requests.last)
        XCTAssertEqual(retried.headerFields[.authorization], "Bearer fresh-jwt")
        XCTAssertEqual(
            try retried.headerFields[XCTUnwrap(.init("X-Wallet-Authorization"))],
            "signed(wallet-id,fresh-jwt)"
        )
    }

    /// Credentials the stack above did apply are left alone: re-resolving them would be a Keychain
    /// read on every request for a token that is already there.
    func test_appliedCredentials_areNotReresolved() async throws {
        let walletAuth = WalletAuthTokenFake()
        let attempts = try await attempts(
            middlewares: stack(
                deviceJWT: "stale-jwt",
                walletAuthToken: "stale-credential",
                deviceAuth: DeviceAuthRecoveryFake(recovered: nil),
                walletAuth: walletAuth
            )
        )

        let sent = try XCTUnwrap(attempts.requests.first)
        XCTAssertEqual(sent.headerFields[.authorization], "Bearer stale-jwt")
        XCTAssertEqual(
            try sent.headerFields[XCTUnwrap(.init("X-Wallet-Authorization"))],
            "stale-credential"
        )
        XCTAssertEqual(walletAuth.invalidated, [])
    }

    /// The 403 the ticket reports: the device session was accepted and the wallet credential was
    /// not, so the credential is dropped and reminted rather than the session refreshed.
    func test_forbidden_remintsTheWalletCredentialAndReplaysOnce() async throws {
        let deviceAuth = DeviceAuthRecoveryFake(recovered: nil)
        let walletAuth = WalletAuthTokenFake()
        let attempts = try await attempts(
            middlewares: stack(
                deviceJWT: "stale-jwt",
                walletAuthToken: "stale-credential",
                deviceAuth: deviceAuth,
                walletAuth: walletAuth
            ),
            responses: [HTTPResponse(status: .forbidden), HTTPResponse(status: .ok)]
        )

        XCTAssertEqual(attempts.requests.count, 2)
        XCTAssertEqual(attempts.response.status, .ok)
        XCTAssertEqual(walletAuth.invalidated, ["wallet-id"])
        // The device session is intact, so it is neither invalidated nor rotated.
        XCTAssertEqual(deviceAuth.invalidated, [])
        let retried = try XCTUnwrap(attempts.requests.last)
        XCTAssertEqual(retried.headerFields[.authorization], "Bearer stale-jwt")
        XCTAssertEqual(
            try retried.headerFields[XCTUnwrap(.init("X-Wallet-Authorization"))],
            "signed(wallet-id,stale-jwt)"
        )
        XCTAssertEqual(try retried.headerFields[XCTUnwrap(.init("X-Wallet-ID"))], "wallet-id")
    }

    /// A wallet this install has no app key for has nothing to remint, and a device the backend has
    /// no binding for is not something the client can repair — so the 403 stands without spending a
    /// second round trip on identical headers.
    func test_forbidden_withNothingToRemint_isNotRetried() async throws {
        let walletAuth = WalletAuthTokenFake(hasAppKey: false)
        let attempts = try await attempts(
            middlewares: stack(
                deviceJWT: "stale-jwt",
                walletAuthToken: nil,
                deviceAuth: DeviceAuthRecoveryFake(recovered: nil),
                walletAuth: walletAuth
            ),
            responses: [HTTPResponse(status: .forbidden)]
        )

        XCTAssertEqual(attempts.requests.count, 1)
        XCTAssertEqual(attempts.response.status, .forbidden)
        XCTAssertEqual(walletAuth.invalidated, ["wallet-id"])
    }

    /// The remint buys one replay, not a loop.
    func test_forbiddenTwice_retriesOnceAndReportsTheSecondRejection() async throws {
        let attempts = try await attempts(
            middlewares: stack(
                deviceJWT: "stale-jwt",
                walletAuthToken: "stale-credential",
                deviceAuth: DeviceAuthRecoveryFake(recovered: nil)
            ),
            responses: [HTTPResponse(status: .forbidden)]
        )

        XCTAssertEqual(attempts.requests.count, 2)
        XCTAssertEqual(attempts.response.status, .forbidden)
    }

    /// Without a session there is nothing to sign a credential over — not before the request and
    /// not after — so the 403 is left as it was rather than replayed with the same empty headers.
    func test_forbidden_whenTheSessionCannotBeResolved_isNotRetried() async throws {
        let attempts = try await attempts(
            middlewares: stack(
                deviceJWT: "",
                walletAuthToken: nil,
                deviceAuth: DeviceAuthRecoveryFake(recovered: nil, sessionError: .connectionError)
            ),
            responses: [HTTPResponse(status: .forbidden)]
        )

        XCTAssertEqual(attempts.requests.count, 1)
        XCTAssertEqual(attempts.response.status, .forbidden)
    }

    func test_forbidden_withASinglePassBody_isNotRetried() async throws {
        let walletAuth = WalletAuthTokenFake()
        let attempts = try await attempts(
            middlewares: stack(
                deviceJWT: "stale-jwt",
                walletAuthToken: "stale-credential",
                deviceAuth: DeviceAuthRecoveryFake(recovered: nil),
                walletAuth: walletAuth
            ),
            body: HTTPBody(
                AsyncStream<[UInt8]> { continuation in
                    continuation.yield(Array("{}".utf8))
                    continuation.finish()
                },
                length: .unknown,
                iterationBehavior: .single
            ),
            responses: [HTTPResponse(status: .forbidden)]
        )

        XCTAssertEqual(attempts.requests.count, 1)
        XCTAssertEqual(walletAuth.invalidated, [])
    }

    /// Only the two rejections the credentials can explain are repaired; anything else is the
    /// caller's answer.
    func test_otherStatuses_areNotRetried() async throws {
        for status in [HTTPResponse.Status.notFound, .tooManyRequests, .internalServerError] {
            let walletAuth = WalletAuthTokenFake()
            let attempts = try await attempts(
                middlewares: stack(
                    deviceJWT: "stale-jwt",
                    walletAuthToken: "stale-credential",
                    deviceAuth: DeviceAuthRecoveryFake(recovered: nil),
                    walletAuth: walletAuth
                ),
                responses: [HTTPResponse(status: status)]
            )

            XCTAssertEqual(attempts.requests.count, 1)
            XCTAssertEqual(walletAuth.invalidated, [])
        }
    }

    func test_deviceAuthStack_sendsFirebaseUserIdAndAuthorizationForBindings() async throws {
        let request = try await send(
            middlewares: [
                FirebaseUserIdHeaderMiddleware(
                    firebaseUserIdProvider: { "firebase-user-id" },
                    operationIDs: [MultichainAPI.Operations.getDeviceBindings.id]
                ),
                BearerTokenMiddleware(token: "device-jwt"),
            ]
        )

        XCTAssertEqual(try request.headerFields[XCTUnwrap(.init("F"))], "firebase-user-id")
        XCTAssertEqual(request.headerFields[.authorization], "Bearer device-jwt")
    }

    func test_deviceAuthStack_doesNotSendFirebaseUserIdForOtherOperations() async throws {
        let request = try await send(
            middlewares: [
                FirebaseUserIdHeaderMiddleware(
                    firebaseUserIdProvider: { "firebase-user-id" },
                    operationIDs: [MultichainAPI.Operations.getDeviceBindings.id]
                ),
            ],
            operationID: MultichainAPI.Operations.registerWallets.id
        )

        XCTAssertNil(try request.headerFields[XCTUnwrap(.init("F"))])
    }

    func test_firebaseUserIdMiddleware_skipsMissingIdentity() async throws {
        for firebaseUserId in [nil, ""] as [String?] {
            let request = try await send(
                middlewares: [
                    FirebaseUserIdHeaderMiddleware(
                        firebaseUserIdProvider: { firebaseUserId },
                        operationIDs: [MultichainAPI.Operations.getDeviceBindings.id]
                    ),
                ]
            )

            XCTAssertNil(try request.headerFields[XCTUnwrap(.init("F"))])
        }
    }
}

private extension MultichainMiddlewaresTests {
    /// The wallet-scoped stack as `APIAssembly` builds it: credentials first, recovery innermost.
    func recoveringStack(
        deviceAuth: DeviceAuthRecoveryFake,
        walletAuth: WalletAuthTokenFake = WalletAuthTokenFake(),
        accessToken: String = "stale-jwt"
    ) -> [any ClientMiddleware] {
        stack(
            deviceJWT: accessToken,
            walletAuthToken: "signed(wallet-id,\(accessToken))",
            deviceAuth: deviceAuth,
            walletAuth: walletAuth
        )
    }

    func stack(
        deviceJWT: String,
        walletAuthToken: String?,
        deviceAuth: DeviceAuthRecoveryFake,
        walletAuth: WalletAuthTokenFake = WalletAuthTokenFake()
    ) -> [any ClientMiddleware] {
        WalletAuthClientMiddlewares.make(
            deviceJWT: deviceJWT,
            walletId: "wallet-id",
            walletAuthToken: walletAuthToken,
            recovery: MultichainWalletAuthDependencies(
                deviceAuth: deviceAuth,
                walletAuthTokenProvider: walletAuth
            )
        )
    }

    /// Runs the stack the same way the generated client does and returns what would hit the wire.
    func send(
        middlewares: [any ClientMiddleware],
        operationID: String = MultichainAPI.Operations.getDeviceBindings.id,
        request: HTTPRequest = .bindings
    ) async throws -> HTTPRequest {
        let attempts = try await attempts(
            middlewares: middlewares,
            operationID: operationID,
            request: request
        )
        return try XCTUnwrap(attempts.requests.first)
    }

    /// Answers each attempt with the next scripted response — the last one repeats — and records
    /// every request, so a middleware that retries can be asserted on both attempts.
    func attempts(
        middlewares: [any ClientMiddleware],
        operationID: String = MultichainAPI.Operations.getDeviceBindings.id,
        request: HTTPRequest = .bindings,
        body: HTTPBody? = nil,
        responses: [HTTPResponse] = [HTTPResponse(status: .ok)]
    ) async throws -> (requests: [HTTPRequest], response: HTTPResponse) {
        let captured = CapturedRequests()
        var next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?) = { request, _, _ in
            let index = captured.append(request)
            return (responses[min(index, responses.count - 1)], nil)
        }
        for middleware in middlewares.reversed() {
            let downstream = next
            next = { request, body, baseURL in
                try await middleware.intercept(
                    request,
                    body: body,
                    baseURL: baseURL,
                    operationID: operationID,
                    next: downstream
                )
            }
        }

        let (response, _) = try await next(request, body, URL(string: "https://multi.tonkeeper.com")!)
        return (captured.requests, response)
    }
}

private extension HTTPRequest {
    static let bindings = HTTPRequest(
        method: .post,
        scheme: nil,
        authority: nil,
        path: "/api/v2/devices/bindings"
    )
}

private final class DeviceAuthRecoveryFake: DeviceAuthProviding, @unchecked Sendable {
    /// `nil` makes recovery fail, which is what a device the backend revoked looks like.
    let current: DeviceAuthSession
    let recovered: DeviceAuthSession?
    let sessionError: DeviceAuthError?
    private(set) var invalidated = [String]()

    init(
        session: DeviceAuthSession = .init(deviceId: "device-1", accessToken: "stale-jwt"),
        recovered: DeviceAuthSession?,
        sessionError: DeviceAuthError? = nil
    ) {
        current = session
        self.recovered = recovered
        self.sessionError = sessionError
    }

    func session() async throws(DeviceAuthError) -> DeviceAuthSession {
        if let sessionError {
            throw sessionError
        }
        return current
    }

    func recoverSession(invalidating accessToken: String) async throws(DeviceAuthError) -> DeviceAuthSession {
        invalidated.append(accessToken)
        guard let recovered else {
            throw .unauthorized(reason: DeviceAuthRevocation.revokedReason)
        }
        return recovered
    }

    func isDeviceKnown() async -> Bool {
        true
    }
}

private final class WalletAuthTokenFake: WalletAuthTokenProviding, @unchecked Sendable {
    private let hasAppKey: Bool
    private(set) var invalidated = [String]()

    init(hasAppKey: Bool = true) {
        self.hasAppKey = hasAppKey
    }

    func token(walletId: String, accessToken: String) async -> String? {
        hasAppKey ? "signed(\(walletId),\(accessToken))" : nil
    }

    func invalidateToken(walletId: String) async {
        invalidated.append(walletId)
    }

    func hasPersistentAppKey(walletId _: String) async -> Bool {
        hasAppKey
    }

    func warm(walletId _: String, mnemonic _: String) async {}
    func forget(walletId _: String) async {}
    func wipe() async {}
}

private final class CapturedRequests: @unchecked Sendable {
    private(set) var requests = [HTTPRequest]()

    /// Returns the attempt's index, so the caller can pick the response scripted for it.
    func append(_ request: HTTPRequest) -> Int {
        requests.append(request)
        return requests.count - 1
    }
}
