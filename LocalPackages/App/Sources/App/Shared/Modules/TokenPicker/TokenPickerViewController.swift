import TKLocalize
import TKUIKit
import UIKit

final class TokenPickerViewController: GenericViewViewController<TokenPickerView>, TKBottomSheetScrollContentViewController {
    private lazy var dataSource = createDataSource()

    private let viewModel: TokenPickerViewModel

    init(viewModel: TokenPickerViewModel) {
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

    // MARK: - TKPullCardScrollableContent

    var scrollView: UIScrollView {
        customView.collectionView
    }

    var didUpdateHeight: (() -> Void)?
    var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
    var headerItem: TKUIKit.TKPullCardHeaderItem? {
        TKUIKit.TKPullCardHeaderItem(title: .title(title: TKLocales.TokensPicker.title))
    }

    func calculateHeight(withWidth width: CGFloat) -> CGFloat {
        view.bounds.height
    }

    @objc
    private func searchTextChanged() {
        let text = customView.searchBar.textField.text ?? ""
        viewModel.search(text: text)
    }
}

private extension TokenPickerViewController {
    func setup() {
        customView.collectionView.delegate = self
        customView.searchBar.textField.returnKeyType = .search
        customView.searchBar.textField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        customView.searchBar.textField.delegate = self

        setupCollectionLayout()
    }

    func setupBindings() {
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
            didUpdateHeight?()
        }

        viewModel.didUpdateSelectedToken = { [weak self] index, isScroll in
            guard let index else { return }

            self?.customView.collectionView.selectItem(
                at: IndexPath(item: index, section: 0),
                animated: false,
                scrollPosition: isScroll ? [.centeredVertically] : []
            )
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

        let layout = UICollectionViewCompositionalLayout(sectionProvider: { _, _ in
            let item = NSCollectionLayoutItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(76)
                )
            )

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(76)
                ),
                subitems: [item]
            )

            let sectionLayout = NSCollectionLayoutSection(group: group)
            sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

            return sectionLayout
        }, configuration: configuration)

        customView.collectionView.setCollectionViewLayout(layout, animated: false)
    }

    func createDataSource() -> TokenPicker.DataSource {
        let tokenCellConfiguration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
        return TokenPicker.DataSource(collectionView: customView.collectionView) { [weak self] collectionView, indexPath, itemIdentifier in
            let cell = collectionView.dequeueConfiguredReusableCell(
                using: tokenCellConfiguration,
                for: indexPath,
                item: itemIdentifier.configuration
            )
            cell.selectionAccessoryViews = self?.createSelectionAccessoryViews() ?? []

            return cell
        }
    }

    func createSelectionAccessoryViews() -> [UIView] {
        var configuration = TKButton.Configuration.accentButtonConfiguration(padding: .zero)
        configuration.contentPadding.right = 16
        configuration.iconTintColor = .Accent.blue
        configuration.content.icon = .TKUIKit.Icons.Size28.donemarkOutline
        let button = TKButton(configuration: configuration)
        button.isUserInteractionEnabled = false
        return [button]
    }
}

extension TokenPickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let item = snapshot.itemIdentifiers(
            inSection: snapshot.sectionIdentifiers[indexPath.section]
        )[indexPath.item]
        item.selectionHandler?()
    }
}

extension TokenPickerViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        customView.searchBar.textField.resignFirstResponder()
        return true
    }
}
