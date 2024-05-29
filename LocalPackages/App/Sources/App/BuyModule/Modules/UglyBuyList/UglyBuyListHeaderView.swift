import UIKit
import TKUIKit
import SnapKit

final class UglyBuyListHeaderView: UICollectionReusableView, ReusableView {
  
  let label = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

private extension UglyBuyListHeaderView {
  func setup() {
    label.font = .systemFont(ofSize: 14, weight: .regular)
    label.textColor = .Text.secondary
    label.numberOfLines = 0
    label.text = """
    Buy and sell TON on licensed exchanges. These are third-party exchanges not affiliated with Tonkeeper, where you can buy and sell TON and USDT using a variety of methods. Regulatory requirements apply.
    """
    
    addSubview(label)
    label.snp.makeConstraints { make in
      make.top.equalTo(self)
      make.bottom.equalTo(self).offset(-18)
      make.left.equalTo(self).offset(16)
      make.right.equalTo(self).offset(-72)
    }
  }
}
