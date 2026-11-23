import Foundation
import KeeperCore
import TKLogging

@MainActor
final class MultichainSwapQuoteViewModel {
    var onSnapshotChange: ((MultichainSwapQuoteSnapshot) -> Void)?
    var onProviderErrorMessage: ((String) -> Void)?
    var isSuspended = false {
        didSet {
            activePairViewModel?.isSuspended = isSuspended
        }
    }

    private let multichainSwapService: MultichainSwapService
    private let requestedAggregators: [String]
    private let debounce: MultichainSwapQuotePairViewModel.Wait?
    private let routeExpiryWait: MultichainSwapQuotePairViewModel.Wait?
    private let now: () -> Date
    private(set) var activePairViewModel: MultichainSwapQuotePairViewModel?

    init(
        multichainSwapService: MultichainSwapService,
        requestedAggregators: [String],
        debounce: MultichainSwapQuotePairViewModel.Wait? = nil,
        routeExpiryWait: MultichainSwapQuotePairViewModel.Wait? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.multichainSwapService = multichainSwapService
        self.requestedAggregators = requestedAggregators
        self.debounce = debounce
        self.routeExpiryWait = routeExpiryWait
        self.now = now
    }

    func reset() {
        activePairViewModel?.cancel()
        activePairViewModel = nil
        onSnapshotChange?(.initial())
    }

    func setPair(_ context: MultichainSwapQuotePairContext?) {
        activePairViewModel?.cancel()
        activePairViewModel = nil

        guard let context else {
            onSnapshotChange?(.initial())
            return
        }

        let pairViewModel = MultichainSwapQuotePairViewModel(
            context: context,
            multichainSwapService: multichainSwapService,
            requestedAggregators: requestedAggregators,
            debounce: debounce,
            routeExpiryWait: routeExpiryWait,
            now: now
        )
        pairViewModel.isSuspended = isSuspended
        pairViewModel.onSnapshotChange = { [weak self, weak pairViewModel] snapshot in
            guard let self, let pairViewModel, self.activePairViewModel === pairViewModel else {
                return
            }
            self.onSnapshotChange?(snapshot)
        }
        pairViewModel.onProviderErrorMessage = { [weak self, weak pairViewModel] message in
            guard let self, let pairViewModel, self.activePairViewModel === pairViewModel else {
                return
            }
            self.onProviderErrorMessage?(message)
        }
        activePairViewModel = pairViewModel
        onSnapshotChange?(pairViewModel.snapshot)
    }

    func updateAmount(_ amount: MultichainSwapQuoteAmount?, isMax: Bool, debounce: Bool) {
        guard let activePairViewModel else {
            onSnapshotChange?(.initial())
            return
        }
        activePairViewModel.updateAmount(amount, isMax: isMax, debounce: debounce)
    }

    func notifyCircularProgressCompleted() {
        activePairViewModel?.notifyCircularProgressCompleted()
    }

    func adopt(quote: MultichainSwapQuote, route: MultichainSwapRoute) {
        activePairViewModel?.adopt(quote: quote, route: route)
    }
}
