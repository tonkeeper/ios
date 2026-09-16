@testable import KeeperCore
import XCTest

final class ChainKitSessionTokenProviderTests: XCTestCase {
    func test_getAccessToken_returnsTheAccessTokenOfTheSession() async {
        let deviceAuth = DeviceAuthFake(session: .success(.init(deviceId: "device-1", accessToken: "jwt-1")))
        let provider = ChainKitSessionTokenProvider(deviceAuth: deviceAuth)

        let token = await provider.getAccessToken()

        XCTAssertEqual(token, "jwt-1")
    }

    /// The provider is what registers an install that has no device yet, the same way the
    /// Android interceptor does.
    func test_getAccessToken_registersAnInstallWithoutADevice() async {
        let deviceAuth = DeviceAuthFake(session: .success(.init(deviceId: "device-1", accessToken: "jwt-1")))
        let provider = ChainKitSessionTokenProvider(deviceAuth: deviceAuth)

        let token = await provider.getAccessToken()

        XCTAssertEqual(token, "jwt-1")
        let sessionCount = await deviceAuth.sessionCount
        XCTAssertEqual(sessionCount, 1)
    }

    /// ChainKit distinguishes a thrown error from `nil`: only `nil` still fetches a manifest,
    /// unauthenticated, where a failure pins the node provider to the endpoints it already had.
    func test_getAccessToken_isNilWhenTheSessionCannotBeEstablished() async {
        let deviceAuth = DeviceAuthFake(session: .failure(.connectionError))
        let provider = ChainKitSessionTokenProvider(deviceAuth: deviceAuth)

        let token = await provider.getAccessToken()

        XCTAssertNil(token)
    }

    func test_getAccessToken_asksOncePerCallSoARotatedTokenIsPickedUp() async {
        let deviceAuth = DeviceAuthFake(session: .success(.init(deviceId: "device-1", accessToken: "jwt-1")))
        let provider = ChainKitSessionTokenProvider(deviceAuth: deviceAuth)

        let tokens = await withTaskGroup(of: String?.self) { group in
            for _ in 0 ..< 8 {
                group.addTask { await provider.getAccessToken() }
            }
            return await group.reduce(into: [String?]()) { $0.append($1) }
        }

        XCTAssertEqual(tokens.compactMap { $0 }, Array(repeating: "jwt-1", count: 8))
        let sessionCount = await deviceAuth.sessionCount
        XCTAssertEqual(sessionCount, 8)
    }

    /// ChainKit hands back the token a node rejected, and the ladder only renews when that token
    /// is still the current one — otherwise a concurrent renewal of ours would be spent twice.
    func test_refreshToken_recoversTheSessionForTheRejectedToken() async {
        let deviceAuth = DeviceAuthFake(
            session: .success(.init(deviceId: "device-1", accessToken: "jwt-1")),
            recovered: .success(.init(deviceId: "device-1", accessToken: "jwt-2"))
        )
        let provider = ChainKitSessionTokenProvider(deviceAuth: deviceAuth)

        let token = await provider.refreshToken(expiredToken: "jwt-1")

        XCTAssertEqual(token, "jwt-2")
        let invalidated = await deviceAuth.invalidatedTokens
        XCTAssertEqual(invalidated, ["jwt-1"])
    }

    func test_refreshToken_isNilWhenTheSessionCannotBeRecovered() async {
        let deviceAuth = DeviceAuthFake(
            session: .success(.init(deviceId: "device-1", accessToken: "jwt-1")),
            recovered: .failure(.connectionError)
        )
        let provider = ChainKitSessionTokenProvider(deviceAuth: deviceAuth)

        let token = await provider.refreshToken(expiredToken: "jwt-1")

        XCTAssertNil(token)
    }
}

private actor DeviceAuthFake: DeviceAuthProviding {
    private(set) var sessionCount = 0
    private(set) var invalidatedTokens = [String]()

    private let stored: Result<DeviceAuthSession, DeviceAuthError>
    private let recovered: Result<DeviceAuthSession, DeviceAuthError>

    init(
        session: Result<DeviceAuthSession, DeviceAuthError>,
        recovered: Result<DeviceAuthSession, DeviceAuthError> = .failure(.failed(message: "not expected"))
    ) {
        self.stored = session
        self.recovered = recovered
    }

    func session() async throws(DeviceAuthError) -> DeviceAuthSession {
        sessionCount += 1
        return try stored.get()
    }

    func recoverSession(invalidating accessToken: String) async throws(DeviceAuthError) -> DeviceAuthSession {
        invalidatedTokens.append(accessToken)
        return try recovered.get()
    }

    func isDeviceKnown() async -> Bool {
        (try? stored.get()) != nil
    }
}
