import UIKit
import TKUIKit

final class StakingAmountViewController: GenericViewViewController<StakingAmountView>, KeyboardObserving, UICollectionViewDelegate {
    private let viewModel: StakingAmountViewModel
    private let amountInputViewController = AmountInputViewController()
    
    private lazy var dataSource = createDataSource()
    private lazy var layout: UICollectionViewCompositionalLayout = {
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.scrollDirection = .vertical
        
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: { _, _ in .defaultSection },
            configuration: configuration
        )
        return layout
    }()
    
    init(viewModel: StakingAmountViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Stake"
        view.backgroundColor = .Background.page
        
        setup()
        setupBindings()
        setupViewEventsBinding()
        viewModel.viewDidLoad()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        registerForKeyboardEvents()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterFromKeyboardEvents()
    }
    
    public func keyboardWillShow(_ notification: Notification) {
        guard let animationDuration = notification.keyboardAnimationDuration,
              let keyboardHeight = notification.keyboardSize?.height else { return }
        customView.keyboardWillShow(keyboardHeight: keyboardHeight, animationDuration: animationDuration)
    }
    
    public func keyboardWillHide(_ notification: Notification) {
        guard let animationDuration = notification.keyboardAnimationDuration else { return }
        customView.keyboardWillHide(animationDuration: animationDuration)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let snapshot = dataSource.snapshot()
        let section = snapshot.sectionIdentifiers[indexPath.section]
        let item = snapshot.itemIdentifiers(inSection: section)[indexPath.item]
        switch item {
        case let model as StakingAmountOptionCell.Model:
            model.selectionHandler?()
        default:
            break
        }
    }
}

private extension StakingAmountViewController {
    func setup() {
        addChild(amountInputViewController)
        customView.embedAmountInputView(amountInputViewController.view)
        amountInputViewController.didMove(toParent: self)
        
        var maxButtonConfiguration = TKButton.Configuration.titleHeaderButtonConfiguration(category: .secondary)
        maxButtonConfiguration.backgroundColors[.selected] = .Button.primaryBackground
        maxButtonConfiguration.content.title = .plainString("MAX")
        maxButtonConfiguration.padding = .zero
        maxButtonConfiguration.action = { [weak customView, weak viewModel] in
            customView?.maxButton.isSelected.toggle()
            viewModel?.toggleMax()
        }
        customView.maxButton.configuration = maxButtonConfiguration
        
        var continueButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        continueButtonConfiguration.content.title = .plainString("Continue")
        continueButtonConfiguration.action = { [weak self] in
            self?.viewModel.didTapContinueButton()
        }
        customView.continueButton.configuration = continueButtonConfiguration
        
        customView.optionCollectionView.delegate = self
        customView.optionCollectionView.setCollectionViewLayout(layout, animated: false)
        customView.optionCollectionView.register(
            StakingAmountOptionCell.self,
            forCellWithReuseIdentifier: StakingAmountOptionCell.reuseIdentifier
        )
    }
    
    func setupBindings() {
        viewModel.didUpdateInputConvertedValue = { [weak self] text in
            self?.amountInputViewController.inputValue = text
        }
        
        viewModel.didUpdateInput = { [weak self] model in
            guard let self else { return }
            self.amountInputViewController.convertedValue = model.convertedValue
            self.amountInputViewController.inputSymbol = model.inputSymbol
            self.amountInputViewController.maximumFractionDigits = model.maximumFractionDigits
            self.amountInputViewController.isTokenPickerAvailable = false
            self.customView.remainingLabel.attributedText = model.remainingAttributedText
            self.customView.continueButton.isEnabled = model.isContinueButtonEnabled
        }
        
        viewModel.didUpdateOptions = { [weak self] section in
            guard let self else { return }
            var snapshot = self.dataSource.snapshot()
            snapshot.deleteAllItems()
            snapshot.appendSections([section])
            snapshot.appendItems(section.items, toSection: section)
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }
    
    func setupViewEventsBinding() {
        amountInputViewController.didUpdateText = { [weak viewModel] text in
            viewModel?.didEditInput(text)
        }
        
        amountInputViewController.didToggle = { [weak viewModel] in
            viewModel?.toggleInputMode()
        }
    }
}

private extension StakingAmountViewController {
    func createDataSource() -> UICollectionViewDiffableDataSource<StakingAmountOptionSection, AnyHashable> {
        let dataSource = UICollectionViewDiffableDataSource<StakingAmountOptionSection, AnyHashable>(
            collectionView: customView.optionCollectionView) { collectionView, indexPath, itemIdentifier in
                switch itemIdentifier {
                case let model as StakingAmountOptionCell.Model:
                    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StakingAmountOptionCell.reuseIdentifier, for: indexPath) as? StakingAmountOptionCell {
                        cell.configure(model: model)
                        cell.isFirstInSection = { return $0.item == 0 }
                        cell.isLastInSection = { [unowned collectionView] in
                            let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
                            return $0.item == numberOfItems - 1
                        }
                        return cell
                    }
                default: return nil
                }
                return nil
            }
        return dataSource
    }
}

private extension NSCollectionLayoutSection {
    static let defaultSection: NSCollectionLayoutSection = {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(76)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(76)
        )
        
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: groupSize,
            subitems: [item]
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0)
        
        return section
    }()
}
