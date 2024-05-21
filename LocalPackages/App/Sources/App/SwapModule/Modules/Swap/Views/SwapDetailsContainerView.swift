import UIKit
import TKUIKit

final class SwapDetailsContainerView: UIView, ConfigurableView {
  
  let swapRateRow = SwapRateRow()
  let swapInfoContainerView = SwapInfoContainerView()
  
  private let detailsStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.distribution = .fill
    return stackView
  }()
  
  override var intrinsicContentSize: CGSize { sizeThatFits(bounds.size) }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let swapRateRowHeight = swapRateRow.sizeThatFits(size).height
    let swapInfoContainerHeight = swapInfoContainerView.sizeThatFits(size).height
    let height = swapRateRowHeight + swapInfoContainerHeight
    return CGSize(width: bounds.width, height: height)
  }
  
  struct Model {
    let swapRate: SwapRateRow.Model
    let infoContainer: SwapInfoContainerView.Model
  }
  
  func configure(model: Model) {
    swapRateRow.configure(model: model.swapRate)
    swapInfoContainerView.configure(model: model.infoContainer)
    
    setNeedsLayout()
    layoutIfNeeded()
  }
}

private extension SwapDetailsContainerView {
  func setup() {
    detailsStackView.addArrangedSubview(swapRateRow)
    detailsStackView.addArrangedSubview(swapInfoContainerView)
    addSubview(detailsStackView)
    
    swapRateRow.addTopDivider()
    swapInfoContainerView.addTopDivider()
    
    setupConstraints()
  }
  
  func setupConstraints() {
    detailsStackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}

extension UIView {
  class DividerView: UIView {}
  
  func addTopDivider() {
    let divider = createDivider()
    addSubview(divider)
    
    divider.snp.makeConstraints { make in
      make.left.right.top.equalTo(self)
      make.height.equalTo(Constants.separatorWidth)
    }
  }
  
  func createDivider() -> DividerView {
    let view = DividerView()
    view.backgroundColor = .Separator.common
    return view
  }
  
  func removeAllDividers() {
    for subview in subviews where subview is DividerView {
      subview.removeFromSuperview()
    }
  }
}
