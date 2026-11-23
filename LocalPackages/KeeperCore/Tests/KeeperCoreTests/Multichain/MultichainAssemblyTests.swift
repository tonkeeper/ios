import Foundation
import HTTPTypes
@testable import KeeperCore
import KeeperCoreComponents
import KeeperCoreSensitive
import MultichainAPI
import OpenAPIRuntime
import SwapAPI
import XCTest

/// The gates multichain sends and relayed swaps clear, as the assembly builds them: chain-kit validates
/// what they read unless the boot configuration's `tx_validation_enabled` turns it off, read at every
/// review.
final class MultichainAssemblyTests: XCTestCase {
    /// The assembly's lazy graph is resolved on main.
    @MainActor
    func test_theSendGateValidatesUntilTheBootConfigurationTurnsValidationOff() async throws {
        let configuration = KeeperCore.Configuration.review(thenValidates: false)
        let assembly = try makeAssembly(configuration: configuration)

        XCTAssertTrue(assembly.sendGate.checks().contains { $0 is ChainKitValidationCheck })
        _ = await configuration.loadConfigurations()
        XCTAssertFalse(assembly.sendGate.checks().contains { $0 is ChainKitValidationCheck })
    }

    @MainActor
    func test_theSwapGateValidatesUntilTheBootConfigurationTurnsValidationOff() async throws {
        let configuration = KeeperCore.Configuration.review(thenValidates: false)
        let assembly = try makeAssembly(configuration: configuration)

        XCTAssertTrue(assembly.swapGate.checks().contains { $0 is ChainKitValidationCheck })
        _ = await configuration.loadConfigurations()
        XCTAssertFalse(assembly.swapGate.checks().contains { $0 is ChainKitValidationCheck })
    }
}

private extension MultichainAssemblyTests {
    /// Nothing it is built with is reached while its gate is read.
    func makeAssembly(configuration: KeeperCore.Configuration) throws -> MultichainAssembly {
        let vault = InMemoryKeychainVault()
        let keeperInfoStore = KeeperInfoStore(keeperInfoRepository: EmptyKeeperInfoRepositoryStub())
        let multichain = try MultichainAPI.Client(serverURL: XCTUnwrap(URL(string: "https://multichain.test")), transport: NoTransport())
        let swap = try SwapAPI.Client(serverURL: XCTUnwrap(URL(string: "https://swap.test")), transport: NoTransport())
        let clientAPI = MultichainClientAPIImplementation(
            multichainAPIClient: { multichain },
            deviceScopedAPIClient: { multichain },
            walletScopedAPIClient: { _ in multichain }
        )
        return MultichainAssembly(
            appInfoProvider: AppInfoStub(),
            mnemonicAccess: .inMemory(seed: "multichain-assembly", keychainVault: vault),
            walletsStore: WalletsStore(keeperInfoStore: keeperInfoStore),
            multichainService: MultichainServiceFake(),
            multichainClientAPI: clientAPI,
            multichainAuthClientAPI: MultichainAuthClientAPIImplementation(
                multichainAPIClient: { multichain },
                deviceAuthMultichainAPIClient: { _ in multichain }
            ),
            multichainSwapService: MultichainSwapServiceImplementation(
                multichainSwapAPI: MultichainSwapAPIImplementation(swapAPIClient: swap, firebaseUserIdProvider: { nil })
            ),
            pendingTransactionsService: PendingTransactionsServiceFake(),
            visibilityChangesController: VisibilityChangesController(
                vault: FileSystemVault(fileManager: .default, directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)),
                writer: MultichainAssetVisibilityChangesClientWriter(multichainClientAPI: clientAPI)
            ),
            currencyStore: CurrencyStore(keeperInfoStore: keeperInfoStore),
            configuration: configuration,
            keychainVault: vault,
            deviceAuthService: NoDeviceAuth(),
            legacyBatteryMigrationController: LegacyBatteryMigrationController(dependencies: .init(
                load: { .init() },
                save: { _ in },
                wallets: { [] },
                balance: { _ in .empty },
                waitUntilIdle: { _ in false },
                migrate: { _, _ in XCTFail("Reading a gate must not migrate the battery") },
                refreshBalance: { _ in }
            )),
            walletAuthTokenProvider: WalletAuthTokenProvider(chainKitService: { nil }, store: WalletAuthKeychainStore(keychainVault: vault))
        )
    }
}

private struct NoTransport: ClientTransport {
    func send(_: HTTPRequest, body _: HTTPBody?, baseURL _: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        XCTFail("the assembly requested \(operationID)")
        return (HTTPResponse(status: .internalServerError), nil)
    }
}

private struct NoDeviceAuth: DeviceAuthProviding {
    func session() async throws(DeviceAuthError) -> DeviceAuthSession {
        throw .failed(message: "no device session in a test")
    }

    func recoverSession(invalidating _: String) async throws(DeviceAuthError) -> DeviceAuthSession {
        throw .failed(message: "no device session in a test")
    }

    func isDeviceKnown() async -> Bool {
        false
    }
}

private struct AppInfoStub: AppInfoProvider {
    let version = "1.0"
    let userAgent = "Keeper/1.0"
    let platform = "ios"
    let language = "en"
    let storeCountryCode: String? = nil
    let deviceCountryCode: String? = nil
    let isVPNActive = false
    let timeZoneIdentifier = "UTC"
}
