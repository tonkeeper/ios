import UIKit
import TKLocalize
import TKUIKit

final class SwapTokenPickerViewController: GenericViewViewController<SwapTokenPickerView>, TKBottomSheetScrollContentViewController {
  enum Item: Hashable {
    case suggested(SwapTokenPickerSuggestedCell.Model)
    case token(SwapTokenPickerCell.Model)
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .suggested(let suggested):
            hasher.combine(suggested.identifier)
        case .token(let token):
            hasher.combine(token.identifier)
        }
    }

    static func == (lhs: Item, rhs: Item) -> Bool {
        switch (lhs, rhs) {
        case (.suggested(let lhsItem), .suggested(let rhsItem)):
            return lhsItem.identifier == rhsItem.identifier
        case (.token(let lhsItem), .token(let rhsItem)):
            return lhsItem.identifier == rhsItem.identifier
        default:
            return false
        }
    }
  }
  typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>
  
  enum Section {
    case suggestedTokens
    case tokens
  }
  
  // Collection
  
  private lazy var dataSource = createDataSource()
  
  private let viewModel: SwapTokenPickerViewModel
  
  init(viewModel: SwapTokenPickerViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
    setupBindings()
    viewModel.viewDidLoad()
  }
  
  // MARK: - TKPullCardScrollableContent
  
  var scrollView: UIScrollView {
    customView.collectionView
  }
  var didUpdateHeight: (() -> Void)?
  var didUpdatePullCardHeaderItem: ((TKPullCardHeaderItem) -> Void)?
  var headerItem: TKUIKit.TKPullCardHeaderItem? {
    TKUIKit.TKPullCardHeaderItem(title: "Choose Token")
  }
  func calculateHeight(withWidth width: CGFloat) -> CGFloat {
    scrollView.contentSize.height
  }
}

private extension SwapTokenPickerViewController {
  func setup() {
    customView.collectionView.delegate = self
    customView.collectionView.register(
      TKReusableContainerView.self,
      forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
      withReuseIdentifier: TKReusableContainerView.reuseIdentifier
    )
    customView.collectionView.register(
      EmptyHeaderView.self,
      forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
      withReuseIdentifier: EmptyHeaderView.reuseIdentifier
    )
    customView.collectionView.register(
      SwapTokenPickerCell.self,
      forCellWithReuseIdentifier: SwapTokenPickerCell.reuseIdentifier
    )
    customView.collectionView.register(
      SwapTokenPickerSuggestedCell.self,
      forCellWithReuseIdentifier: SwapTokenPickerSuggestedCell.reuseIdentifier
    )
    
    setupCollectionLayout()
  }
  
  func setupBindings() {
    viewModel.didUpdateTokens = { [weak self] (tokens, suggestedTokens) in
      self?.updateTokenItems(tokens, suggestedTokens: suggestedTokens)
    }
    
    viewModel.didUpdateSelectedToken = { [weak self] index in
      self?.customView.collectionView.selectItem(
        at: IndexPath(item: index, section: 0),
        animated: false,
        scrollPosition: .centeredVertically
      )
    }
  }
  
  func setupCollectionLayout() {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, environment in

      let snapshot = self.dataSource.snapshot()
      
      switch sectionIndex {
      case 0:
        let isEmptySection = snapshot.itemIdentifiers(inSection: .suggestedTokens).isEmpty

        let item = NSCollectionLayoutItem(
          layoutSize: NSCollectionLayoutSize(
            widthDimension: .estimated(120),
            heightDimension: .absolute(isEmptySection ? 0 : 36 + 8)
          )
        )
        item.contentInsets = .init(top: 0, leading: 0, bottom: 8, trailing: 0)

        let group = NSCollectionLayoutGroup.horizontal(
          layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                             heightDimension: .absolute(isEmptySection ? 0 : 36 + 8)),
          subitems: [item]
        )

        let sectionLayout = NSCollectionLayoutSection(group: group)
        sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16)
        
        let headerSize = NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1.0),
          heightDimension: .absolute(isEmptySection ? 0 : 48)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
          layoutSize: headerSize,
          elementKind: UICollectionView.elementKindSectionHeader,
          alignment: .top
        )
        sectionLayout.boundarySupplementaryItems = [header]

        return sectionLayout
      default:
        let item = NSCollectionLayoutItem(
          layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(76)
          )
        )
        
        let group = NSCollectionLayoutGroup.vertical(
          layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                             heightDimension: .absolute(76)),
          subitems: [item]
        )

        let sectionLayout = NSCollectionLayoutSection(group: group)
        sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        
        let headerSize = NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1.0),
          heightDimension: .absolute(48)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
          layoutSize: headerSize,
          elementKind: UICollectionView.elementKindSectionHeader,
          alignment: .top
        )
        sectionLayout.boundarySupplementaryItems = [header]

        return sectionLayout
      }
    }, configuration: configuration)
    
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
  }
  
  func createDataSource() -> DataSource {
    let dataSource = DataSource(collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
      switch itemIdentifier {
      case .token(let tokenModel):
        let cell = collectionView.dequeueReusableCell(
          withReuseIdentifier: SwapTokenPickerCell.reuseIdentifier,
          for: indexPath
        ) as? SwapTokenPickerCell
        cell?.configure(model: tokenModel)
        cell?.isFirstInSection = { return $0.item == 0 }
        cell?.isLastInSection = { [unowned collectionView] in
          let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
          return $0.item == numberOfItems - 1
        }
        return cell
      case .suggested(let suggested):
        let cell = collectionView.dequeueReusableCell(
          withReuseIdentifier: SwapTokenPickerSuggestedCell.reuseIdentifier,
          for: indexPath
        ) as? SwapTokenPickerSuggestedCell
        cell?.configure(model: suggested)
        return cell
      }
    }
    
    dataSource.supplementaryViewProvider = { [weak dataSource] collectionView, kind, indexPath -> UICollectionReusableView? in
      guard let dataSource else { return nil }
      if kind == UICollectionView.elementKindSectionHeader {
        // Check if the section has any items
        let snapshot = dataSource.snapshot()
        let sectionIdentifier: Section
        switch indexPath.section {
        case 0:
          sectionIdentifier = .suggestedTokens
        case 1:
          sectionIdentifier = .tokens
        default:
          return nil
        }
        
        // Only show header if the section has items
        if snapshot.itemIdentifiers(inSection: sectionIdentifier).isEmpty {
          let emptyView = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: EmptyHeaderView.reuseIdentifier,
            for: indexPath
          )
          return emptyView
        }

        let view = collectionView.dequeueReusableSupplementaryView(
          ofKind: kind,
          withReuseIdentifier: TKReusableContainerView.reuseIdentifier,
          for: indexPath
        ) as? TKReusableContainerView
        let lbl = UILabel()
        lbl.font = TKTextStyle.label1.font
        lbl.text = indexPath.section == 0 ? TKLocales.Swap.suggested : TKLocales.Swap.other
        view?.setContentView(lbl)
        return view
      } else {
        return nil
      }
    }

    return dataSource
  }
  
  func updateTokenItems(_ tokenItems: [SwapTokenPickerCell.Model], suggestedTokens: [SwapTokenPickerSuggestedCell.Model]) {
    let tokenItemsArray = tokenItems.map({ tokenItem in
      return Item.token(tokenItem)
    })
    let suggestedItemsArray = suggestedTokens.map({ suggestedItem in
      return Item.suggested(suggestedItem)
    })
    var snapshot = dataSource.snapshot()
    snapshot.deleteAllItems()
    snapshot.appendSections([.suggestedTokens, .tokens])
    snapshot.appendItems(tokenItemsArray, toSection: .tokens)
    snapshot.reloadItems(tokenItemsArray)
    snapshot.appendItems(suggestedItemsArray, toSection: .suggestedTokens)
    snapshot.reloadItems(suggestedItemsArray)
    dataSource.apply(snapshot)
    didUpdateHeight?()
  }
}

extension SwapTokenPickerViewController: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    viewModel.didSelectItemAt(section: indexPath.section, index: indexPath.item)
  }
}

final class EmptyHeaderView: UICollectionReusableView {
  static let reuseIdentifier = "EmptyHeaderView"

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
