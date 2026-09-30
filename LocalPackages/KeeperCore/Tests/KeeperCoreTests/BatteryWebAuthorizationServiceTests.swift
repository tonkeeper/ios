import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class BatteryWebAuthorizationServiceTests: XCTestCase {
    func test_getData_usesCurrentSessionAndSignsWalletToken() async throws {
        let deviceAuth = DeviceAuthFake(sessionToken: "device-token")
        let service = makeService(deviceAuth: deviceAuth, walletAuth: WalletAuthTokenProviderStub(isWarm: true))

        let authorization = try await service.authorization(
            for: makeWallet(multichainWalletId: "backend-wallet-id"),
            expiredDeviceToken: nil
        )
        let sessionCallCount = await deviceAuth.sessionCallCount
        let recoveredTokens = await deviceAuth.recoveredTokens

        XCTAssertEqual(
            authorization,
            BatteryWebAuthorization(
                walletId: "backend-wallet-id",
                deviceToken: "device-token",
                walletToken: "signed(backend-wallet-id,device-token)"
            )
        )
        XCTAssertEqual(sessionCallCount, 1)
        XCTAssertEqual(recoveredTokens, [])
    }

    func test_refreshData_recoversSessionInvalidatingExpiredToken() async throws {
        let deviceAuth = DeviceAuthFake(sessionToken: "device-token", recoveredToken: "new-device-token")
        let service = makeService(deviceAuth: deviceAuth, walletAuth: WalletAuthTokenProviderStub(isWarm: true))

        let authorization = try await service.authorization(
            for: makeWallet(multichainWalletId: "backend-wallet-id"),
            expiredDeviceToken: "expired-token"
        )
        let sessionCallCount = await deviceAuth.sessionCallCount
        let recoveredTokens = await deviceAuth.recoveredTokens

        XCTAssertEqual(authorization.deviceToken, "new-device-token")
        XCTAssertEqual(authorization.walletToken, "signed(backend-wallet-id,new-device-token)")
        XCTAssertEqual(sessionCallCount, 0)
        XCTAssertEqual(recoveredTokens, ["expired-token"])
    }

    func test_deviceSessionFailure_isPropagated() async {
        let service = makeService(
            deviceAuth: DeviceAuthFake(error: .connectionError),
            walletAuth: WalletAuthTokenProviderStub(isWarm: true)
        )

        do {
            _ = try await service.authorization(
                for: makeWallet(multichainWalletId: "backend-wallet-id"),
                expiredDeviceToken: nil
            )
            XCTFail("Expected device session failure")
        } catch {
            XCTAssertEqual(error as? DeviceAuthError, .connectionError)
        }
    }

    func test_coldAppKey_throwsUnavailable() async {
        let service = makeService(
            deviceAuth: DeviceAuthFake(sessionToken: "device-token"),
            walletAuth: WalletAuthTokenProviderStub(isWarm: false)
        )

        await assertAuthorizationUnavailable(
            service: service,
            wallet: makeWallet(multichainWalletId: "backend-wallet-id")
        )
    }

    func test_legacyWallet_throwsUnavailable() async {
        let deviceAuth = DeviceAuthFake(sessionToken: "device-token")
        let service = makeService(deviceAuth: deviceAuth, walletAuth: WalletAuthTokenProviderStub(isWarm: true))

        await assertAuthorizationUnavailable(service: service, wallet: makeWallet())
    }
}

private extension BatteryWebAuthorizationServiceTests {
    func makeService(
        deviceAuth: DeviceAuthFake,
        walletAuth: WalletAuthTokenProviderStub
    ) -> BatteryWebAuthorizationServiceImplementation {
        BatteryWebAuthorizationServiceImplementation(
            deviceAuth: deviceAuth,
            walletAuthTokenProvider: walletAuth
        )
    }

    func assertAuthorizationUnavailable(
        service: BatteryWebAuthorizationServiceImplementation,
        wallet: Wallet,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await service.authorization(for: wallet, expiredDeviceToken: nil)
            XCTFail("Expected unavailable authorization", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? BatteryAuthorizationError, .unavailable, file: file, line: line)
        }
    }

    func makeWallet(multichainWalletId: String? = nil) -> Wallet {
        Wallet(
            id: "wallet-id",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
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
    let isWarm: Bool

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

private actor DeviceAuthFake: DeviceAuthProviding {
    private let sessionToken: String
    private let recoveredToken: String
    private let error: DeviceAuthError?
    private(set) var sessionCallCount = 0
    private(set) var recoveredTokens = [String]()

    init(sessionToken: String = "session-token", recoveredToken: String = "recovered-token", error: DeviceAuthError? = nil) {
        self.sessionToken = sessionToken
        self.recoveredToken = recoveredToken
        self.error = error
    }

    func session() async throws(DeviceAuthError) -> DeviceAuthSession {
        sessionCallCount += 1
        if let error {
            throw error
        }
        return DeviceAuthSession(deviceId: "device-id", accessToken: sessionToken)
    }

    func recoverSession(invalidating accessToken: String) async throws(DeviceAuthError) -> DeviceAuthSession {
        recoveredTokens.append(accessToken)
        if let error {
            throw error
        }
        return DeviceAuthSession(deviceId: "device-id", accessToken: recoveredToken)
    }

    func isDeviceKnown() -> Bool {
        true
    }
}
