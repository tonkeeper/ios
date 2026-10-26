@testable import App
@testable import KeeperCore
import TonSwift
import XCTest

@MainActor
final class SettingsListCurrencyPickerConfiguratorTests: XCTestCase {
    func test_restrictedSelectionIsHiddenBeforeAndAfterLoadingInGB() async throws {
        for code in ["RUB", "BYN"] {
            let configurator = try makeConfigurator(selectedCode: code, isRestrictedRegion: true)
            let loaded = expectation(description: "Currencies loaded for \(code)")
            configurator.didUpdateState = { state in
                XCTAssertEqual(self.rowCodes(state), ["USD"])
                loaded.fulfill()
            }

            XCTAssertEqual(rowCodes(configurator.getInitialState()), [])
            await fulfillment(of: [loaded], timeout: 2)
        }
    }

    func test_allowedSelectionMissingFromAPIIsKept() async throws {
        for (code, restricted) in [("RUB", false), ("BYN", false), ("NOK", true)] {
            let configurator = try makeConfigurator(selectedCode: code, isRestrictedRegion: restricted)
            let loaded = expectation(description: "Currencies loaded for \(code)")
            configurator.didUpdateState = { state in
                XCTAssertEqual(self.rowCodes(state), [code, "USD"])
                loaded.fulfill()
            }

            XCTAssertEqual(rowCodes(configurator.getInitialState()), [code])
            await fulfillment(of: [loaded], timeout: 2)
        }
    }

    private func makeConfigurator(
        selectedCode: String,
        isRestrictedRegion: Bool
    ) throws -> SettingsListCurrencyPickerConfigurator {
        let wallet = Wallet(
            id: "wallet",
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
        let repository = try KeeperInfoRepositoryStub(keeperInfo: KeeperInfo(
            wallets: [wallet],
            currentWallet: wallet,
            currency: XCTUnwrap(Currency(code: selectedCode)),
            securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
            appSettings: KeeperInfo.AppSettings(isSecureMode: false, searchEngine: .duckduckgo),
            country: .auto
        ))
        return SettingsListCurrencyPickerConfigurator(
            currencyStore: CurrencyStore(keeperInfoStore: KeeperInfoStore(keeperInfoRepository: repository)),
            currenciesService: CurrenciesServiceStub(),
            isRestrictedRegion: { isRestrictedRegion }
        )
    }

    private func rowCodes(_ state: SettingsListState) -> [String] {
        state.sections.flatMap { section -> [String] in
            guard case let .items(items) = section else { return [] }
            return items.items.compactMap { item in
                guard case let .listItem(row) = item else { return nil }
                return row.id
            }
        }
    }
}

private struct CurrenciesServiceStub: CurrenciesService {
    func loadCurrencies() async throws -> [RemoteCurrency] {
        [.default]
    }

    func clearCachedCurrencies() {}
}

private final class KeeperInfoRepositoryStub: KeeperInfoRepository {
    private let keeperInfo: KeeperInfo

    init(keeperInfo: KeeperInfo) {
        self.keeperInfo = keeperInfo
    }

    func getKeeperInfo() throws -> KeeperInfo {
        keeperInfo
    }

    func saveKeeperInfo(_ keeperInfo: KeeperInfo) throws {}
    func removeKeeperInfo() throws {}
}
