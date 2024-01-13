import UIKit
import TKUIKit

final class WalletColorPickerView: UIView, ConfigurableView {
  lazy var collectionView: UICollectionView = {
    let collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
    return collectionView
  }()
  
  var model = Model(items: [], initialSelectedIdentifier: nil)
  
  private let cellConfig = UICollectionView.CellRegistration<WalletColorPickerViewCell, Model.ColorItem> { cell, indexPath, itemIdentifier in
    cell.configure(model: itemIdentifier)
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 68)
  }
  
  struct Model {
    struct ColorItem {
      let identifier: String
      let selectHandler: (() -> Void)?
    }
    let items: [ColorItem]
    let initialSelectedIdentifier: String?
  }
  
  func configure(model: Model) {
    self.model = model
    collectionView.reloadData()
    if let initialSelectedIdentifier = model.initialSelectedIdentifier,
       let selectedIndex = model.items.firstIndex(where: { $0.identifier == initialSelectedIdentifier }) {
      collectionView.selectItem(
        at: IndexPath(item: selectedIndex, section: 0),
        animated: false,
        scrollPosition: .centeredHorizontally)
    }
  }
}

private extension WalletColorPickerView {
  func setup() {
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.backgroundColor = .Background.page
    collectionView.showsHorizontalScrollIndicator = false
    
    addSubview(collectionView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: topAnchor),
      collectionView.leftAnchor.constraint(equalTo: leftAnchor),
      collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
      collectionView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
  
  func createLayout() -> UICollectionViewLayout {
    let item = NSCollectionLayoutItem(
      layoutSize: .itemSize
    )
  
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: .groupSize,
      subitems: [item]
    )

    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = 12
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .horizontal
    
    let layout = UICollectionViewCompositionalLayout(
      section: section,
      configuration: configuration
    )
    
    return layout
  }
}

extension WalletColorPickerView: UICollectionViewDataSource {
  func collectionView(_ collectionView: UICollectionView, 
                      numberOfItemsInSection section: Int) -> Int {
    return model.items.count
  }
  
  func collectionView(_ collectionView: UICollectionView, 
                      cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let model = model.items[indexPath.row]
    return collectionView.dequeueConfiguredReusableCell(
      using: cellConfig,
      for: indexPath,
      item: model
    )
  }
}

extension WalletColorPickerView: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, 
                      didSelectItemAt indexPath: IndexPath) {
    let model = model.items[indexPath.row]
    model.selectHandler?()
    collectionView.scrollToItem(
      at: indexPath,
      at: .centeredHorizontally,
      animated: true
    )
  }
}

private extension NSCollectionLayoutSize {
  static let itemSize = NSCollectionLayoutSize(
    widthDimension: .absolute(36),
    heightDimension: .fractionalHeight(1.0)
  )
  
  static let groupSize = NSCollectionLayoutSize(
    widthDimension: .absolute(36),
    heightDimension: .fractionalHeight(1.0)
  )
}
