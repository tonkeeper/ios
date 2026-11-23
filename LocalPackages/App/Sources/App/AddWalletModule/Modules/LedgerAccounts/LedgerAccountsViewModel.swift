import AppUI
import BigInt
import Foundation
import KeeperCore
import LedgerKit
import TKLocalize
import TonSwift
import TonTransport

/// The accounts of a Ledger at multichain pairing: what its selected apps handed out for each, the TON balance, and
/// which ones the user picks. Further accounts are read on demand, a page or one chosen number at a time, in the apps
/// that answered then.
@MainActor
final class LedgerAccountsViewModel {
    static let pageSize = 3
    /// The last account index Keeper reads, as on Android.
    static let maxAccountIndex = 100

    struct Dependencies {
        /// Reads the accounts at the indices in the selected chain apps on the Ledger and the TON app. With
        /// `choosesApps`, the user confirms or skips each chain app first.
        let read: @MainActor (_ indices: [Int], _ apps: [LedgerApp], _ choosesApps: Bool) async throws -> LedgerDiscovery
        let loadBalances: @MainActor ([LedgerAccount]) async -> [ActiveWalletModel]
        /// The account already is a wallet of this Ledger.
        let isAdded: (LedgerAccount) -> Bool
        /// The account number the user typed, from 1; `nil` when they cancelled.
        let askAccountNumber: @MainActor () async -> Int?
        let amountFormatter: AmountFormatter
    }

    fileprivate struct Account {
        let ton: LedgerAccount
        let keys: LedgerAppKeys
        let balance: ActiveWalletModel?
        let isAdded: Bool
    }

    var didUpdateState: ((LedgerAccountsScreenState) -> Void)?
    var didShowAccounts: (() -> Void)?
    var didChoose: (([LedgerAccount]) -> Void)?
    /// The first accounts were not read: the user cancelled or the Ledger failed.
    var didCancel: (() -> Void)?

    var state: LedgerAccountsScreenState {
        LedgerAccountsScreenState(
            accounts: accounts.keys.sorted().compactMap { index in
                accounts[index].map { row(index: index, account: $0) }
            },
            isReading: isReading,
            canShowMore: !unreadIndices.isEmpty,
            isContinueEnabled: !selected.isEmpty
        )
    }

    let selectedChains: [MultichainChain]

    private var accounts: [Int: Account] = [:]
    private var selected = Set<Int>()
    private var apps: [LedgerApp]
    /// Set from the start: the first page is read once the screen appears.
    private var isReading = true
    private var hasStarted = false

    private let dependencies: Dependencies

    init(chains: [MultichainChain], dependencies: Dependencies) {
        let chains = MultichainChain.orderedByDisplayOrder(chains)
        selectedChains = chains
        apps = LedgerDiscovery.chainApps(for: chains)
        self.dependencies = dependencies
    }

    /// Reads the first page once the screen is on, so that the Ledger's steps sheet opens over it.
    func appear() {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        Task {
            do {
                try await start()
            } catch {
                didCancel?()
            }
        }
    }

    /// Reads the first page, selecting the funded accounts or else the first one not added yet. Throws when the user
    /// cancels or the Ledger fails.
    func start() async throws {
        try await readAccounts(Array(0 ..< Self.pageSize))
        if selected.isEmpty, let first = accounts.keys.sorted().first(where: { accounts[$0]?.isAdded == false }) {
            selected.insert(first)
            update()
        }
    }

    func toggle(_ index: Int) {
        guard accounts[index]?.isAdded == false else {
            return
        }
        if selected.contains(index) {
            selected.remove(index)
        } else {
            selected.insert(index)
        }
        update()
    }

    func showMore() {
        let indices = Array(unreadIndices.prefix(Self.pageSize))
        guard !isReading, !indices.isEmpty else {
            return
        }
        Task {
            try? await readAccounts(indices)
        }
    }

    func addAccountByNumber() {
        guard !isReading else {
            return
        }
        Task {
            guard let number = await dependencies.askAccountNumber(), (1 ... Self.maxAccountIndex + 1).contains(number) else {
                return
            }
            let index = number - 1
            if accounts[index] == nil {
                guard (try? await readAccounts([index])) != nil else {
                    return
                }
            }
            if accounts[index]?.isAdded == false {
                selected.insert(index)
                update()
            }
        }
    }

    func choose() {
        let chosen = selected.sorted().compactMap { accounts[$0]?.ton }
        guard !chosen.isEmpty else {
            return
        }
        didChoose?(chosen)
    }

    /// The chosen accounts as multichain accounts, with the wallet key proofs the TON app signed for them, in order.
    func multichainAccounts(_ chosen: [LedgerAccount], proofs: [Data]) -> [AccountPath: LedgerMultichainAccount] {
        Dictionary(uniqueKeysWithValues: zip(chosen, proofs).compactMap { account, proof in
            accounts[account.path.index].map { (account.path, LedgerMultichainAccount(proofSignature: proof, keys: $0.keys)) }
        })
    }
}

private extension LedgerAccountsViewModel {
    /// The accounts not read yet, in order: Show more takes the first of them, so one added by its number leaves no gap.
    var unreadIndices: [Int] {
        (0 ... Self.maxAccountIndex).filter { accounts[$0] == nil }
    }

    /// The funded accounts it reads get selected.
    func readAccounts(_ indices: [Int]) async throws {
        isReading = true
        update()
        var didRead = false
        defer {
            isReading = false
            update()
            if didRead, !accounts.isEmpty { didShowAccounts?() }
        }
        let discovery = try await dependencies.read(indices, apps, accounts.isEmpty)
        apps = discovery.apps
        let read = discovery.tonKeys.keys.sorted().compactMap { index in
            discovery.tonKeys[index].map { LedgerAccount(publicKey: TonSwift.PublicKey(data: $0), revision: .v4R2, path: AccountPath(index: index)) }
        }
        let balances = await dependencies.loadBalances(read)
        for ton in read {
            let index = ton.path.index
            let balance = balances.first { $0.id == ton.id }
            let isAdded = dependencies.isAdded(ton)
            accounts[index] = Account(ton: ton, keys: discovery.keys[index] ?? LedgerAppKeys(), balance: balance, isAdded: isAdded)
            if !isAdded, let balance, !balance.balance.isEmpty {
                selected.insert(index)
            }
        }
        didRead = true
    }

    func update() {
        didUpdateState?(state)
    }

    func row(index: Int, account: Account) -> LedgerAccountsScreenState.Account {
        LedgerAccountsScreenState.Account(
            id: index,
            title: TKLocales.LedgerDevice.account(index + 1),
            addresses: addresses(of: account),
            isAdded: account.isAdded,
            isSelected: selected.contains(index)
        )
    }

    func addresses(of account: Account) -> [LedgerAccountsScreenState.Account.Address] {
        let ton = (try? WalletV4R2(publicKey: account.ton.publicKey.data).address()).map { address in
            LedgerAccountsScreenState.Account.Address(
                network: MultichainChain.ton.shortDisplayTitle,
                value: ([address.toShortString(bounceable: false)] + [account.balance.map(balanceText)].compactMap { $0 }).joined(separator: " · ")
            )
        }
        let others = ((try? account.keys.addresses(chains: selectedChains)) ?? []).map { address in
            LedgerAccountsScreenState.Account.Address(
                network: address.chain.shortDisplayTitle,
                value: MultichainAddressFormatter.shortAddress(address.address, chain: address.chain)
            )
        }
        return [ton].compactMap { $0 } + others
    }

    func balanceText(_ model: ActiveWalletModel) -> String {
        let amount = dependencies.amountFormatter.format(
            amount: BigUInt(integerLiteral: UInt64(model.balance.tonBalance.amount)),
            fractionDigits: TonInfo.fractionDigits,
            accessory: .token(Currency.GRAM)
        )
        guard !model.balance.isEmptyJettonsBalance || !model.nfts.isEmpty else {
            return amount
        }
        return amount + ", " + TKLocales.ChooseWallets.tokens
    }
}
