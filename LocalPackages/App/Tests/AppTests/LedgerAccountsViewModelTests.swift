@testable import App
@testable import KeeperCore
import LedgerKit
import TonSwift
import TonTransport
import XCTest

@MainActor
final class LedgerAccountsViewModelTests: XCTestCase {
    func testTheFirstPageIsReadInEveryAppAndSelectsTheFundedAccounts() async throws {
        let ledger = FakeLedger(funded: [2])
        let viewModel = ledger.viewModel()
        var didShowAccounts = false
        viewModel.didShowAccounts = {
            XCTAssertFalse(viewModel.state.isReading)
            XCTAssertEqual(viewModel.state.accounts.count, 3)
            didShowAccounts = true
        }

        try await viewModel.start()

        XCTAssertTrue(didShowAccounts)
        XCTAssertEqual(ledger.reads, [FakeLedger.Read(indices: [0, 1, 2], apps: LedgerDiscovery.chainApps, choosesApps: true)])
        XCTAssertEqual(viewModel.state.accounts.map(\.id), [0, 1, 2])
        XCTAssertEqual(viewModel.state.accounts.filter(\.isSelected).map(\.id), [2])
    }

    func testWithoutFundsTheFirstAccountNotAddedIsSelected() async throws {
        let ledger = FakeLedger(added: [0])
        let viewModel = ledger.viewModel()

        try await viewModel.start()

        XCTAssertEqual(viewModel.state.accounts.filter(\.isAdded).map(\.id), [0])
        XCTAssertEqual(viewModel.state.accounts.filter(\.isSelected).map(\.id), [1])
    }

    func testMoreAccountsAreReadInTheAppsThatAnsweredWithoutAskingAgain() async throws {
        let ledger = FakeLedger(answering: [.ethereum, .tron])
        let viewModel = ledger.viewModel()
        try await viewModel.start()
        let read = expectation(description: "next page read")
        read.assertForOverFulfill = false
        viewModel.didUpdateState = { state in
            if state.accounts.count == 6 {
                read.fulfill()
            }
        }

        viewModel.showMore()
        await fulfillment(of: [read], timeout: 1)

        XCTAssertEqual(ledger.reads.last, FakeLedger.Read(indices: [3, 4, 5], apps: [.ethereum, .tron], choosesApps: false))
    }

    func testAnAccountAddedByNumberIsReadAndSelected() async throws {
        let ledger = FakeLedger(number: 17)
        let viewModel = ledger.viewModel()
        try await viewModel.start()
        let selected = expectation(description: "account 17 selected")
        selected.assertForOverFulfill = false
        viewModel.didUpdateState = { state in
            if state.accounts.contains(where: { $0.id == 16 && $0.isSelected }) {
                selected.fulfill()
            }
        }

        viewModel.addAccountByNumber()
        await fulfillment(of: [selected], timeout: 1)

        XCTAssertEqual(ledger.reads.last?.indices, [16])
        XCTAssertEqual(viewModel.state.accounts.map(\.id), [0, 1, 2, 16])
    }

    func testANumberAlreadyListedIsSelectedWithoutReadingAgain() async throws {
        let ledger = FakeLedger(number: 3)
        let viewModel = ledger.viewModel()
        try await viewModel.start()
        let selected = expectation(description: "account 3 selected")
        selected.assertForOverFulfill = false
        viewModel.didUpdateState = { state in
            if state.accounts.contains(where: { $0.id == 2 && $0.isSelected }) {
                selected.fulfill()
            }
        }

        viewModel.addAccountByNumber()
        await fulfillment(of: [selected], timeout: 1)

        XCTAssertEqual(ledger.reads.count, 1)
    }

    func testShowMoreGoesOnFromTheFirstAccountNotReadAfterOneAddedByNumber() async throws {
        let ledger = FakeLedger(number: 5)
        let viewModel = ledger.viewModel()
        try await viewModel.start()
        let added = expectation(description: "account 5 read")
        added.assertForOverFulfill = false
        let shown = expectation(description: "next page read")
        shown.assertForOverFulfill = false
        viewModel.didUpdateState = { state in
            if state.accounts.count == 4, !state.isReading {
                added.fulfill()
            }
            if state.accounts.count == 7 {
                shown.fulfill()
            }
        }

        viewModel.addAccountByNumber()
        await fulfillment(of: [added], timeout: 1)
        viewModel.showMore()
        await fulfillment(of: [shown], timeout: 1)

        XCTAssertEqual(ledger.reads.last?.indices, [3, 5, 6])
        XCTAssertEqual(viewModel.state.accounts.map(\.id), [0, 1, 2, 3, 4, 5, 6])
    }

    func testTheLastAccountAddedByNumberLeavesShowMoreForTheOthers() async throws {
        let ledger = FakeLedger(number: LedgerAccountsViewModel.maxAccountIndex + 1)
        let viewModel = ledger.viewModel()
        try await viewModel.start()
        let added = expectation(description: "the last account read")
        added.assertForOverFulfill = false
        viewModel.didUpdateState = { state in
            if state.accounts.count == 4, !state.isReading {
                added.fulfill()
            }
        }

        viewModel.addAccountByNumber()
        await fulfillment(of: [added], timeout: 1)

        XCTAssertTrue(viewModel.state.canShowMore)
    }

    func testTheChosenAccountsKeepTheKeysTheirAppsHandedOut() async throws {
        let ledger = FakeLedger(funded: [0, 2])
        let viewModel = ledger.viewModel()
        try await viewModel.start()
        var chosen: [LedgerAccount] = []
        viewModel.didChoose = { chosen = $0 }

        viewModel.toggle(2)
        viewModel.choose()
        let accounts = viewModel.multichainAccounts(chosen, proofs: [Data([1])])

        XCTAssertEqual(chosen.map(\.path.index), [0])
        XCTAssertEqual(accounts[AccountPath(index: 0)]?.proofSignature, Data([1]))
        XCTAssertEqual(accounts[AccountPath(index: 0)]?.keys.solana, FakeLedger.solanaKey(0))
    }

    func testOnlyTheAppsForTheSelectedNetworksAreRead() async throws {
        let ledger = FakeLedger()
        let viewModel = ledger.viewModel(chains: [.ton, .base, .tron])

        try await viewModel.start()

        XCTAssertEqual(ledger.reads, [FakeLedger.Read(indices: [0, 1, 2], apps: [.ethereum, .tron], choosesApps: true)])
    }
}

@MainActor
private final class FakeLedger {
    struct Read: Equatable {
        let indices: [Int]
        let apps: [LedgerApp]
        let choosesApps: Bool
    }

    private(set) var reads: [Read] = []

    private let funded: Set<Int>
    private let added: Set<Int>
    private let answering: [LedgerApp]
    private let number: Int?

    init(funded: Set<Int> = [], added: Set<Int> = [], answering: [LedgerApp] = LedgerDiscovery.chainApps, number: Int? = nil) {
        self.funded = funded
        self.added = added
        self.answering = answering
        self.number = number
    }

    static func solanaKey(_ index: Int) -> Data {
        Data(repeating: UInt8(index + 1), count: 32)
    }

    func viewModel(chains: [MultichainChain] = MultichainChain.displayOrder) -> LedgerAccountsViewModel {
        LedgerAccountsViewModel(chains: chains, dependencies: LedgerAccountsViewModel.Dependencies(
            read: { [unowned self] indices, apps, choosesApps in
                reads.append(Read(indices: indices, apps: apps, choosesApps: choosesApps))
                return LedgerDiscovery(
                    tonKeys: Dictionary(uniqueKeysWithValues: indices.map { ($0, Data(repeating: UInt8($0 + 1), count: 32)) }),
                    keys: Dictionary(uniqueKeysWithValues: indices.map { ($0, LedgerAppKeys(solana: Self.solanaKey($0))) }),
                    apps: apps.filter(answering.contains)
                )
            },
            loadBalances: { [funded] accounts in
                accounts.map { account in
                    ActiveWalletModel(
                        id: account.id,
                        revision: .v4R2,
                        address: try! Address.parse(raw: "0:0000000000000000000000000000000000000000000000000000000000000000"),
                        isActive: true,
                        balance: Balance(
                            tonBalance: TonBalance(amount: funded.contains(account.path.index) ? 1_000_000_000 : 0),
                            jettonsBalance: []
                        ),
                        nfts: [],
                        history: .unknown
                    )
                }
            },
            isAdded: { [added] account in
                added.contains(account.path.index)
            },
            askAccountNumber: { [number] in
                number
            },
            amountFormatter: AmountFormatter(configuration: .init())
        ))
    }
}
