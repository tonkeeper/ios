import DisconnectDappToast
import TKCoordinator
import TKLocalize
import TKUIKit
import UIKit

final class BrowserConnectedViewController: GenericViewViewController<BrowserConnectedView>, ScrollViewController {
    enum State {
        case data
        case empty(TKEmptyViewController.Model)
    }

    var state: State = .data {
        didSet {
            setupState()
        }
    }

    private let viewModel: BrowserConnectedViewModel

    private lazy var dataSource = createDataSource()

    private lazy var appCellConfiguration = UICollectionView.CellRegistration<
        BrowserAppCollectionViewCell,
        BrowserAppCollectionViewCell.Configuration
    > { [weak self]
        cell, _, itemIdentifier in
            cell.configure(configuration: itemIdentifier)
    }

    private let emptyViewController = TKEmptyViewController()

    private lazy var layout = createLayout()

    init(viewModel: BrowserConnectedViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setup()
        setupBindings()
        viewModel.viewDidLoad()
    }

    func scrollToTop() {}

    func setListContentInsets(_ insets: UIEdgeInsets) {
        customView.collectionView.contentInset = insets
        customView.didUpdateTopInset()
    }
}

extension BrowserConnectedViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel.selectApp(index: indexPath.item)
    }
}

// MARK: - Private

private extension BrowserConnectedViewController {
    func setup() {
        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.delegate = self

        addChild(emptyViewController)
        customView.embedEmptyView(emptyViewController.view)
        emptyViewController.didMove(toParent: self)
    }

    func setupBindings() {
        viewModel.didUpdateSnapshot = { [weak self] snapshot in
            self?.dataSource.apply(snapshot, animatingDifferences: false)
        }

        viewModel.didUpdateViewState = { [weak self] state in
            self?.state = state
        }

        viewModel.presentDisconnectAppToast = { [weak self] model in
            guard let windowScene = self?.windowScene else { return }
            DisconnectDappToastPresenter.presentToast(
                model: model,
                windowScene: windowScene
            )
        }
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        configuration.interSectionSpacing = 16

        return UICollectionViewCompositionalLayout(sectionProvider: {
            [weak self] sectionIndex, environment -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }

            let snapshot = dataSource.snapshot()
            let section = snapshot.sectionIdentifiers[sectionIndex]
            switch section {
            case .apps:
                return appsSectionLayout(
                    snapshot: snapshot,
                    section: section,
                    environment: environment
                )
            }
        }, configuration: configuration)
    }

    func appsSectionLayout(
        snapshot: BrowserConnected.Snapshot,
        section: BrowserConnected.Section,
        environment: NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1 / 4),
            heightDimension: .absolute(104)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 8)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(104)
        )

        let group: NSCollectionLayoutGroup

        if #available(iOS 16.0, *) {
            group = NSCollectionLayoutGroup.horizontalGroup(
                with: groupSize,
                repeatingSubitem: item,
                count: 4
            )
        } else {
            group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitem: item,
                count: 4
            )
        }
        group.contentInsets = .init(top: 0, leading: 12, bottom: 0, trailing: 12)

        return NSCollectionLayoutSection(group: group)
    }

    func createDataSource() -> BrowserConnected.DataSource {
        return BrowserConnected.DataSource(collectionView: customView.collectionView) { [appCellConfiguration] collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueConfiguredReusableCell(
                using: appCellConfiguration,
                for: indexPath,
                item: itemIdentifier.configuration
            )

            cell.didLongPress = {
                itemIdentifier.longPressHandler?()
            }

            return cell
        }
    }

    private func setupState() {
        switch state {
        case .data:
            customView.emptyViewContainer.isHidden = true
            customView.collectionView.isHidden = false
        case let .empty(model):
            emptyViewController.configure(model: model)
            customView.emptyViewContainer.isHidden = false
            customView.collectionView.isHidden = true
        }
    }
}
