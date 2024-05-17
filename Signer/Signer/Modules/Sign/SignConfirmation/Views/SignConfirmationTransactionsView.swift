import UIKit
import TKUIKit

final class SignConfirmationTransactionsView: UIView, ConfigurableView, ReusableView {
  var itemViews = [SignConfirmationTransactionItemView]()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let height = itemViews.reduce(CGFloat(0)) { partialResult, view in
      return partialResult + view.sizeThatFits(size).height
    }
    return CGSize(width: size.width, height: height)
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()

    var originY: CGFloat = 0
    itemViews.forEach { view in
      let size = view.sizeThatFits(CGSize(width: bounds.width, height: 0))
      view.frame.origin = CGPoint(x: 0, y: originY)
      view.frame.size = size
      originY = view.frame.maxY
    }
    
    invalidateIntrinsicContentSize()
  }
  
  override var intrinsicContentSize: CGSize {
    return CGSize(width: UIView.noIntrinsicMetric, height: sizeThatFits(.init(width: bounds.width, height: 0)).height)
  }
  
  struct Model {
    struct Action {
      let configuration: SignConfirmationTransactionItemView.Model
    }
    let actions: [Action]
  }
  
  func configure(model: Model) {
    var itemViews = [SignConfirmationTransactionItemView]()
    for (index, view) in self.itemViews.enumerated() {
      guard index < model.actions.count else {
        view.removeFromSuperview()
        continue
      }
      itemViews.append(view)
    }
    
    model.actions.enumerated().forEach { index, action in
      let view: SignConfirmationTransactionItemView
      if index < itemViews.count {
        view = itemViews[index]
      } else {
        view = SignConfirmationTransactionItemView()
        itemViews.append(view)
        addSubview(view)
      }
      view.configure(model: action.configuration)
      view.isSeparatorVisible = index < model.actions.count - 1
    }
    
    self.itemViews = itemViews
    setNeedsLayout()
  }
  
  func prepareForReuse() {
    itemViews.forEach { $0.prepareForReuse() }
  }
}

private extension SignConfirmationTransactionsView {
  func setup() {
    layer.masksToBounds = true
    layer.cornerRadius = 16
  }
}
