import AppUI
import Foundation
import KeeperCore
import TKCore
import TKLogging

@MainActor
final class WalletBalanceEarnPortfolioViewModel: ObservableObject {
    enum State: Equatable {
        case noEVMAccount
        case loading
        case empty
        case positions(EarnPortfolioSectionState)
        case unavailable
    }

    @Published private(set) var state: State = .noEVMAccount

    var onSelectPosition: ((EarnPosition) -> Void)?
    var onOpenCatalog: (() -> Void)?

    private var address: String?
    private let repository: EarnPortfolioRepository
    private let mapper: ([EarnPosition], Bool) -> EarnPortfolioSectionState
    private let analyticsProvider: AnalyticsProvider
    private let freshnessModel = BalanceFreshnessModel()
    private var positions: [EarnPosition]?
    private var loadTask: Task<Void, Never>?
    private var isActive = true
    private var isPositionsViewReported = false

    init(
        address: String?,
        repository: EarnPortfolioRepository,
        mapper: @escaping ([EarnPosition], Bool) -> EarnPortfolioSectionState,
        analyticsProvider: AnalyticsProvider
    ) {
        self.address = address
        self.repository = repository
        self.mapper = mapper
        self.analyticsProvider = analyticsProvider
        restoreCachedPositions()
        freshnessModel.onNeedsRefresh = { [weak self] in
            self?.reload()
        }
    }

    func adopt(address: String?) {
        guard self.address != address else { return }
        self.address = address
        loadTask?.cancel()
        loadTask = nil
        restoreCachedPositions()
        reload()
    }

    func setActive(_ isActive: Bool) {
        self.isActive = isActive
        guard !isActive else { return }
        freshnessModel.didDisappear()
        loadTask?.cancel()
        loadTask = nil
    }

    func didAppear() {
        freshnessModel.didAppear()
    }

    func didDisappear() {
        freshnessModel.didDisappear()
    }

    func positionsDidAppear() {
        guard !isPositionsViewReported, let positions, !positions.isEmpty else { return }
        isPositionsViewReported = true
        analyticsProvider.log(
            EarnEntryView(
                from: .earnYourVaults,
                vaultsCount: positions.count,
                balanceUsd: NSDecimalNumber(decimal: positions.reduce(0) { $0 + $1.balanceUsd }).doubleValue
            )
        )
    }

    func positionsDidDisappear() {
        isPositionsViewReported = false
    }

    func refresh() async {
        guard let address else { return }
        await startLoad(address: address).value
    }

    func reload() {
        guard let address, isActive else { return }
        startLoad(address: address)
    }

    func openCatalog() {
        onOpenCatalog?()
    }

    func selectRow(id: String) {
        guard let position = positions?.first(where: { $0.rowId == id }) else { return }
        onSelectPosition?(position)
    }

    private func restoreCachedPositions() {
        if let address, let cached = repository.cachedPositions(address: address) {
            positions = cached
            state = Self.state(for: cached, isStale: false, mapper: mapper)
        } else {
            positions = nil
            state = address == nil ? .noEVMAccount : .loading
        }
    }

    @discardableResult
    private func startLoad(address: String) -> Task<Void, Never> {
        loadTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.load(address: address)
        }
        loadTask = task
        return task
    }

    private func load(address: String) async {
        do {
            let positions = try await repository.loadPositions(address: address)
            guard !Task.isCancelled, address == self.address else { return }
            self.positions = positions
            state = Self.state(for: positions, isStale: false, mapper: mapper)
        } catch {
            guard !Task.isCancelled, address == self.address else { return }
            Log.w("earn positions load failed", extraInfo: ["address": address, "error": "\(error)"])
            if let positions {
                state = Self.state(for: positions, isStale: true, mapper: mapper)
            } else {
                state = .unavailable
            }
        }
    }

    private static func state(
        for positions: [EarnPosition],
        isStale: Bool,
        mapper: ([EarnPosition], Bool) -> EarnPortfolioSectionState
    ) -> State {
        positions.isEmpty ? .empty : .positions(mapper(positions, isStale))
    }
}
