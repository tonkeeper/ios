import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

final class CountryPickerViewController: GenericViewViewController<CountryPickerView>, KeyboardObserving {
    var didSelectCountry: ((SelectedCountry) -> Void)?

    // MARK: - List

    private lazy var layout = createLayout()
    private lazy var dataSource = createDataSource()

    // MARK: - State

    private var countries = [Country]() {
        didSet {
            updateList(countries: countries, locale: .current, animated: false)
        }
    }

    private var isSearching: Bool = false {
        didSet {
            updateList(countries: countries, locale: .current, animated: true)
        }
    }

    private var searchInput: String? {
        didSet {
            guard isSearching else { return }
            updateList(countries: countries, locale: .current, animated: false)
        }
    }

    // MARK: - Dependencies

    private let selectedCountry: SelectedCountry
    private let countriesProvider: CountriesProvider

    // MARK: - Init

    init(
        selectedCountry: SelectedCountry,
        countriesProvider: CountriesProvider
    ) {
        self.selectedCountry = selectedCountry
        self.countriesProvider = countriesProvider
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        customView.topBar.title = TKLocales.CountryPicker.title
        customView.topBar.button.configuration.action = { [weak self] in
            self?.dismiss(animated: true)
        }
        customView.searchBar.isCancelButtonOnEdit = true

        customView.collectionView.setCollectionViewLayout(layout, animated: false)
        customView.collectionView.allowsMultipleSelection = true
        customView.collectionView.delegate = self

        self.countries = countriesProvider.countries

        customView.searchBar.placeholder = TKLocales.CountryPicker.search
        customView.searchBar.textField.addTarget(self, action: #selector(didBeginSearch), for: .editingDidBegin)
        customView.searchBar.textField.addTarget(self, action: #selector(didEndSearch), for: .editingDidEnd)
        customView.searchBar.textField.addTarget(self, action: #selector(didEdit), for: .editingChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerForKeyboardEvents()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterFromKeyboardEvents()
    }

    func keyboardWillShow(_ notification: Notification) {
        guard let animationDuration = notification.keyboardAnimationDuration,
              let keyboardHeight = notification.keyboardSize?.height else { return }
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
            self.customView.hideTopBar()
            self.customView.collectionView.contentInset.bottom = keyboardHeight
        }
    }

    func keyboardWillHide(_ notification: Notification) {
        guard let animationDuration = notification.keyboardAnimationDuration else { return }
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveEaseInOut) {
            self.customView.showTopBar()
            self.customView.collectionView.contentInset.bottom = 0
        }
    }
}

private extension CountryPickerViewController {
    func createDataSource() -> CountryPicker.DataSource {
        let cellConfiguration = ListItemCellRegistration.registration(collectionView: customView.collectionView)
        return CountryPicker.DataSource(collectionView: customView.collectionView) { [weak self]
            collectionView,
                indexPath,
                itemIdentifier in
            let cell = collectionView.dequeueConfiguredReusableCell(
                using: cellConfiguration,
                for: indexPath,
                item: itemIdentifier.configuration
            )
            cell.selectionAccessoryViews = self?.createSelectionAccessoryViews() ?? []
            return cell
        }
    }

    func createLayout() -> UICollectionViewCompositionalLayout {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical

        return UICollectionViewCompositionalLayout(sectionProvider: { _, _ in
            let itemLayoutSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(56)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemLayoutSize)

            let groupLayoutSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(56)
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

    func updateList(countries: [Country], locale: Locale, animated: Bool) {
        var snapshot = CountryPicker.Snapshot()

        var recentSectionItems = [CountryPicker.Item]()
        var selectedItems = [CountryPicker.Item]()
        if !isSearching {
            if let regionCode = locale.regionCode,
               let auto = countries.first(with: regionCode, at: \.alpha2)
            {
                let title: String = Locale.current.localizedString(forRegionCode: auto.alpha2) ?? auto.en

                let configuration = CountryPicker.mapListItemConfiguration(
                    title: TKLocales.CountryPicker.auto,
                    caption: title,
                    emoji: auto.flag
                )
                let item = CountryPicker.Item(
                    identifier: "auto",
                    configuration: configuration,
                    selectionHandler: { [weak self] in
                        self?.didSelectCountry?(.auto)
                    }
                )
                recentSectionItems.append(item)
                if case .auto = selectedCountry {
                    selectedItems.append(item)
                }
            }

            let allItem = CountryPicker.Item(
                identifier: "all",
                configuration: CountryPicker.mapListItemConfiguration(
                    title: TKLocales.CountryPicker.allRegions,
                    caption: nil,
                    emoji: "🌍"
                ),
                selectionHandler: { [weak self] in
                    self?.didSelectCountry?(.all)
                }
            )

            recentSectionItems.append(allItem)
            if case .all = selectedCountry {
                selectedItems.append(allItem)
            }

            if case let .country(countryCode) = selectedCountry,
               let country = countries.first(with: countryCode, at: \.alpha2)
            {
                let title: String = Locale.current.localizedString(forRegionCode: country.alpha2) ?? country.en
                let recentCountry = CountryPicker.Item(
                    identifier: "countryRecent",
                    configuration: CountryPicker.mapListItemConfiguration(
                        title: title,
                        caption: nil,
                        emoji: country.flag
                    ),
                    selectionHandler: { [weak self] in
                        self?.didSelectCountry?(.country(countryCode: country.alpha2))
                    }
                )

                recentSectionItems.append(recentCountry)
                selectedItems.append(recentCountry)
            }

            snapshot.appendSections([.recent])
            snapshot.appendItems(recentSectionItems, toSection: .recent)
        }
        snapshot.appendSections([.all])
        let filteredCountries: [Country] = {
            guard isSearching else {
                return countries
            }
            if let searchInput, !searchInput.isEmpty {
                return countries.filter { country in
                    country.en.lowercased().contains(searchInput.lowercased()) || country.ru.lowercased().contains(searchInput.lowercased())
                }
            } else {
                return countries
            }
        }()

        for country in filteredCountries {
            let title: String = Locale.current.localizedString(forRegionCode: country.alpha2) ?? country.en
            let item = CountryPicker.Item(
                identifier: country.alpha2,
                configuration: CountryPicker.mapListItemConfiguration(
                    title: title,
                    caption: nil,
                    emoji: country.flag
                ),
                selectionHandler: { [weak self] in
                    self?.didSelectCountry?(.country(countryCode: country.alpha2))
                }
            )
            if case let .country(countryCode) = self.selectedCountry,
               country.alpha2 == countryCode
            {
                selectedItems.append(item)
            }
            snapshot.appendItems([item], toSection: .all)
        }

        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self, weak dataSource] in
            guard let self, let dataSource else { return }
            selectedItems
                .compactMap { dataSource.indexPath(for: $0) }
                .forEach {
                    self.customView.collectionView.selectItem(at: $0, animated: false, scrollPosition: [])
                }
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

    @objc func didBeginSearch() {
        isSearching = true
    }

    @objc func didEndSearch() {
        searchInput = nil
        customView.searchBar.textField.text = nil
        isSearching = false
    }

    @objc func didEdit() {
        searchInput = customView.searchBar.textField.text
    }
}

extension CountryPickerViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        dataSource.snapshot()
            .itemIdentifiers(inSection: dataSource.snapshot().sectionIdentifiers[indexPath.section])[indexPath.item]
            .selectionHandler?()
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        dataSource.snapshot()
            .itemIdentifiers(inSection: dataSource.snapshot().sectionIdentifiers[indexPath.section])[indexPath.item]
            .selectionHandler?()
    }
}
