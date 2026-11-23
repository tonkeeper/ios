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
    var didUpdateTabs: (([TKTabsView.Item]) -> Void)? { get set }
    var didUpdateTabViewIsHidden: ((Bool) -> Void)? { get set }
    var didUpdateSelectedTab: ((TKTabsView.Item) -> Void)? { get set }

    @MainActor func viewDidLoad()
    @MainActor func close()
}

final class HistoryV2ViewModelImplementation: HistoryViewModel, HistoryModuleOutput, HistoryModuleInput {
    // MARK: - HistoryModuleOutput

    var didSelectSpamHistory: (() -> Void)?
    private let closeAction: (() -> Void)?

    // MARK: - HistoryViewModel

    var didUpdateTabs: (([TKTabsView.Item]) -> Void)?
    var didUpdateTabViewIsHidden: ((Bool) -> Void)?
    var didUpdateSelectedTab: ((TKTabsView.Item) -> Void)?

    private let historyListModuleInput: HistoryListModuleInput
    private var tabs: [TKTabsView.Item] = []

    init(
        historyListModuleInput: HistoryListModuleInput,
        closeAction: (() -> Void)?
    ) {
        self.historyListModuleInput = historyListModuleInput
        self.closeAction = closeAction
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
        closeAction?()
    }
}
