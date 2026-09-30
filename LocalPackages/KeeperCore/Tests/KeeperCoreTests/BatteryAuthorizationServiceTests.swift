import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class BatteryAuthorizationServiceTests: XCTestCase {
    func test_legacyWallet_usesOnlyTonProofAndSkipsDeviceSession() async throws {
        let tonProof = TonProofTokenServiceFake(token: "ton-proof")
        let deviceAuth = DeviceAuthFake()
        let service = BatteryAuthorizationService(
            tonProofTokenService: tonProof,
            deviceAuth: deviceAuth,
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )

        let authorization = try await service.authorization(for: makeWallet())
        let sessionCallCount = await deviceAuth.sessionCallCount

        XCTAssertEqual(authorization.tonProof, "ton-proof")
        XCTAssertNil(authorization.walletId)
        XCTAssertNil(authorization.deviceAccessToken)
        XCTAssertEqual(sessionCallCount, 0)
    }

    func test_multichainWallet_sendsTonProofAndWalletCredentialsTogether() async throws {
        let deviceAuth = DeviceAuthFake(sessionToken: "device-access-token")
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: "ton-proof"),
            deviceAuth: deviceAuth,
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )

        let authorization = try await service.authorization(
            for: makeWallet(multichainWalletId: "backend-wallet-id")
        )

        XCTAssertEqual(authorization.tonProof, "ton-proof")
        XCTAssertEqual(authorization.walletId, "backend-wallet-id")
        XCTAssertEqual(authorization.deviceAccessToken, "device-access-token")
    }

    func test_multichainWalletWithoutTonProof_stillAuthorizesByWalletId() async throws {
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: nil),
            deviceAuth: DeviceAuthFake(sessionToken: "device-access-token"),
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )

        let authorization = try await service.authorization(
            for: makeWallet(multichainWalletId: "backend-wallet-id")
        )

        XCTAssertNil(authorization.tonProof)
        XCTAssertEqual(authorization.deviceAccessToken, "device-access-token")
    }

    func test_multichainWalletWithoutDeviceSession_fallsBackToTonProof() async throws {
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: "ton-proof"),
            deviceAuth: DeviceAuthFake(sessionToken: ""),
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )

        let authorization = try await service.authorization(
            for: makeWallet(multichainWalletId: "backend-wallet-id")
        )

        XCTAssertEqual(authorization.tonProof, "ton-proof")
        XCTAssertEqual(authorization.walletId, "backend-wallet-id")
        XCTAssertNil(authorization.deviceAccessToken)
    }

    func test_missingLegacyCredentials_returnsUnavailable() async {
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: nil),
            deviceAuth: DeviceAuthFake(),
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )

        do {
            _ = try await service.authorization(for: makeWallet())
            XCTFail("Expected unavailable authorization")
        } catch {
            XCTAssertEqual(error as? BatteryAuthorizationError, .unavailable)
        }
    }

    func test_emptyLegacyCredentials_returnsUnavailable() async {
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: ""),
            deviceAuth: DeviceAuthFake(),
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )

        await assertAuthorizationUnavailable(for: makeWallet(), service: service)
    }

    func test_emptyWalletId_doesNotRequestDeviceSession() async throws {
        let deviceAuth = DeviceAuthFake(sessionToken: "device-access-token")
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: "ton-proof"),
            deviceAuth: deviceAuth,
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )

        let authorization = try await service.authorization(for: makeWallet(multichainWalletId: ""))
        let sessionCallCount = await deviceAuth.sessionCallCount

        XCTAssertEqual(authorization.tonProof, "ton-proof")
        XCTAssertNil(authorization.walletId)
        XCTAssertNil(authorization.deviceAccessToken)
        XCTAssertEqual(sessionCallCount, 0)
    }

    func test_neitherCredentialAvailable_returnsUnavailable() async {
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: nil),
            deviceAuth: DeviceAuthFake(sessionToken: ""),
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )

        await assertAuthorizationUnavailable(
            for: makeWallet(multichainWalletId: "backend-wallet-id"),
            service: service
        )
    }

    func test_multichainWallet_carriesTheWalletAuthTokenForItsSession() async throws {
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: nil),
            deviceAuth: DeviceAuthFake(sessionToken: "device-access-token"),
            walletAuthTokenProvider: WalletAuthTokenProviderStub(isWarm: true)
        )

        let authorization = try await service.authorization(
            for: makeWallet(multichainWalletId: "backend-wallet-id")
        )

        XCTAssertEqual(authorization.walletAuthToken, "signed(backend-wallet-id,device-access-token)")
    }

    func test_legacyWallet_carriesNoWalletAuthToken() async throws {
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: "ton-proof"),
            deviceAuth: DeviceAuthFake(),
            walletAuthTokenProvider: WalletAuthTokenProviderStub(isWarm: true)
        )

        let authorization = try await service.authorization(for: makeWallet())

        XCTAssertNil(authorization.walletAuthToken)
    }

    /// The wallet token signs the access token, so the one minted for the expired session cannot be
    /// replayed against the recovered one.
    func test_recoveredSession_remintsTheWalletAuthToken() async throws {
        let deviceAuth = DeviceAuthFake(sessionToken: "expired-token", recoveredToken: "fresh-token")
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: nil),
            deviceAuth: deviceAuth,
            walletAuthTokenProvider: WalletAuthTokenProviderStub(isWarm: true)
        )
        let wallet = makeWallet(multichainWalletId: "backend-wallet-id")
        var authorizations = [BatteryAuthorization]()

        _ = try await service.withAuthorization(for: wallet) { authorization -> String in
            authorizations.append(authorization)
            if authorizations.count == 1 {
                throw BatteryAPI.ApiError.badStatus(status: 401, message: "expired")
            }
            return "success"
        }

        XCTAssertEqual(
            authorizations.map(\.walletAuthToken),
            [
                "signed(backend-wallet-id,expired-token)",
                "signed(backend-wallet-id,fresh-token)",
            ]
        )
    }

    func test_multichainUnauthorized_recoversSessionAndRetriesOnce() async throws {
        let deviceAuth = DeviceAuthFake(sessionToken: "expired-token", recoveredToken: "fresh-token")
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: nil),
            deviceAuth: deviceAuth,
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )
        let wallet = makeWallet(multichainWalletId: "backend-wallet-id")
        var authorizations = [BatteryAuthorization]()

        let result: String = try await service.withAuthorization(for: wallet) { authorization in
            authorizations.append(authorization)
            if authorizations.count == 1 {
                throw BatteryAPI.ApiError.badStatus(status: 401, message: "expired")
            }
            return "success"
        }
        let recoveredTokens = await deviceAuth.recoveredTokens

        XCTAssertEqual(result, "success")
        XCTAssertEqual(authorizations.map(\.deviceAccessToken), ["expired-token", "fresh-token"])
        XCTAssertEqual(recoveredTokens, ["expired-token"])
    }

    func test_secondMultichainUnauthorized_isNotRetriedAgain() async {
        let deviceAuth = DeviceAuthFake(sessionToken: "expired-token", recoveredToken: "fresh-token")
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: nil),
            deviceAuth: deviceAuth,
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )
        var requestCount = 0

        do {
            let _: Void = try await service.withAuthorization(
                for: makeWallet(multichainWalletId: "backend-wallet-id")
            ) { _ in
                requestCount += 1
                throw BatteryAPI.ApiError.badStatus(status: 401, message: "expired")
            }
            XCTFail("Expected the repeated 401")
        } catch let error as BatteryAPI.ApiError {
            guard case let .badStatus(status, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(status, 401)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        let recoveredTokens = await deviceAuth.recoveredTokens

        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(recoveredTokens, ["expired-token"])
    }

    func test_legacyUnauthorized_doesNotRecoverDeviceSession() async {
        let deviceAuth = DeviceAuthFake()
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: "ton-proof"),
            deviceAuth: deviceAuth,
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )
        var requestCount = 0

        do {
            let _: Void = try await service.withAuthorization(for: makeWallet()) { _ in
                requestCount += 1
                throw BatteryAPI.ApiError.badStatus(status: 401, message: "expired")
            }
            XCTFail("Expected 401")
        } catch {}
        let recoveredTokens = await deviceAuth.recoveredTokens

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(recoveredTokens, [])
    }

    func test_optionalAuthorization_withoutAnyCredentials_stillRunsUnauthorized() async throws {
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: nil),
            deviceAuth: DeviceAuthFake(sessionToken: ""),
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )
        var authorizations = [BatteryAuthorization]()

        let result: String = try await service.withOptionalAuthorization(
            for: makeWallet(multichainWalletId: "backend-wallet-id")
        ) { authorization in
            authorizations.append(authorization)
            return "estimate"
        }

        XCTAssertEqual(result, "estimate")
        XCTAssertEqual(authorizations, [.none])
    }

    func test_optionalAuthorization_sendsCredentialsWhenTheWalletHasThem() async throws {
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: "ton-proof"),
            deviceAuth: DeviceAuthFake(sessionToken: "device-access-token"),
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )

        let authorization: BatteryAuthorization = try await service.withOptionalAuthorization(
            for: makeWallet(multichainWalletId: "backend-wallet-id")
        ) { $0 }

        XCTAssertEqual(authorization.tonProof, "ton-proof")
        XCTAssertEqual(authorization.deviceAccessToken, "device-access-token")
    }

    func test_optionalAuthorization_recoversExpiredSession() async throws {
        let deviceAuth = DeviceAuthFake(sessionToken: "expired-token", recoveredToken: "fresh-token")
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: nil),
            deviceAuth: deviceAuth,
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )
        var authorizations = [BatteryAuthorization]()

        let result: String = try await service.withOptionalAuthorization(
            for: makeWallet(multichainWalletId: "backend-wallet-id")
        ) { authorization in
            authorizations.append(authorization)
            if authorizations.count == 1 {
                throw BatteryAPI.ApiError.badStatus(status: 401, message: "expired")
            }
            return "estimate"
        }

        XCTAssertEqual(result, "estimate")
        XCTAssertEqual(authorizations.map(\.deviceAccessToken), ["expired-token", "fresh-token"])
    }

    func test_recoveryWithIncompleteCredentials_doesNotRepeatRequest() async {
        let deviceAuth = DeviceAuthFake(sessionToken: "expired-token", recoveredToken: "")
        let service = BatteryAuthorizationService(
            tonProofTokenService: TonProofTokenServiceFake(token: nil),
            deviceAuth: deviceAuth,
            walletAuthTokenProvider: WalletAuthTokenProviderStub()
        )
        var requestCount = 0

        do {
            let _: Void = try await service.withAuthorization(
                for: makeWallet(multichainWalletId: "backend-wallet-id")
            ) { _ in
                requestCount += 1
                throw BatteryAPI.ApiError.badStatus(status: 401, message: "expired")
            }
            XCTFail("Expected unavailable authorization")
        } catch {
            XCTAssertEqual(error as? BatteryAuthorizationError, .unavailable)
        }

        XCTAssertEqual(requestCount, 1)
    }
}

private extension BatteryAuthorizationServiceTests {
    func assertAuthorizationUnavailable(
        for wallet: Wallet,
        service: BatteryAuthorizationService,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await service.authorization(for: wallet)
            XCTFail("Expected unavailable authorization", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? BatteryAuthorizationError, .unavailable, file: file, line: line)
        }
    }

    func makeWallet(
        publicKeyData: Data = Data(repeating: 1, count: 32),
        multichainWalletId: String? = nil
    ) -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: publicKeyData), .v4R2)
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: multichainWalletId.map {
                .multichain(
                    MultichainWalletState(
                        walletId: $0,
                        addresses: [MultichainWalletAddress(chain: .ton, address: "ton-address")]
                    )
                )
            }
        )
    }
}

private struct WalletAuthTokenProviderStub: WalletAuthTokenProviding {
    /// `false` stands for a wallet whose app key was never derived this session.
    var isWarm = false

    func token(walletId: String, accessToken: String) async -> String? {
        guard isWarm else {
            return nil
        }
        return "signed(\(walletId),\(accessToken))"
    }

    func invalidateToken(walletId _: String) async {}

    func hasPersistentAppKey(walletId _: String) async -> Bool {
        isWarm
    }

    func warm(walletId _: String, mnemonic _: String) async {}
    func forget(walletId _: String) async {}
    func wipe() async {}
}

private final class TonProofTokenServiceFake: TonProofTokenService {
    private let token: String?

    init(token: String?) {
        self.token = token
    }

    func getWalletToken(_: Wallet) throws -> String {
        guard let token else {
            throw BatteryAuthorizationError.unavailable
        }
        return token
    }

    func getWalletsWithMissedToken() -> [Wallet] {
        []
    }

    func loadTokensFor(pairs _: [WalletPrivateKeyPair]) async {}
}

private actor DeviceAuthFake: DeviceAuthProviding {
    private let sessionToken: String
    private let recoveredToken: String
    private(set) var sessionCallCount = 0
    private(set) var recoveredTokens = [String]()

    init(sessionToken: String = "session-token", recoveredToken: String = "recovered-token") {
        self.sessionToken = sessionToken
        self.recoveredToken = recoveredToken
    }

    func session() async throws(DeviceAuthError) -> DeviceAuthSession {
        sessionCallCount += 1
        return DeviceAuthSession(deviceId: "device-id", accessToken: sessionToken)
    }

    func recoverSession(invalidating accessToken: String) async throws(DeviceAuthError) -> DeviceAuthSession {
        recoveredTokens.append(accessToken)
        return DeviceAuthSession(deviceId: "device-id", accessToken: recoveredToken)
    }

    func isDeviceKnown() -> Bool {
        true
    }
}
