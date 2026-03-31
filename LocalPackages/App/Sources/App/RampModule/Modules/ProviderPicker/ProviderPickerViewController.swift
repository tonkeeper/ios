import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

final class ProviderPickerViewController: GenericViewViewController<ProviderPickerView>, TKBottomSheetScrollContentViewController {
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, ProviderPickerItem>
    typealias DataSource = UICollectionViewDiffableDataSource<Section, ProviderPickerItem>
    typealias SectionFooterRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<TKListItemTextView>>

    enum Section: Hashable {
        case providers
    }

    private let viewModel: ProviderPickerViewModelProtocol
    private lazy var dataSource = createDataSource()

    private lazy var sheetHeaderItem: TKPullCardHeaderItem = TKPullCardHeaderItem(
        title: .title(title: TKLocales.Ramp.ProviderPicker.title, subtitle: nil),
        leftButton: TKPullCardHeaderItem.LeftButton(
            model: TKUIHeaderButtonIconContentView.Model(image: .TKUIKit.Icons.Size16.chevronDown),
            action: { [weak viewModel] _ in
                viewModel?.didTapCloseButton()
            }
        ),
        isTitleCentered: true,
        isCloseButtonHidden: true
    )

    // MARK: - TKBottomSheetScrollContentViewController

    var scrollView: UIScrollView {
        customView.collectionView
    }

    var didUpdateHeight: (() -> Void)?

    var headerItem: TKPullCardHeaderItem? {
        sheetHeaderItem
    }

    var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        scrollView.contentSize.height
    }

    // MARK: - Init

    init(viewModel: ProviderPickerViewModelProtocol) {
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
}

private extension ProviderPickerViewController {
    func setup() {
        customView.collectionView.delegate = self
        customView.collectionView.setCollectionViewLayout(createLayout(), animated: false)
    }

    func setupBindings() {
        viewModel.didUpdateSnapshot = { [weak self] snapshot in
            guard let self else { return }

            let contentOffset = customView.collectionView.contentOffset
            dataSource.apply(snapshot, animatingDifferences: false) {
                self.customView.collectionView.layoutIfNeeded()
                self.customView.collectionView.contentOffset = contentOffset
            }
            customView.collectionView.layoutIfNeeded()
            customView.collectionView.contentOffset = contentOffset
            didUpdateHeight?()
        }
    }

    func createDataSource() -> DataSource {
        let cellRegistration = UICollectionView.CellRegistration<TKListItemCell, ProviderPickerItem> { [weak self] cell, _, item in
            guard let self else { return }
            let configuration = ProviderPickerModule.mapItemConfiguration(item: item)
            cell.configuration = configuration
            cell.defaultAccessoryViews = item.isSelected
                ? [TKListItemAccessory.icon(TKListItemIconAccessoryView.Configuration(
                    icon: .TKUIKit.Icons.Size28.donemarkOutline,
                    tintColor: .Accent.blue
                )).view] : []
            let collectionView = self.customView.collectionView
            cell.isFirstInSection = { $0.item == 0 }
            cell.isLastInSection = { $0.item == collectionView.numberOfItems(inSection: $0.section) - 1 }
        }

        let sectionFooterRegistration = SectionFooterRegistration(
            elementKind: Self.sectionFooterElementKind
        ) { supplementaryView, _, _ in
            supplementaryView.configure(model: TKListItemTextView.Configuration(
                text: TKLocales.Ramp.ProviderPicker.footer,
                color: .Text.secondary,
                textStyle: .body2,
                numberOfLines: 0,
                padding: UIEdgeInsets(top: 12, left: 0, bottom: 16, right: 0)
            ))
        }

        let dataSource = DataSource(collectionView: customView.collectionView) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            if kind == Self.sectionFooterElementKind {
                return collectionView.dequeueConfiguredReusableSupplementary(
                    using: sectionFooterRegistration,
                    for: indexPath
                )
            }
            return nil
        }
        return dataSource
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(72)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
            let layoutSection = NSCollectionLayoutSection(group: group)
            layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
            layoutSection.interGroupSpacing = 0

            let footerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(68)
            )
            let footer = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: footerSize,
                elementKind: Self.sectionFooterElementKind,
                alignment: .bottom
            )

            layoutSection.boundarySupplementaryItems = [footer]

            return layoutSection
        }
    }
}

extension ProviderPickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel.didSelectMerchant(at: indexPath.item)
    }
}

private extension ProviderPickerViewController {
    static let sectionFooterElementKind = "ProviderPickerSectionFooterElementKind"
}
