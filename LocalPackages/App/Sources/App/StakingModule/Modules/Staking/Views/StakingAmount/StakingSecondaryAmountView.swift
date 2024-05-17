import UIKit
import TKUIKit

final class StakingSecondaryAmountView: UIView, ConfigurableView {
  struct Model {
    let title: String
  }
  
  private lazy var label: UILabel = {
    let label = UILabel()
    label.font = .montserratSemiBold(size: 16)
    label.numberOfLines = 1
    label.textAlignment = .center
    label.textColor = .Text.secondary
    
    return label
  }()
  
  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func configure(model: Model) {
    label.attributedText =  model.title
      .withTextStyle(
        .body1,
        color: .Text.secondary,
        alignment: .center
      )
  }
}

private extension StakingSecondaryAmountView {
  func setup() {
    layer.cornerRadius = .cornerRadius
    layer.borderWidth = .borderWidth
    layer.borderColor = UIColor.Text.secondary.cgColor
    
    label.layout(in: self) {
      $0.center.equalToSuperview()
      $0.top.equalToSuperview().offset(CGFloat.padding / 2)
      $0.bottom.equalToSuperview().inset(CGFloat.padding / 2)
      $0.leading.equalToSuperview().offset(CGFloat.padding)
      $0.trailing.equalToSuperview().inset(CGFloat.padding)
    }
  }
}

private extension CGFloat {
  static let cornerRadius: CGFloat = 20
  static let borderWidth: CGFloat = 1.5
  static let padding: CGFloat = 16
}
