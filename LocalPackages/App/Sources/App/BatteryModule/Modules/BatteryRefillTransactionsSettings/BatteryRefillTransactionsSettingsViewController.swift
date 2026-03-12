import TKUIKit
import UIKit

final class BatteryRefillTransactionsSettingsViewController: GenericViewViewController<BatteryRefillTransactionsSettingsView> {
    private let viewModel: BatteryRefillTransactionsSettingsViewModel

    // MARK: - List

    private lazy var layout = createLayout()
    private lazy var dataSource = createDataSource()

    // MARK: - Init

    init(viewModel: BatteryRefillTransactionsSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }
}

private extension BatteryRefillTransactionsSettingsViewController {
    func setup() {
        customView.navigationBar.apperance = .transparent
        setupNavigationBar()
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.delegate = self
    }

    func setupBindings() {
        viewModel.didUpdateSnapshot = { [weak self] snapshot in
            guard let self else { return }
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    private func setupNavigationBar() {
        if presentingViewController != nil {
            customView.navigationBar.rightViews = [
                TKUINavigationBar.createCloseButton { [weak self] in
                    self?.dismiss(animated: true)
                },
            ]
        }

        if let navigationController, navigationController.viewControllers.count > 1 {
            customView.navigationBar.leftViews = [
                TKUINavigationBar.createBackButton {
                    navigationController.popViewController(animated: true)
                },
            ]
        }
    }

    func createDataSource() -> BatteryRefillTransactionsSettings.DataSource {
        let listCellRegistration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
        let titleDescriptionRegistration = TKTitleDescriptionCellRegistration.registration(collectionView: customView.collectionView)

        return BatteryRefillTransactionsSettings.DataSource(
            collectionView: customView.collectionView
        ) {
            collectionView, indexPath, itemIdentifier -> UICollectionViewCell? in
            switch itemIdentifier {
            case let .listItem(listItem):
                let cell = collectionView.dequeueConfiguredReusableCell(
                    using: listCellRegistration,
                    for: indexPath,
                    item: listItem.cellConfiguration
                )
                cell.defaultAccessoryViews = [listItem.accessory.view]
                return cell
            case let .title(model):
                return collectionView.dequeueConfiguredReusableCell(
                    using: titleDescriptionRegistration,
                    for: indexPath,
                    item: model
                )
            }
        }
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(sectionProvider: { _, _ in
            let itemLayoutSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(96)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)

            let groupLayoutSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(96)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupLayoutSize,
                subitems: [item]
            )

            let layoutSection = NSCollectionLayoutSection(group: group)
            layoutSection.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: 16,
                bottom: 16,
                trailing: 16
            )

            return layoutSection
        }, configuration: configuration)
    }
}

extension BatteryRefillTransactionsSettingsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {}

    func collectionView(
        _ collectionView: UICollectionView,
        shouldSelectItemAt indexPath: IndexPath
    ) -> Bool {
        false
    }

    func collectionView(
        _ collectionView: UICollectionView,
        shouldHighlightItemAt indexPath: IndexPath
    ) -> Bool {
        false
    }
}
