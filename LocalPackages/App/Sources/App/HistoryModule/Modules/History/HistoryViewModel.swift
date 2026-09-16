import KeeperCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

protocol HistoryModuleOutput: AnyObject {
    var didSelectSpamHistory: (() -> Void)? { get set }
}

protocol HistoryModuleInput: AnyObject {
    func setHistoryListState(_ state: HistoryList.State)
}

protocol HistoryViewModel: AnyObject {
    var didUpdateIsConnecting: ((Bool) -> Void)? { get set }

    var didUpdateTabs: (([TKTabsView.Item]) -> Void)? { get set }
    var didUpdateTabViewIsHidden: ((Bool) -> Void)? { get set }
    var didUpdateSelectedTab: ((TKTabsView.Item) -> Void)? { get set }

    @MainActor var presentationStyle: HistoryPresentationStyle { get set }
    @MainActor func viewDidLoad()
    @MainActor func close()
}

final class HistoryV2ViewModelImplementation: HistoryViewModel, HistoryModuleOutput, HistoryModuleInput {
    // MARK: - HistoryModuleOutput

    var didSelectSpamHistory: (() -> Void)?
    @MainActor var presentationStyle: HistoryPresentationStyle

    // MARK: - HistoryViewModel

    var didUpdateIsConnecting: ((Bool) -> Void)?
    var didUpdateTabs: (([TKTabsView.Item]) -> Void)?
    var didUpdateTabViewIsHidden: ((Bool) -> Void)?
    var didUpdateSelectedTab: ((TKTabsView.Item) -> Void)?

    private let wallet: Wallet
    private let backgroundUpdate: BackgroundUpdate
    private let historyListModuleInput: HistoryListModuleInput
    private let configuration: Configuration
    private var tabs: [TKTabsView.Item] = []
    private var backgroundStateTask: Task<Void, Never>?

    init(
        wallet: Wallet,
        backgroundUpdate: BackgroundUpdate,
        historyListModuleInput: HistoryListModuleInput,
        configuration: Configuration,
        presentationStyle: HistoryPresentationStyle
    ) {
        self.wallet = wallet
        self.backgroundUpdate = backgroundUpdate
        self.historyListModuleInput = historyListModuleInput
        self.configuration = configuration
        self.presentationStyle = presentationStyle
    }

    deinit {
        backgroundStateTask?.cancel()
    }

    func setHistoryListState(_ state: HistoryList.State) {
        switch state {
        case .loading:
            didUpdateTabViewIsHidden?(true)
        case .content, .empty:
            didUpdateTabViewIsHidden?(false)
        }
    }

    @MainActor func viewDidLoad() {
        setupTabs()

        let walletID = wallet.id
        didUpdateIsConnecting?(isConnecting(backgroundUpdate.connectionState(walletID: walletID)))
        backgroundStateTask?.cancel()
        backgroundStateTask = Task { @MainActor [weak self, backgroundUpdate] in
            for await update in backgroundUpdate.stateUpdates() {
                guard let self else { return }
                guard update.walletID == walletID else { continue }
                didUpdateIsConnecting?(isConnecting(update.state))
            }
        }
    }

    private func isConnecting(_ backgroundUpdateState: BackgroundUpdateConnectionState) -> Bool {
        switch backgroundUpdateState {
        case .connected: return false
        default: return true
        }
    }

    private func setupTabs() {
        tabs = [
            TKTabsView.Item(
                title: TKLocales.History.Tab.all,
                isSelectable: true,
                action: { [weak self] in
                    self?.historyListModuleInput.filter = .all
                }
            ),
            TKTabsView.Item(
                title: TKLocales.History.Tab.sent,
                isSelectable: true,
                action: { [weak self] in
                    self?.historyListModuleInput.filter = .sent
                }
            ),
            TKTabsView.Item(
                title: TKLocales.History.Tab.received,
                isSelectable: true,
                action: { [weak self] in
                    self?.historyListModuleInput.filter = .received
                }
            ),
            TKTabsView.Item(
                title: TKLocales.History.Tab.spam,
                isSelectable: false,
                action: { [weak self] in
                    self?.didSelectSpamHistory?()
                }
            ),
        ]
        didUpdateTabs?(tabs)
        didUpdateTabViewIsHidden?(true)

        if let allTab = tabs.first {
            didUpdateSelectedTab?(allTab)
        }
    }

    @MainActor func close() {
        backgroundStateTask?.cancel()
        presentationStyle.closeAction?()
    }
}
