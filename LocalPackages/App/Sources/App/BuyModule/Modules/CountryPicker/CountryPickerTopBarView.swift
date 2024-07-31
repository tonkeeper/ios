import UIKit
import TKUIKit

final class CountryPickerTopBarView: UIView {
  
  var title: String? {
    didSet {
      titleLabel.attributedText = title?.withTextStyle(
        .h3,
        color: .Text.primary,
        alignment: .center,
        lineBreakMode: .byTruncatingTail
      )
    }
  }
  
  let titleLabel = UILabel()
  let button: TKButton = {
    var configuration = TKButton.Configuration.iconHeaderButtonConfiguration()
    configuration.content = TKButton.Configuration.Content(icon: .TKUIKit.Icons.Size16.close)
    return TKButton(configuration: configuration)
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: 64)
  }
  
  private func setup() {
    backgroundColor = .Background.page
    
    addSubview(titleLabel)
    addSubview(button)
    
    button.snp.makeConstraints { make in
      make.right.equalTo(self).offset(-8)
      make.centerY.equalTo(self)
    }
    
    titleLabel.snp.makeConstraints { make in
      make.centerX.equalTo(self)
      make.centerY.equalTo(self)
      make.right.lessThanOrEqualTo(button.snp.left).offset(-8)
      make.left.greaterThanOrEqualTo(self).offset(8)
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
