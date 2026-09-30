import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class TotalBalanceLoaderTargetsTests: XCTestCase {
    private let wallet = TotalBalanceLoaderTargetsTests.makeWallet(id: "wallet", addressType: .tonV5R1)
    private let siblingWallet = TotalBalanceLoaderTargetsTests.makeWallet(
        id: "sibling-wallet",
        addressType: .tonV4R2
    )
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func test_walletsSharingMultichainWalletIdAreBothRequested() {
        let targets = portfolioTargets(
            wallets: [wallet, siblingWallet],
            portfolioTotals: [:],
            currencyCode: "usd",
            now: now
        )

        XCTAssertEqual(targets.map(\.wallet.id), [wallet.id, siblingWallet.id])
    }

    func test_freshTotalOfOneWalletDoesNotSuppressItsSibling() {
        let targets = portfolioTargets(
            wallets: [wallet, siblingWallet],
            portfolioTotals: [wallet: Self.makePortfolio(date: now)],
            currencyCode: "usd",
            now: now
        )

        XCTAssertEqual(targets.map(\.wallet.id), [siblingWallet.id])
    }

    func test_staleTotalIsRequestedAgain() {
        let targets = portfolioTargets(
            wallets: [wallet],
            portfolioTotals: [
                wallet: Self.makePortfolio(date: now.addingTimeInterval(-61)),
            ],
            currencyCode: "usd",
            now: now
        )

        XCTAssertEqual(targets.map(\.wallet.id), [wallet.id])
    }

    func test_freshTotalMissingDisplayCurrencyIsRequestedAgain() {
        let targets = portfolioTargets(
            wallets: [wallet],
            portfolioTotals: [wallet: Self.makePortfolio(date: now)],
            currencyCode: "eur",
            now: now
        )

        XCTAssertEqual(targets.map(\.wallet.id), [wallet.id])
    }

    func test_freshTotalWithDifferentDustFilterIsRequestedAgain() {
        let targets = portfolioTargets(
            wallets: [wallet],
            portfolioTotals: [wallet: Self.makePortfolio(date: now)],
            currencyCode: "usd",
            hidesDustBalances: true,
            now: now
        )

        XCTAssertEqual(targets.map(\.wallet.id), [wallet.id])
    }

    func test_aWalletWithoutMultichainStateAsksForItsOwnBalance() {
        let legacyWallet = Self.makeWallet(id: "legacy", addressType: nil)

        let targets = targets(wallets: [legacyWallet], currencyCode: "usd", now: now)

        XCTAssertEqual(targets, [.walletBalance(wallet: legacyWallet)])
    }

    /// The list renders the portfolio total, and the screens behind it read what the fan-out
    /// writes, so a multichain wallet earns both.
    func test_aMultichainWalletAsksForItsTotalAndForItsBalance() {
        guard let state = wallet.multichainWalletState else {
            return XCTFail("the fixture is expected to carry multichain state")
        }

        let targets = targets(wallets: [wallet], currencyCode: "usd", now: now)

        XCTAssertEqual(
            targets,
            [.portfolioTotal(wallet: wallet, state: state), .walletBalance(wallet: wallet)]
        )
    }

    /// The two halves are held to their own windows: a total answered for a moment ago does not
    /// excuse a balance nobody has asked for in a while.
    func test_aFreshTotalDoesNotSuppressTheBalanceBesideIt() {
        let targets = targets(
            wallets: [wallet],
            portfolioTotals: [wallet: Self.makePortfolio(date: now)],
            currencyCode: "usd",
            now: now
        )

        XCTAssertEqual(targets, [.walletBalance(wallet: wallet)])
    }

    func test_aLegacyWalletAnsweredForInsideTheWindowIsLeftAlone() {
        let legacyWallet = Self.makeWallet(id: "legacy", addressType: nil)

        let targets = targets(
            wallets: [legacyWallet],
            balanceStates: [legacyWallet: .current(Self.balance(date: now.addingTimeInterval(-30)))],
            currencyCode: "usd",
            now: now
        )

        XCTAssertTrue(targets.isEmpty)
    }

    func test_aLegacyWalletAnsweredForTooLongAgoIsAskedAgain() {
        let legacyWallet = Self.makeWallet(id: "legacy", addressType: nil)

        let targets = targets(
            wallets: [legacyWallet],
            balanceStates: [legacyWallet: .current(Self.balance(date: now.addingTimeInterval(-61)))],
            currencyCode: "usd",
            now: now
        )

        XCTAssertEqual(targets, [.walletBalance(wallet: legacyWallet)])
    }

    private func portfolioTargets(
        wallets: [Wallet],
        balanceStates: [Wallet: WalletBalanceState] = [:],
        portfolioTotals: [Wallet: MultichainPortfolio] = [:],
        currencyCode: String,
        hidesDustBalances: Bool = false,
        now: Date
    ) -> [TotalBalanceLoaderTarget] {
        targets(
            wallets: wallets,
            balanceStates: balanceStates,
            portfolioTotals: portfolioTotals,
            currencyCode: currencyCode,
            hidesDustBalances: hidesDustBalances,
            now: now
        )
        .filter { if case .portfolioTotal = $0 { true } else { false } }
    }

    private func targets(
        wallets: [Wallet],
        balanceStates: [Wallet: WalletBalanceState] = [:],
        portfolioTotals: [Wallet: MultichainPortfolio] = [:],
        currencyCode: String,
        hidesDustBalances: Bool = false,
        now: Date
    ) -> [TotalBalanceLoaderTarget] {
        TotalBalanceLoaderTarget.from(
            wallets: wallets,
            balanceStates: balanceStates,
            portfolioTotals: portfolioTotals,
            currencyCode: currencyCode,
            hidesDustBalances: hidesDustBalances,
            now: now
        )
    }

    private static func makePortfolio(date: Date) -> MultichainPortfolio {
        MultichainPortfolio(
            fiatPrice: ["usd": "20"],
            assets: [],
            accountsIdentifier: "accounts",
            currencyCode: "usd",
            hidesDustBalances: false,
            date: date
        )
    }

    private static func balance(date: Date) -> WalletBalance {
        WalletBalance(
            date: date,
            balance: Balance(tonBalance: TonBalance(amount: 0), jettonsBalance: []),
            stacking: [],
            batteryBalance: nil,
            tronBalance: nil
        )
    }

    private static func makeWallet(
        id: String,
        addressType: MultichainWalletAddressType?
    ) -> Wallet {
        let publicKeyData = Data((id + "-public-key").utf8) + Data(repeating: 0, count: 32)
        let publicKey = TonSwift.PublicKey(data: Data(publicKeyData.prefix(32)))
        let multichain: MultichainWallet? = addressType.map { addressType in
            .multichain(
                MultichainWalletState(
                    walletId: "shared-multichain-wallet-id",
                    addresses: [
                        MultichainWalletAddress(
                            chain: .ton,
                            address: "\(id)-ton-address",
                            type: addressType
                        ),
                    ]
                )
            )
        }
        return Wallet(
            id: id,
            identity: WalletIdentity(
                network: .mainnet,
                kind: .Regular(publicKey, addressType == .tonV5R1 ? .v5R1 : .v4R2)
            ),
            metaData: WalletMetaData(label: id, tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: multichain
        )
    }
}
