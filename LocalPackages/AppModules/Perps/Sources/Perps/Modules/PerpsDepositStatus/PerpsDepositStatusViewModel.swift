import Foundation
import PerpsModels
import TKLocalize

@MainActor
public final class PerpsDepositStatusViewModel: ObservableObject {
    enum Banner: Equatable {
        case single(String)
        case multiple
        case problems
        case completed(Set<String>)
    }

    @Published private(set) var deposits: [PerpsDepositStatus] = []
    @Published private(set) var banner: Banner?
    let format: PerpsFormatting
    public var onCompleted: (() -> Void)?
    public var isVisible = true

    private var watched: Set<String> = []
    private var announced: Set<String> = []
    private var acknowledged: Set<String> = []
    private var grouped: Set<String> = []
    private var listAnnounced: Set<String> = []
    private var completedTimeout: Task<Void, Never>?
    private let accountStore: any PerpsAccountStoring
    private let completedRowLifetime: @Sendable () async -> Void

    public init(
        accountStore: any PerpsAccountStoring,
        format: PerpsFormatting,
        completedRowLifetime: @escaping @Sendable () async -> Void = { try? await Task.sleep(nanoseconds: 5_000_000_000) }
    ) {
        self.format = format
        self.accountStore = accountStore
        self.completedRowLifetime = completedRowLifetime
        apply(accountStore.fundingActivity())
        accountStore.addChangeObserver(self) { observer in
            Task { @MainActor in observer.apply(observer.accountStore.fundingActivity()) }
        }
    }

    private func apply(_ activity: PerpsFundingActivity) {
        acknowledged.formUnion(activity.acknowledgedDepositIds)
        apply(activity.deposits, isBalanceRefreshing: activity.isBalanceRefreshing)
    }

    func apply(_ values: [PerpsDepositStatus], isBalanceRefreshing: Bool = false) {
        let values = values.map { value in
            if isBalanceRefreshing, value.state == .completed, watched.contains(value.id),
               let previous = deposits.first(where: { $0.id == value.id })
            {
                return previous
            }
            return value
        }.sorted { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) }
        // A credited deposit can briefly read as in flight again; it stays announced.
        let pending = Set(values.filter { $0.state == .pending && !announced.contains($0.id) }.map(\.id))
        let completed = Set(values.filter { $0.state == .completed }.map(\.id))
        let arrived = watched.intersection(completed).subtracting(announced)
        announced.formUnion(arrived)
        watched = pending
        if deposits != values { deposits = values }
        let next: Banner?
        if pending.count > 1 {
            grouped.formUnion(pending)
            next = .multiple
        } else if let id = pending.first {
            next = .single(id)
        } else if !arrived.isEmpty, isVisible {
            next = .completed(arrived)
        } else if case .completed = banner {
            next = banner
        } else {
            let problems = values.filter { isProblem($0) && !acknowledged.contains($0.id) }
            next = problems.contains { grouped.contains($0.id) }
                ? .problems
                : problems.first.map { .single($0.id) }
        }
        if banner != next {
            banner = next
            completedTimeout?.cancel()
            completedTimeout = nil
        }
        if !arrived.isEmpty { onCompleted?() }
    }

    func didInteract() {
        guard case .completed = banner else { return }
        completedTimeout?.cancel()
        completedTimeout = nil
        banner = nil
        apply(deposits)
    }

    /// The completed row's lifetime starts once the row is on screen.
    func didShowBanner() {
        guard case .completed = banner, completedTimeout == nil else { return }
        completedTimeout = Task { [weak self, completedRowLifetime] in
            await completedRowLifetime()
            guard !Task.isCancelled else { return }
            self?.didInteract()
        }
    }

    /// Returns the deposits this list hides: ones already seen when it last closed.
    @discardableResult
    func didOpenList() -> Set<String> {
        let hidden = Set(deposits.filter { $0.state != .pending && acknowledged.contains($0.id) }.map(\.id))
            .subtracting(listAnnounced)
        listAnnounced = []
        let ids = Set(deposits.filter(isProblem).map(\.id))
        acknowledged.formUnion(ids)
        accountStore.acknowledgeDepositStatuses(ids)
        apply(deposits)
        return hidden
    }

    /// The completed row's tap also counts as an interaction that clears it, so it hands over its ids.
    func willOpenList(announcing ids: Set<String>) {
        listAnnounced = ids
    }

    func didCloseList() {
        let ids = Set(deposits.filter { $0.state != .pending }.map(\.id)).subtracting(acknowledged)
        guard !ids.isEmpty else { return }
        acknowledged.formUnion(ids)
        accountStore.acknowledgeDepositStatuses(ids)
    }

    public func didOpen(_ id: String) {
        guard let deposit = deposits.first(where: { $0.id == id }), isProblem(deposit) else { return }
        acknowledged.insert(id)
        accountStore.acknowledgeDepositStatuses([id])
        apply(deposits)
    }

    func deposit(_ id: String) -> PerpsDepositStatus? {
        deposits.first { $0.id == id }
    }

    func amount(_ deposit: PerpsDepositStatus) -> String {
        format.hiddenBalanceText ?? PerpsFundingAmountInput.decimal(deposit.sourceAmount)
            .map { format.tokenCompact($0, symbol: deposit.sourceSymbol) } ?? "—"
    }

    func received(_ deposit: PerpsDepositStatus) -> String {
        guard let amount = creditedAmount(of: deposit) ?? deposit.expectedAmount else { return "—" }
        return format.balance(amount)
    }

    /// A credit seen without its size (a fun.xyz bridge deposit) has none; callers fall back to the expected amount.
    private func creditedAmount(of deposit: PerpsDepositStatus) -> String? {
        deposit.state == .completed ? deposit.creditedAmount : nil
    }

    func duration(_ deposit: PerpsDepositStatus) -> String? {
        deposit.estimatedDurationSeconds.map(Self.minutes)
    }

    private static func minutes(_ seconds: Int) -> String {
        TKLocales.Perps.DepositStatus.approximateMinutes(max(1, Int((Double(seconds) / 60).rounded())))
    }

    private func isProblem(_ deposit: PerpsDepositStatus) -> Bool {
        switch deposit.state {
        case .failed, .refunded, .unconfirmed: true
        case .pending, .completed: false
        }
    }

    func completionText(_ ids: Set<String>) -> String {
        let amounts = deposits.filter { ids.contains($0.id) }.map(\.creditedAmount)
        guard amounts.count == ids.count,
              amounts.allSatisfy({ $0.flatMap(PerpsFundingAmountInput.decimal) != nil })
        else {
            return TKLocales.Perps.DepositStatus.completed
        }
        let sum = amounts.compactMap { $0.flatMap(PerpsFundingAmountInput.decimal) }.reduce(Decimal.zero, +)
        let amount = format.hiddenBalanceText ?? "+" + format.usd(NSDecimalNumber(decimal: sum).doubleValue)
        return TKLocales.Perps.DepositStatus.addedToBalance(amount)
    }

    func listedAmount(_ deposit: PerpsDepositStatus) -> (text: String, positive: Bool) {
        let credited = creditedAmount(of: deposit)
        guard let raw = credited ?? deposit.expectedAmount else { return ("—", false) }
        if format.hiddenBalanceText != nil { return (format.balance(raw), false) }
        if credited == nil {
            let text = format.balance(raw)
            return (deposit.state == .completed ? TKLocales.Perps.DepositStatus.approximateAmount(text) : text, false)
        }
        let value = PerpsFundingAmountInput.decimal(raw).map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0
        return (format.signedBalance(value), true)
    }
}
