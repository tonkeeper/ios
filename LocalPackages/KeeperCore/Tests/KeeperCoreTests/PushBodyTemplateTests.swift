import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import XCTest

final class PushBodyTemplateTests: XCTestCase {
    private let template = "Swap completed on {wallet_name}: +32.2 Utya"
    private let main = PushBodyTemplateTests.makeWallet(label: "Main", key: 0x01, walletId: "mc-wallet")
    private let savings = PushBodyTemplateTests.makeWallet(label: "Savings", key: 0x02)

    func test_wallet_found_by_id_replaces_placeholder() throws {
        let body = try makeTemplate(walletId: "mc-wallet", address: savings.address.toRaw())?
            .body(wallets: [main, savings])

        XCTAssertEqual(body, "Swap completed on Main: +32.2 Utya")
    }

    func test_unknown_wallet_id_falls_back_to_address() throws {
        let body = try makeTemplate(walletId: "other", address: savings.address.toRaw())?
            .body(wallets: [main, savings])

        XCTAssertEqual(body, "Swap completed on Savings: +32.2 Utya")
    }

    func test_missing_wallet_id_falls_back_to_address() throws {
        let body = try makeTemplate(address: savings.address.toRaw())?.body(wallets: [main, savings])

        XCTAssertEqual(body, "Swap completed on Savings: +32.2 Utya")
    }

    func test_single_wallet_keeps_server_body() throws {
        let body = try makeTemplate(walletId: "mc-wallet", address: main.address.toRaw())?.body(wallets: [main])

        XCTAssertNil(body)
    }

    func test_unknown_wallet_keeps_server_body() throws {
        let other = Self.makeWallet(label: "Other", key: 0x03)

        let body = try makeTemplate(walletId: "other", address: other.address.toRaw())?
            .body(wallets: [main, savings])

        XCTAssertNil(body)
    }

    func test_testnet_wallet_with_the_same_address_is_skipped() throws {
        let mainnet = Self.makeWallet(label: "Mainnet", key: 0x04)
        let testnet = Self.makeWallet(label: "Testnet", key: 0x04, network: .testnet)
        XCTAssertEqual(try testnet.address, try mainnet.address)

        let body = try makeTemplate(address: mainnet.address.toRaw())?.body(wallets: [testnet, mainnet])

        XCTAssertEqual(body, "Swap completed on Mainnet: +32.2 Utya")
    }

    func test_blank_wallet_name_keeps_server_body() {
        let blank = Self.makeWallet(label: " ", key: 0x01, walletId: "mc-wallet")

        XCTAssertNil(makeTemplate(walletId: "mc-wallet")?.body(wallets: [blank, savings]))
    }

    func test_blank_or_missing_template_keeps_server_body() {
        XCTAssertNil(PushBodyTemplate(userInfo: ["body_template": " ", "wallet_id": "mc-wallet"]))
        XCTAssertNil(PushBodyTemplate(userInfo: ["wallet_id": "mc-wallet"]))
    }

    func test_body_reads_wallets_from_shared_container() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let template = try XCTUnwrap(makeTemplate(walletId: "mc-wallet"))
        XCTAssertNil(template.body(sharedCacheURL: directory))

        try FileSystemVault<KeeperInfo, String>(fileManager: .default, directory: directory)
            .saveKeeperInfo(Self.makeKeeperInfo(wallets: [savings, main]))

        XCTAssertEqual(template.body(sharedCacheURL: directory), "Swap completed on Main: +32.2 Utya")
    }
}

private extension PushBodyTemplateTests {
    func makeTemplate(walletId: String? = nil, address: String? = nil) -> PushBodyTemplate? {
        var userInfo: [AnyHashable: Any] = ["body_template": template]
        userInfo["wallet_id"] = walletId
        userInfo["address"] = address
        return PushBodyTemplate(userInfo: userInfo)
    }

    static func makeWallet(
        label: String,
        key: UInt8,
        network: Network = .mainnet,
        walletId: String? = nil
    ) -> Wallet {
        Wallet(
            id: UUID().uuidString,
            identity: WalletIdentity(
                network: network,
                kind: .Regular(TonSwift.PublicKey(data: Data(repeating: key, count: 32)), .v4R2)
            ),
            metaData: WalletMetaData(label: label, tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: walletId.map {
                .multichain(
                    MultichainWalletState(
                        walletId: $0,
                        addresses: [MultichainWalletAddress(chain: .tron, address: "TWS1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")]
                    )
                )
            }
        )
    }

    static func makeKeeperInfo(wallets: [Wallet]) -> KeeperInfo {
        KeeperInfo(
            wallets: wallets,
            currentWallet: wallets[0],
            currency: .defaultCurrency,
            securitySettings: SecuritySettings(isBiometryEnabled: false, isLockScreen: false),
            appSettings: KeeperInfo.AppSettings(isSecureMode: false, searchEngine: .duckduckgo),
            country: .auto
        )
    }
}
