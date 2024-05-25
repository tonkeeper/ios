import UIKit
import TKUIKit
import TKLocalize

final class SwapTokenPickerView: UIView {
  let searchBar: UISearchBar = {
    let sb = UISearchBar()
    sb.placeholder = TKLocales.Swap.search
    sb.searchBarStyle = .minimal
    sb.translatesAutoresizingMaskIntoConstraints = false
    sb.tintColor = .white
    if let textField = sb.value(forKey: "searchField") as? UITextField {
      textField.textColor = .white
      textField.backgroundColor = .Field.background
      textField.layer.cornerRadius = 16
      textField.clipsToBounds = true
    }
    return sb
  }()

  let collectionView = TKUICollectionView(frame: .zero,
                                          collectionViewLayout: UICollectionViewLayout())
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension SwapTokenPickerView {
  func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    collectionView.keyboardDismissMode = .onDrag
    
    // search bar
    searchBar.placeholder = TKLocales.Swap.search
    addSubview(searchBar)

    // collection view
    addSubview(collectionView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    searchBar.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        searchBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
        searchBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
        searchBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        searchBar.heightAnchor.constraint(equalToConstant: 48)
    ])

    collectionView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
      collectionView.leftAnchor.constraint(equalTo: leftAnchor),
      collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
      collectionView.rightAnchor.constraint(equalTo: rightAnchor)
    ])
  }
}
