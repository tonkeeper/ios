import TKLocalize
import TKUIKit
import UIKit

final class RampPickerViewController: GenericViewViewController<RampPickerView> {
    typealias SectionHeaderRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<RampPickerWarningHeaderView>>
    typealias SectionFooterRegistration = UICollectionView.SupplementaryRegistration<TKCollectionViewSupplementaryContainerView<TKListItemTextView>>

    private lazy var dataSource = createDataSource()
    private var headerText: String?
    private var footerText: String?

    private let viewModel: RampPickerViewModel
    private var showsSelectionCheckmark = false

    init(viewModel: RampPickerViewModel) {
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        customView.searchBar.textField.resignFirstResponder()
    }

    @objc
    private func searchTextChanged() {
        let text = customView.searchBar.textField.text ?? ""
        viewModel.search(text: text)
    }
}

private extension RampPickerViewController {
    func setup() {
        customView.collectionView.delegate = self
        customView.searchBar.textField.returnKeyType = .search
        customView.searchBar.textField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        customView.searchBar.textField.delegate = self

        customView.titleView.configure(model: TKUINavigationBarTitleView.Model(title: ""))
        customView.navigationBar.leftViews = [
            TKUINavigationBar.createBackButton { [weak self] in
                self?.viewModel.didTapBackButton()
            },
        ]
        customView.navigationBar.rightViews = [
            TKUINavigationBar.createCloseButton { [weak self] in
                self?.viewModel.didTapCloseButton()
            },
        ]
        customView.navigationBar.didTapNavigationBar = { [weak self] in
            self?.view.endEditing(true)
        }

        setupCollectionLayout()
    }

    func setupBindings() {
        viewModel.didUpdateTitle = { [weak self] title in
            self?.customView.titleView.configure(
                model: TKUINavigationBarTitleView.Model(
                    title: title.withTextStyle(
                        .h3,
                        color: .Text.primary,
                        alignment: .center,
                        lineBreakMode: .byTruncatingTail
                    )
                )
            )
        }

        viewModel.didUpdateSnapshot = { [weak self] snapshot in
            guard let self else { return }

            customView.zeroSearchLabel.isHidden = snapshot.numberOfItems != .zero

            let contentOffset = customView.collectionView.contentOffset
            dataSource.apply(snapshot, animatingDifferences: false) {
                self.customView.collectionView.layoutIfNeeded()
                self.customView.collectionView.contentOffset = contentOffset
            }
            customView.collectionView.layoutIfNeeded()
            customView.collectionView.contentOffset = contentOffset
        }

        viewModel.didUpdateShowsSelectionCheckmark = { [weak self] shows in
            self?.showsSelectionCheckmark = shows
        }

        viewModel.didUpdateSelectedIndex = { [weak self] index, scroll in
            guard let self else { return }
            guard let index else {
                customView.collectionView.selectItem(at: nil, animated: false, scrollPosition: [])
                return
            }
            customView.collectionView.selectItem(
                at: IndexPath(item: index, section: 0),
                animated: false,
                scrollPosition: scroll ? [.centeredVertically] : []
            )
        }

        viewModel.didUpdateLayoutConfiguration = { [weak self] config in
            guard let self else { return }
            headerText = config.headerText
            footerText = config.footerText
            customView.isSearchBarHidden = config.isSearchBarHidden
            setupCollectionLayout()
        }

        customView.searchBar.cancelButtonAction = { [weak self] in
            self?.searchTextChanged()
        }

        customView.searchBar.clearButtonAction = { [weak self] in
            self?.searchTextChanged()
        }
    }

    func setupCollectionLayout() {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        let hasHeader = (headerText != nil)
        let hasFooter = (footerText != nil)

        let layout = UICollectionViewCompositionalLayout(sectionProvider: { _, _ in
            let item = NSCollectionLayoutItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(56)
                )
            )

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(56)
                ),
                subitems: [item]
            )

            let sectionLayout = NSCollectionLayoutSection(group: group)
            sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

            if hasHeader || hasFooter {
                var boundaryItems: [NSCollectionLayoutBoundarySupplementaryItem] = []
                if hasHeader {
                    let headerSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(68)
                    )
                    let header = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: headerSize,
                        elementKind: Self.networkHeaderElementKind,
                        alignment: .top
                    )
                    boundaryItems.append(header)
                }
                if hasFooter {
                    let footerSize = NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(68)
                    )
                    let footer = NSCollectionLayoutBoundarySupplementaryItem(
                        layoutSize: footerSize,
                        elementKind: Self.networkFooterElementKind,
                        alignment: .bottom
                    )
                    boundaryItems.append(footer)
                }
                sectionLayout.boundarySupplementaryItems = boundaryItems
            }

            return sectionLayout
        }, configuration: configuration)

        customView.collectionView.setCollectionViewLayout(layout, animated: false)
    }

    func createDataSource() -> RampPicker.DataSource {
        let cellConfiguration = ListItemCellRegistration.registration(collectionView: customView.collectionView)

        let sectionHeaderRegistration = SectionHeaderRegistration(
            elementKind: Self.networkHeaderElementKind
        ) { [weak self] supplementaryView, _, _ in
            guard let self, let headerText else { return }
            supplementaryView.configure(model: headerText)
        }

        let sectionFooterRegistration = SectionFooterRegistration(
            elementKind: Self.networkFooterElementKind
        ) { [weak self] supplementaryView, _, _ in
            guard let self, let footerText else { return }
            supplementaryView.configure(model: TKListItemTextView.Configuration(
                text: footerText,
                color: .Text.secondary,
                textStyle: .body2,
                numberOfLines: 0,
                padding: UIEdgeInsets(top: 12, left: 0, bottom: 16, right: 0)
            ))
        }

        let dataSource = RampPicker.DataSource(collectionView: customView.collectionView) { [weak self] collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueConfiguredReusableCell(
                using: cellConfiguration,
                for: indexPath,
                item: itemIdentifier.configuration
            )
            cell.selectionAccessoryViews = (self?.showsSelectionCheckmark == true)
                ? (self?.createSelectionAccessoryViews() ?? [])
                : []

            return cell
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self else { return nil }
            if kind == Self.networkHeaderElementKind, headerText != nil {
                return collectionView.dequeueConfiguredReusableSupplementary(
                    using: sectionHeaderRegistration,
                    for: indexPath
                )
            }
            if kind == Self.networkFooterElementKind, footerText != nil {
                return collectionView.dequeueConfiguredReusableSupplementary(
                    using: sectionFooterRegistration,
                    for: indexPath
                )
            }
            return nil
        }

        return dataSource
    }

    func createSelectionAccessoryViews() -> [UIView] {
        [TKListItemAccessory.icon(TKListItemIconAccessoryView.Configuration(
            icon: .TKUIKit.Icons.Size28.donemarkOutline,
            tintColor: .Accent.blue
        )).view]
    }
}

extension RampPickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let item = snapshot.itemIdentifiers(
            inSection: snapshot.sectionIdentifiers[indexPath.section]
        )[indexPath.item]
        item.selectionHandler?()
    }
}

extension RampPickerViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        customView.searchBar.textField.resignFirstResponder()
        return true
    }
}

private extension RampPickerViewController {
    static let networkHeaderElementKind = "RampPickerNetworkHeaderElementKind"
    static let networkFooterElementKind = "RampPickerNetworkFooterElementKind"
}
