import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol BrowserCategoryModuleOutput: AnyObject {
    var didSelectDapp: ((Dapp) -> Void)? { get set }
    var didTapSearch: (() -> Void)? { get set }
}

protocol BrowserCategoryViewModel: AnyObject {
    var didUpdateSnapshot: ((BrowserCategory.Snapshot) -> Void)? { get set }
    var didUpdateTitle: ((String?) -> Void)? { get set }

    func viewDidLoad()
    func didTapSearchBar()
}

final class BrowserCategoryViewModelImplementation: BrowserCategoryViewModel, BrowserCategoryModuleOutput {
    // MARK: - BrowserCategoryModuleOutput

    var didSelectDapp: ((Dapp) -> Void)?
    var didTapSearch: (() -> Void)?

    // MARK: - BrowserCategoryViewModel

    var didUpdateSnapshot: ((BrowserCategory.Snapshot) -> Void)?
    var didUpdateTitle: ((String?) -> Void)?

    func viewDidLoad() {
        configure()
        reloadContent()
    }

    // MARK: - State

    // MARK: - Dependencies

    private let category: PopularAppsCategory

    // MARK: - Init

    init(category: PopularAppsCategory) {
        self.category = category
    }

    func didTapSearchBar() {
        didTapSearch?()
    }
}

private extension BrowserCategoryViewModelImplementation {
    func configure() {
        didUpdateTitle?(category.title)
    }

    func reloadContent() {
        let mappedCategory = mapCategory(category)
        updateSnapshot(sections: [mappedCategory])
    }

    func mapCategory(_ category: PopularAppsCategory) -> BrowserCategory.SnapshotSection {
        let items = category.apps.map { mapDapp($0) }
        return BrowserCategory.SnapshotSection.regular(items: items)
    }

    func mapDapp(_ dapp: PopularApp) -> BrowserCategory.Item {
        return BrowserCategory.Item(
            identifier: UUID().uuidString,
            configuration: BrowserCategory.mapListItemConfiguration(app: dapp),
            selectionHandler: { [weak self] in
                guard let dapp = Dapp(popularApp: dapp) else { return }
                self?.didSelectDapp?(dapp)
            }
        )
    }

    func updateSnapshot(sections: [BrowserCategory.SnapshotSection]) {
        var snapshot = BrowserCategory.Snapshot()
        snapshot.appendSections(sections)
        for section in sections {
            switch section {
            case let .regular(items):
                snapshot.appendItems(items, toSection: section)
            }
        }
        didUpdateSnapshot?(snapshot)
    }
}
