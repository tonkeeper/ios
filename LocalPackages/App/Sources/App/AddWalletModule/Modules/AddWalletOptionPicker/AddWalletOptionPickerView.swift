import UIKit
import TKUIKit

final class AddWalletOptionPickerView: UIView {
  let collectionView = TKUICollectionView(
    frame: .zero,
    collectionViewLayout: UICollectionViewLayout()
  )
  let titleDescriptionView: TKTitleDescriptionView = {
    let view = TKTitleDescriptionView(size: .big)
    view.padding = .titleDescriptionViewPadding
    return view
  }()

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    backgroundColor = .Background.page
    collectionView.backgroundColor = .Background.page
    
    addSubview(collectionView)
    
    collectionView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
private extension NSDirectionalEdgeInsets {
  static var titleDescriptionViewPadding: NSDirectionalEdgeInsets {
    NSDirectionalEdgeInsets(top: 0, leading: 32, bottom: 32, trailing: 32)
  }
}
