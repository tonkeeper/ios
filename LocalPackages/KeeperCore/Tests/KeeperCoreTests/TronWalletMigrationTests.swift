@testable import KeeperCore
import KeeperCoreSensitive
import TonSwift
import TronSwift
import XCTest

final class TronWalletMigrationTests: XCTestCase {
    func test_migrate_derivesLegacyAddressOnlyForTonMnemonicAndCompletesOnce() async throws {
        let tonWallet = makeWallet(id: "ton-wallet")
        let bip39Wallet = makeWallet(id: "bip39-wallet")
        let tonWords = [
            "business", "thunder", "episode", "arena",
            "tray", "twelve", "humble", "asthma",
            "uphold", "pumpkin", "crunch", "fortune",
        ]
        let bip39Words = Array(repeating: "abandon", count: 11) + ["about"]
        let spy = TronWalletMigrationSpy(
            wallets: [tonWallet, bip39Wallet],
            mnemonics: [
                tonWallet.id: CoreMnemonic(mnemonicWords: tonWords, type: .ton),
                bip39Wallet.id: CoreMnemonic(mnemonicWords: bip39Words, type: .bip39),
            ]
        )
        let migration = makeMigration(spy: spy)

        XCTAssertTrue(migration.needsMigration)
        let firstResult = await migration.migrate(passcode: "1234")
        let secondResult = await migration.migrate(passcode: "1234")

        XCTAssertTrue(firstResult)
        XCTAssertTrue(secondResult)
        XCTAssertTrue(spy.isCompleted)
        XCTAssertEqual(spy.completionCount, 1)
        XCTAssertEqual(spy.requestedWalletIds, [[tonWallet.id, bip39Wallet.id]])
        XCTAssertEqual(spy.savedWalletIds, [tonWallet.id])
        XCTAssertFalse(migration.needsMigration)

        let keyPair = try TonTron.derivedKeyPair(tonMnemonic: tonWords, index: 0)
        let expectedAddress = try TronSwift.Address(publicKey: keyPair.publicKey)
        XCTAssertEqual(spy.savedTronWallets.first?.address.base58, expectedAddress.base58)
    }

    func test_migrate_skipsMissingMnemonicAndCompletesOtherMigrations() async {
        let missingMnemonicWallet = makeWallet(id: "missing-mnemonic-wallet")
        let validWallet = makeWallet(id: "valid-wallet")
        let validWords = [
            "business", "thunder", "episode", "arena",
            "tray", "twelve", "humble", "asthma",
            "uphold", "pumpkin", "crunch", "fortune",
        ]
        let spy = TronWalletMigrationSpy(
            wallets: [missingMnemonicWallet, validWallet],
            mnemonics: [
                validWallet.id: CoreMnemonic(mnemonicWords: validWords, type: .ton),
            ]
        )
        let migration = makeMigration(spy: spy)

        let result = await migration.migrate(passcode: "1234")

        XCTAssertTrue(result)
        XCTAssertTrue(spy.isCompleted)
        XCTAssertEqual(spy.completionCount, 1)
        XCTAssertEqual(spy.savedWalletIds, [validWallet.id])
        XCTAssertFalse(migration.needsMigration)
    }

    func test_migrate_doesNotCompleteWhenMnemonicLoadingFails() async {
        let wallet = makeWallet(id: "failed-mnemonic-wallet")
        let spy = TronWalletMigrationSpy(wallets: [wallet], error: TestError.mnemonicLoadingFailed)
        let migration = makeMigration(spy: spy)

        let result = await migration.migrate(passcode: "1234")

        XCTAssertFalse(result)
        XCTAssertFalse(spy.isCompleted)
        XCTAssertEqual(spy.completionCount, 0)
        XCTAssertTrue(spy.savedWalletIds.isEmpty)
    }

    func test_walletTron_decodesLegacyIsOnFieldWithoutChangingAddress() throws {
        let words = [
            "business", "thunder", "episode", "arena",
            "tray", "twelve", "humble", "asthma",
            "uphold", "pumpkin", "crunch", "fortune",
        ]
        let tron = try XCTUnwrap(WalletTron(tonMnemonic: words))
        let encoded = try JSONEncoder().encode(tron)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object["isOn"] = false
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(WalletTron.self, from: legacyData)

        XCTAssertEqual(decoded.address.base58, tron.address.base58)
    }
}

private extension TronWalletMigrationTests {
    func makeMigration(spy: TronWalletMigrationSpy) -> TronWalletMigrationImplementation {
        TronWalletMigrationImplementation(
            dependencies: TronWalletMigrationDependencies(
                isMigrationCompleted: { spy.isCompleted },
                completeMigration: spy.completeMigration,
                getWallets: { spy.wallets },
                getMnemonics: spy.getMnemonics,
                saveWalletTron: spy.saveWalletTron
            )
        )
    }

    func makeWallet(id: String) -> Wallet {
        let publicKeyData = Data((id + "-public-key").utf8) + Data(repeating: 0, count: 32)
        let publicKey = TonSwift.PublicKey(data: Data(publicKeyData.prefix(32)))
        return Wallet(
            id: id,
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings()
        )
    }
}

private final class TronWalletMigrationSpy {
    var isCompleted = false
    let wallets: [Wallet]
    private let mnemonics: [CoreMnemonicIdentifier: CoreMnemonic]
    private let error: Error?
    private(set) var completionCount = 0
    private(set) var requestedWalletIds = [[String]]()
    private(set) var savedWalletIds = [String]()
    private(set) var savedTronWallets = [WalletTron]()

    init(
        wallets: [Wallet],
        mnemonics: [CoreMnemonicIdentifier: CoreMnemonic] = [:],
        error: Error? = nil
    ) {
        self.wallets = wallets
        self.mnemonics = mnemonics
        self.error = error
    }

    func completeMigration() {
        completionCount += 1
        isCompleted = true
    }

    func getMnemonics(
        wallets: [Wallet],
        passcode _: String
    ) async throws -> [CoreMnemonicIdentifier: CoreMnemonic] {
        requestedWalletIds.append(wallets.map(\.id))
        if let error {
            throw error
        }
        return mnemonics
    }

    func saveWalletTron(wallet: Wallet, tron: WalletTron) async {
        savedWalletIds.append(wallet.id)
        savedTronWallets.append(tron)
    }
}

private enum TestError: Error {
    case mnemonicLoadingFailed
}
