//import UIKit
//import TKUIKit
//
//final class WalletsListAddWalletCell: UICollectionViewCell, ConfigurableView {
//  
//  private let button = TKButton()
//
//  private let container = UIView()
//  
//  override init(frame: CGRect) {
//    super.init(frame: frame)
//    setup()
//  }
//  
//  required init?(coder: NSCoder) {
//    fatalError("init(coder:) has not been implemented")
//  }
//  
//  struct Model: Hashable {
//    let id: String
//    let configuration: TKButton.Configuration
//    let padding: UIEdgeInsets
//    
//    func hash(into hasher: inout Hasher) {
//      hasher.combine(id)
//    }
//    
//    static func ==(lhs: Model, rhs: Model) -> Bool {
//      return lhs.id == rhs.id
//    }
//  }
//  
//  func configure(model: Model) {
//    button.configuration = model.configuration
//    container.snp.remakeConstraints { make in
//      make.edges.equalTo(self).inset(model.padding)
//    }
//  }
//}
//
//private extension WalletsListAddWalletCell {
//  func setup() {
//    addSubview(container)
//    container.addSubview(button)
//    
//    container.snp.makeConstraints { make in
//      make.edges.equalTo(self)
//    }
//    
//    button.snp.makeConstraints { make in
//      make.top.bottom.equalTo(container)
//      make.centerX.equalTo(container)
//      make.left.greaterThanOrEqualTo(container)
//      make.right.lessThanOrEqualTo(container)
//    }
//  }
//}
