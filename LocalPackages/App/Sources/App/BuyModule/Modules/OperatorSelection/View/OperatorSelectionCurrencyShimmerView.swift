import UIKit
import TKUIKit
import SnapKit

final class OperatorSelectionCurrencyShimmerView: UIView, ReusableView,  TKCollectionViewSupplementaryContainerViewContentView {
  
  struct Model {}
  func configure(model: Model) {}
  
  let contentView = UIView()
  let titleShimmerView = TKShimmerView()
  let iconShimmerView = TKShimmerView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return systemLayoutSizeFitting(
      size,
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .defaultLow
    )
  }
  
  func startAnimation() {
    titleShimmerView.startAnimation()
    iconShimmerView.startAnimation()
  }
  
  private func setup() {
    addSubview(contentView)
    contentView.addSubview(titleShimmerView)
    contentView.addSubview(iconShimmerView)
    
    contentView.backgroundColor = .Background.content.withAlphaComponent(0.48)
    contentView.layer.masksToBounds = true
    contentView.layer.cornerRadius = 16
    
    contentView.snp.makeConstraints { make in
      make.top.equalToSuperview()
      make.bottom.equalToSuperview().priority(.high)
      make.leading.equalToSuperview().offset(16)
      make.trailing.equalToSuperview().offset(-16).priority(.high)
      make.height.equalTo(56)
    }
    
    titleShimmerView.snp.makeConstraints { make in
      make.centerY.equalToSuperview()
      make.leading.equalToSuperview().offset(16)
      make.width.equalTo(150)
      make.height.equalTo(24)
    }
    
    iconShimmerView.snp.makeConstraints { make in
      make.centerY.equalToSuperview()
      make.trailing.equalToSuperview().offset(-16)
      make.width.equalTo(24)
      make.height.equalTo(24)
    }
  }
}
