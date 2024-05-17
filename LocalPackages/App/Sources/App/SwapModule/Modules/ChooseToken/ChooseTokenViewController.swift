import UIKit
import TKUIKit

final class ChooseTokenViewController: GenericViewViewController<ChooseTokenView>, TKBottomSheetScrollContentViewController {
  
  private let viewModel: ChooseTokenViewModel
  
  init(viewModel: ChooseTokenViewModel) {
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

  // MARK: - Collection View Setup
  
  private typealias Item = TKUIListItemCell.Configuration
  private typealias DataSource = UICollectionViewDiffableDataSource<Section, Item>

  private lazy var dataSource = createDataSource()
  
  private enum Section {
    case tokens
  }
}

private extension ChooseTokenViewController {
  func setup() {
    setupCollectionLayout()
    customView.collectionView.delegate = self
    customView.collectionView.showsVerticalScrollIndicator = false

    customView.collectionView.register(
      TKUIListItemCell.self,
      forCellWithReuseIdentifier: TKUIListItemCell.reuseIdentifier
    )
  }
  
  func setupBindings() {
    viewModel.didUpdateTokens = { [weak dataSource, weak self] tokenItems in
      guard let dataSource else { return }
      var snapshot = dataSource.snapshot()
      snapshot.deleteAllItems()
      snapshot.appendSections([.tokens])
      snapshot.appendItems(tokenItems, toSection: .tokens)
      snapshot.reloadItems(tokenItems)
      dataSource.apply(snapshot)
      self?.didUpdateHeight?()
    }
  }
  
  func setupCollectionLayout() {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { sectionIndex, environment in
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
      
      return sectionLayout
    }, configuration: configuration)
    
    customView.collectionView.setCollectionViewLayout(layout, animated: false)
  }
  
  private func createDataSource() -> DataSource {
    DataSource(collectionView: customView.collectionView) { collectionView, indexPath, itemIdentifier in
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: TKUIListItemCell.reuseIdentifier,
        for: indexPath
      ) as? TKUIListItemCell
      cell?.configure(configuration: itemIdentifier)
      cell?.isFirstInSection = { return $0.item == 0 }
      cell?.isLastInSection = { [unowned collectionView] in
        let numberOfItems = collectionView.numberOfItems(inSection: $0.section)
        return $0.item == numberOfItems - 1
      }
      return cell
    }
  }
}

extension ChooseTokenViewController: UICollectionViewDelegate {

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) { }

}
