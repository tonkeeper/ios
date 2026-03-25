import KeeperCore
import TKCore
import TKUIKit
import UIKit

public protocol SettingsListModuleOutput: AnyObject {
    var didOpenDevMenu: (() -> Void)? { get set }
}

protocol SettingsListViewModel: AnyObject {
    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)? { get set }
    var didUpdateState: ((SettingsListViewController.State) -> Void)? { get set }
    var didUpdateSnapshot: ((SettingsListViewController.Snapshot, _ animated: Bool) -> Void)? { get set }
    var selectedItems: Set<SettingsListItem> { get }

    func viewDidLoad()
    func openDevMenu()
}

struct SettingsListState {
    let state: SettingsListViewController.State
    let sections: [SettingsListSection]

    init(state: SettingsListViewController.State = .content, sections: [SettingsListSection]) {
        self.state = state
        self.sections = sections
    }
}

protocol SettingsListConfigurator: AnyObject {
    var title: String { get }
    var didUpdateState: ((SettingsListState) -> Void)? { get set }
    var selectedItems: Set<SettingsListItem> { get }
    func getInitialState() -> SettingsListState
}

extension SettingsListConfigurator {
    var selectedItems: Set<SettingsListItem> {
        []
    }
}

final class SettingsListViewModelImplementation: SettingsListViewModel, SettingsListModuleOutput {
    // MARK: - SettingsListModuleOutput

    var didOpenDevMenu: (() -> Void)?

    // MARK: - SettingsListViewModel

    var didUpdateTitleView: ((TKUINavigationBarTitleView.Model) -> Void)?
    var didUpdateState: ((SettingsListViewController.State) -> Void)?
    var didUpdateSnapshot: ((SettingsListViewController.Snapshot, Bool) -> Void)?
    var selectedItems: Set<SettingsListItem> {
        configurator.selectedItems
    }

    func viewDidLoad() {
        didUpdateTitleView?(TKUINavigationBarTitleView.Model(title: configurator.title))

        configurator.didUpdateState = { [weak self] state in
            DispatchQueue.main.async {
                self?.update(with: state, animated: false)
            }
        }

        let state = configurator.getInitialState()
        update(with: state, animated: false)
    }

    func openDevMenu() {
        didOpenDevMenu?()
    }

    private let configurator: SettingsListConfigurator

    init(configurator: SettingsListConfigurator) {
        self.configurator = configurator
    }

    private func update(with state: SettingsListState, animated: Bool) {
        var snapshot = SettingsListViewController.Snapshot()
        snapshot.appendSections(state.sections)
        for section in state.sections {
            switch section {
            case let .listItems(settingsListItemsSection):
                let items: [SettingsListViewController.Item] = settingsListItemsSection.items.map { item in
                    switch item {
                    case let .listItem(settingsItem):
                        return .settingsListItem(settingsItem)
                    case let .notificationBanner(notificationBanner):
                        return .notificationBanner(notificationBanner)
                    case let .button(buttonItem):
                        return .button(buttonItem)
                    }
                }
                snapshot.appendItems(items, toSection: section)
                if #available(iOS 15.0, *) {
                    snapshot.reconfigureItems(items)
                } else {
                    snapshot.reloadItems(items)
                }
            case let .appInformation(configuration):
                let items = [SettingsListViewController.Item.appInformation(configuration)]
                snapshot.appendItems(items, toSection: section)
                if #available(iOS 15.0, *) {
                    snapshot.reconfigureItems(items)
                } else {
                    snapshot.reloadItems(items)
                }
            case let .button(item):
                let items: [SettingsListViewController.Item] = [.button(item)]
                snapshot.appendItems(items, toSection: section)
                if #available(iOS 15.0, *) {
                    snapshot.reconfigureItems(items)
                } else {
                    snapshot.reloadItems(items)
                }
            }
        }
        didUpdateState?(state.state)
        didUpdateSnapshot?(snapshot, animated)
    }
}
