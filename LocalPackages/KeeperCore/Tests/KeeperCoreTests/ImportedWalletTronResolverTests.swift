@testable import KeeperCore
import KeeperCoreSensitive
import TronSwift
import XCTest

final class ImportedWalletTronResolverTests: XCTestCase {
    func test_legacyBalance_returnsBalanceForBip39WithUsdtBalance() async throws {
        let balanceService = TronBalanceServiceMock(
            result: .success(TronBalance(amount: 1, trxAmount: 0))
        )
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.legacyBalance(mnemonic: bip39Mnemonic, network: .mainnet)
        let expectedLegacyTron = try XCTUnwrap(
            WalletTron(tonMnemonic: bip39Mnemonic.mnemonicWords)
        )

        XCTAssertEqual(result?.amount, 1)
        XCTAssertEqual(result?.trxAmount, 0)
        XCTAssertEqual(balanceService.requestedAddresses, [expectedLegacyTron.address.base58])
    }

    func test_legacyBalance_returnsBalanceForBip39WithTrxBalance() async {
        let balanceService = TronBalanceServiceMock(
            result: .success(TronBalance(amount: 0, trxAmount: 1))
        )
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.legacyBalance(mnemonic: bip39Mnemonic, network: .mainnet)

        XCTAssertEqual(result?.amount, 0)
        XCTAssertEqual(result?.trxAmount, 1)
    }

    func test_legacyBalance_returnsNilForBip39WithZeroBalance() async {
        let balanceService = TronBalanceServiceMock(
            result: .success(TronBalance(amount: 0, trxAmount: 0))
        )
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.legacyBalance(mnemonic: bip39Mnemonic, network: .mainnet)

        XCTAssertNil(result)
    }

    func test_legacyBalance_returnsNilWhenBalanceRequestFails() async {
        let balanceService = TronBalanceServiceMock(result: .failure(TestError.offline))
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.legacyBalance(mnemonic: bip39Mnemonic, network: .mainnet)

        XCTAssertNil(result)
    }

    func test_walletKindSelectionReason_returnsAmbiguousMnemonicWithLegacyTrxBalance() async {
        let balance = TronBalance(amount: 0, trxAmount: 1)
        let balanceService = TronBalanceServiceMock(result: .success(balance))
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.walletKindSelectionReason(
            words: ambiguousMnemonicWords,
            network: .mainnet
        )

        XCTAssertEqual(result, .ambiguousMnemonic(legacyTronBalance: balance))
        XCTAssertEqual(balanceService.requestedAddresses.count, 1)
    }

    func test_walletKindSelectionReason_returnsAmbiguousMnemonicWithoutLegacyBalance() async {
        let balanceService = TronBalanceServiceMock(
            result: .success(TronBalance(amount: 0, trxAmount: 0))
        )
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.walletKindSelectionReason(
            words: ambiguousMnemonicWords,
            network: .mainnet
        )

        XCTAssertEqual(result, .ambiguousMnemonic(legacyTronBalance: nil))
    }

    func test_walletKindSelectionReason_returnsLegacyTronBalanceForBip39WithTrxBalance() async {
        let balanceService = TronBalanceServiceMock(
            result: .success(TronBalance(amount: 0, trxAmount: 1))
        )
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.walletKindSelectionReason(
            words: bip39Mnemonic.mnemonicWords,
            network: .mainnet
        )

        XCTAssertEqual(
            result,
            .legacyTronBalance(TronBalance(amount: 0, trxAmount: 1))
        )
    }

    func test_walletKindSelectionReason_returnsNilForBip39WithoutBalance() async {
        let balanceService = TronBalanceServiceMock(
            result: .success(TronBalance(amount: 0, trxAmount: 0))
        )
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.walletKindSelectionReason(
            words: bip39Mnemonic.mnemonicWords,
            network: .mainnet
        )

        XCTAssertNil(result)
    }

    func test_resolve_returnsLegacyForAutomaticBip39WithBalance() async {
        let balanceService = TronBalanceServiceMock(
            result: .success(TronBalance(amount: 1, trxAmount: 0))
        )
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.resolve(
            mnemonic: bip39Mnemonic,
            network: .mainnet,
            walletKindPreference: .automatic
        )

        XCTAssertNotNil(result.tron)
        XCTAssertEqual(result.multichain, .unavailable)
        XCTAssertEqual(balanceService.requestedAddresses.count, 1)
    }

    func test_resolve_returnsMultichainForAutomaticBip39WithoutBalance() async {
        let balanceService = TronBalanceServiceMock(
            result: .success(TronBalance(amount: 0, trxAmount: 0))
        )
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.resolve(
            mnemonic: bip39Mnemonic,
            network: .mainnet,
            walletKindPreference: .automatic
        )

        XCTAssertNil(result.tron)
        XCTAssertNil(result.multichain)
        XCTAssertEqual(balanceService.requestedAddresses.count, 1)
    }

    func test_resolve_returnsMultichainForAutomaticBip39WhenBalanceRequestFails() async {
        let balanceService = TronBalanceServiceMock(result: .failure(TestError.offline))
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.resolve(
            mnemonic: bip39Mnemonic,
            network: .mainnet,
            walletKindPreference: .automatic
        )

        XCTAssertNil(result.tron)
        XCTAssertNil(result.multichain)
        XCTAssertEqual(balanceService.requestedAddresses.count, 1)
    }

    func test_resolve_returnsSelectedLegacyBip39WithoutBalanceRequest() async {
        let balanceService = TronBalanceServiceMock(result: .failure(TestError.unexpectedRequest))
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.resolve(
            mnemonic: bip39Mnemonic,
            network: .mainnet,
            walletKindPreference: .selected(.ton)
        )

        XCTAssertNotNil(result.tron)
        XCTAssertEqual(result.multichain, .unavailable)
        XCTAssertTrue(balanceService.requestedAddresses.isEmpty)
    }

    func test_resolve_returnsSelectedMultichainBip39WithoutBalanceRequest() async {
        let balanceService = TronBalanceServiceMock(
            result: .success(TronBalance(amount: 1, trxAmount: 1))
        )
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)

        let result = await resolver.resolve(
            mnemonic: bip39Mnemonic,
            network: .mainnet,
            walletKindPreference: .selected(.multichain)
        )

        XCTAssertNil(result.tron)
        XCTAssertNil(result.multichain)
        XCTAssertTrue(balanceService.requestedAddresses.isEmpty)
    }

    func test_resolve_returnsLegacyForTonMnemonicWithoutBalanceRequest() async {
        let balanceService = TronBalanceServiceMock(result: .failure(TestError.unexpectedRequest))
        let resolver = ImportedWalletTronResolver(tronBalanceService: balanceService)
        let mnemonic = CoreMnemonic(
            mnemonicWords: [
                "business", "thunder", "episode", "arena",
                "tray", "twelve", "humble", "asthma",
                "uphold", "pumpkin", "crunch", "fortune",
            ],
            type: .ton
        )

        let result = await resolver.resolve(
            mnemonic: mnemonic,
            network: .mainnet,
            walletKindPreference: .automatic
        )

        XCTAssertNotNil(result.tron)
        XCTAssertNil(result.multichain)
        XCTAssertTrue(balanceService.requestedAddresses.isEmpty)
    }
}

private extension ImportedWalletTronResolverTests {
    var bip39Mnemonic: CoreMnemonic {
        CoreMnemonic(
            mnemonicWords: Array(repeating: "abandon", count: 11) + ["about"],
            type: .bip39
        )
    }

    var ambiguousMnemonicWords: [String] {
        [
            "business", "thunder", "episode", "arena",
            "tray", "twelve", "humble", "asthma",
            "uphold", "pumpkin", "crunch", "fortune",
        ]
    }
}

private final class TronBalanceServiceMock: TronBalanceService {
    private let result: Result<TronBalance, Error>
    private(set) var requestedAddresses = [String]()

    init(result: Result<TronBalance, Error>) {
        self.result = result
    }

    func loadBalance(address: TronSwift.Address) async throws -> TronBalance {
        requestedAddresses.append(address.base58)
        return try result.get()
    }

    func loadAccountBalancesBatch(addresses: [TronSwift.Address]) async throws -> [String: TronBalance] {
        var balances = [String: TronBalance]()
        for address in addresses {
            requestedAddresses.append(address.base58)
            balances[address.base58] = try result.get()
        }
        return balances
    }

    func loadAccountBalances(address: TronSwift.Address) async throws -> TronBalance {
        requestedAddresses.append(address.base58)
        return try result.get()
    }
}

private enum TestError: Error {
    case offline
    case unexpectedRequest
}
