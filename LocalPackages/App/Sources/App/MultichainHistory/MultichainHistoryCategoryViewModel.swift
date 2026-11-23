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
    private let encryptedComments: MultichainEncryptedComments?
    private let appSettingsStore: AppSettingsStore
    private let currentDateProvider: () -> Date
    private let onAddFunds: (() -> Void)?

    private weak var screenRenderOwner: AnyObject?
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
        encryptedComments: MultichainEncryptedComments?,
        appSettingsStore: AppSettingsStore,
        currentDateProvider: @escaping () -> Date,
        onAddFunds: (() -> Void)?,
        screenRenderOwner: AnyObject? = nil
    ) {
        self.multichainState = multichainState
        self.category = category
        self.hidesDustTransactions = hidesDustTransactions
        self.showsPerps = showsPerps
        self.multichainService = multichainService
        self.amountFormatter = amountFormatter
        self.dateFormatter = dateFormatter
        self.nftResolver = nftResolver
        self.encryptedComments = encryptedComments
        self.appSettingsStore = appSettingsStore
        self.currentDateProvider = currentDateProvider
        self.onAddFunds = onAddFunds
        self.screenRenderOwner = screenRenderOwner
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
            encryptedComments: encryptedComments,
            appSettingsStore: appSettingsStore,
            currentDateProvider: currentDateProvider,
            onAddFunds: onAddFunds,
            screenRenderOwner: screenRenderOwner
        )
        cachedQueryViewModel = queryViewModel
        return queryViewModel
    }

    func disappeared() {
        cachedQueryViewModel?.disappeared()
    }
}
