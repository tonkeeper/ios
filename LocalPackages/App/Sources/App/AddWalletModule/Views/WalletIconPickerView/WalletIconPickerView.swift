import UIKit
import TKUIKit
import TKCore
import KeeperCore

final class WalletIconPickerView: UIView, ConfigurableView {
  
  var didSelectIcon: ((WalletIcon) -> Void)?
  
  lazy var collectionView: UICollectionView = {
    let collectionView = TKUICollectionView(frame: .zero, collectionViewLayout: createLayout())
    return collectionView
  }()
  
  private let topGradientView = TKGradientView(color: .Background.page, direction: .topToBottom)
  private let bottomGradientView = TKGradientView(color: .Background.page, direction: .bottomToTop)
  
  private let cellConfig = UICollectionView.CellRegistration<WalletIconPickerViewCell, WalletIcon> { cell, indexPath, itemIdentifier in
    let model: WalletIconPickerViewCell.Model
    switch itemIdentifier {
    case .emoji(let emoji):
      model = .emoji(emoji)
    case .icon(let image):
      model = .image(image.image)
    }
    
    cell.configure(model: model)
  }
  
  private var model = Model(items: [])
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
    collectionView.register(WalletIconPickerViewCell.self, forCellWithReuseIdentifier: "cell")
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let items: [WalletIcon]
  }
  
  func configure(model: Model) {
    self.model = model
    collectionView.reloadData()
  }
}

private extension WalletIconPickerView {
  func setup() {
    topGradientView.isUserInteractionEnabled = false
    bottomGradientView.isUserInteractionEnabled = false
    
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.backgroundColor = .Background.page
    collectionView.showsHorizontalScrollIndicator = false
    collectionView.showsVerticalScrollIndicator = false
    collectionView.contentInset.top = .contentTopPadding
    collectionView.contentInset.bottom = .contentBottomPadding
    
    addSubview(collectionView)
    addSubview(topGradientView)
    addSubview(bottomGradientView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    topGradientView.translatesAutoresizingMaskIntoConstraints = false
    bottomGradientView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: topAnchor),
      collectionView.leftAnchor.constraint(equalTo: leftAnchor),
      collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
      collectionView.rightAnchor.constraint(equalTo: rightAnchor),
      
      topGradientView.topAnchor.constraint(equalTo: topAnchor),
      topGradientView.leftAnchor.constraint(equalTo: leftAnchor),
      topGradientView.rightAnchor.constraint(equalTo: rightAnchor),
      topGradientView.heightAnchor.constraint(equalToConstant: .contentTopPadding * 2),
      
      bottomGradientView.bottomAnchor.constraint(equalTo: bottomAnchor),
      bottomGradientView.leftAnchor.constraint(equalTo: leftAnchor),
      bottomGradientView.rightAnchor.constraint(equalTo: rightAnchor),
      bottomGradientView.heightAnchor.constraint(equalToConstant: .contentBottomPadding),
    ])
  }
  
  func createLayout() -> UICollectionViewLayout {
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.scrollDirection = .vertical
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { section, env in
      let itemsInRow = Int(env.container.contentSize.width / .itemSide)
      let rowItemsWidth = CGFloat(itemsInRow) * .itemSide
      let spacing = (env.container.contentSize.width - rowItemsWidth) / CGFloat(itemsInRow - 1)
      
      let item = NSCollectionLayoutItem(
        layoutSize: NSCollectionLayoutSize(
          widthDimension: .absolute(.itemSide),
          heightDimension: .absolute(.itemSide)
        )
      )
    
      let group = NSCollectionLayoutGroup.horizontal(
        layoutSize: NSCollectionLayoutSize(
          widthDimension: .fractionalWidth(1.0),
          heightDimension: .absolute(.itemSide)
        ),
        subitems: [item]
      )
      group.interItemSpacing = NSCollectionLayoutSpacing.fixed(spacing)

      let section = NSCollectionLayoutSection(group: group)
      section.interGroupSpacing = spacing
      
      return section
    }, configuration: configuration)

    return layout
  }
}

extension WalletIconPickerView: UICollectionViewDataSource {
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

extension WalletIconPickerView: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView,
                      didSelectItemAt indexPath: IndexPath) {
    collectionView.scrollToItem(
      at: indexPath,
      at: .centeredVertically,
      animated: true)
    didSelectIcon?(model.items[indexPath.row])
  }
}

private extension NSCollectionLayoutSize {
  static let itemSize = NSCollectionLayoutSize(
    widthDimension: .absolute(48),
    heightDimension: .absolute(48)
  )
  
  static let groupSize = NSCollectionLayoutSize(
    widthDimension: .fractionalWidth(1.0),
    heightDimension: .absolute(48)
  )
}

private extension CGFloat {
  static let itemSide: CGFloat = 48
  static let contentTopPadding: CGFloat = 8
  static let contentBottomPadding: CGFloat = 48
}
