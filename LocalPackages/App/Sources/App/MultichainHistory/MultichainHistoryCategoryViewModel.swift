import Foundation
import KeeperCore

@MainActor
final class MultichainHistoryCategoryViewModel {
    private let multichainState: MultichainWalletState
    private let category: MultichainHistoryCategory
    private let hidesDustTransactions: Bool
    private let showsPerps: Bool
    private let multichainService: MultichainService
    private let amountFormatter: AmountFormatter
    private let dateFormatter: DateFormatter
    private let nftResolver: MultichainActivityNFTResolver
    private let currentDateProvider: () -> Date
    private let onAddFunds: () -> Void

    private var cachedQueryViewModel: MultichainHistoryQueryViewModel?

    init(
        multichainState: MultichainWalletState,
        category: MultichainHistoryCategory,
        hidesDustTransactions: Bool,
        showsPerps: Bool,
        multichainService: MultichainService,
        amountFormatter: AmountFormatter,
        dateFormatter: DateFormatter,
        nftResolver: MultichainActivityNFTResolver,
        currentDateProvider: @escaping () -> Date,
        onAddFunds: @escaping () -> Void
    ) {
        self.multichainState = multichainState
        self.category = category
        self.hidesDustTransactions = hidesDustTransactions
        self.showsPerps = showsPerps
        self.multichainService = multichainService
        self.amountFormatter = amountFormatter
        self.dateFormatter = dateFormatter
        self.nftResolver = nftResolver
        self.currentDateProvider = currentDateProvider
        self.onAddFunds = onAddFunds
    }

    func queryViewModel() -> MultichainHistoryQueryViewModel {
        if let cachedQueryViewModel {
            return cachedQueryViewModel
        }

        let queryViewModel = MultichainHistoryQueryViewModel(
            multichainState: multichainState,
            category: category,
            hidesDustTransactions: hidesDustTransactions,
            showsPerps: showsPerps,
            multichainService: multichainService,
            amountFormatter: amountFormatter,
            dateFormatter: dateFormatter,
            nftResolver: nftResolver,
            currentDateProvider: currentDateProvider,
            onAddFunds: onAddFunds
        )
        cachedQueryViewModel = queryViewModel
        return queryViewModel
    }

    func disappeared() {
        cachedQueryViewModel?.disappeared()
    }
}
