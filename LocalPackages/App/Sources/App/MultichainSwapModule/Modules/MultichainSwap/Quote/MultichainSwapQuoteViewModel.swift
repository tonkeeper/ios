import BigInt
import Foundation
import KeeperCore
import TKLocalize
import TKLogging

@MainActor
final class MultichainSwapQuoteViewModel {
    var onSnapshotChange: ((MultichainSwapQuoteSnapshot) -> Void)?
    var onProviderErrorMessage: ((String) -> Void)?

    private let multichainSwapService: MultichainSwapService
    private let amountFormatter: AmountFormatter
    private let requestedAggregators: [String]
    private var activePairViewModel: MultichainSwapQuotePairViewModel?

    init(
        multichainSwapService: MultichainSwapService,
        amountFormatter: AmountFormatter,
        requestedAggregators: [String]
    ) {
        self.multichainSwapService = multichainSwapService
        self.amountFormatter = amountFormatter
        self.requestedAggregators = requestedAggregators
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
            amountFormatter: amountFormatter,
            requestedAggregators: requestedAggregators
        )
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

    func updateSourceAmount(_ sourceAmount: BigUInt?, debounce: Bool) {
        guard let activePairViewModel else {
            onSnapshotChange?(.initial())
            return
        }
        activePairViewModel.updateSourceAmount(sourceAmount, debounce: debounce)
    }

    func notifyCircularProgressCompleted() {
        activePairViewModel?.notifyCircularProgressCompleted()
    }

    func toggleRateDisplayDirection() {
        activePairViewModel?.toggleRateDisplayDirection()
    }
}
