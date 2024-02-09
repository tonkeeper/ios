import UIKit
import TKUIKit

class HistoryEventCell: TKCollectionViewContainerCell<HistoryEventCellContentView> {}

final class HistoryEventCellContentView: UIView, ConfigurableView, TKCollectionViewCellContentView, ReusableView {
  var padding: UIEdgeInsets = .zero
  
  var actionViews = [HistoryEventActionView]()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    var originY: CGFloat = 0
    actionViews.forEach { view in
      let size = view.sizeThatFits(CGSize(width: bounds.width, height: 0))
      view.frame.origin = CGPoint(x: 0, y: originY)
      view.frame.size = size
      originY = view.frame.maxY
    }
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let height = actionViews.reduce(CGFloat(0)) { partialResult, view in
      return partialResult + view.sizeThatFits(size).height
      
    }
    return CGSize(width: size.width, height: height)
  }
  
  func prepareForReuse() {
    actionViews.forEach { $0.prepareForReuse() }
  }
  
  struct Model {
    let actionModels: [HistoryEventActionView.Model]
  }
  
  func configure(model: Model) {
    var actionViews = [HistoryEventActionView]()
    for (index, actionView) in self.actionViews.enumerated() {
      guard index < model.actionModels.count else {
        actionView.removeFromSuperview()
        continue
      }
      actionViews.append(actionView)
    }
    model.actionModels.enumerated().forEach { index, actionView in
      let view: HistoryEventActionView
      if index < actionViews.count {
        view = actionViews[index]
      } else {
        view = HistoryEventActionView()
        actionViews.append(view)
        addSubview(view)
      }
      view.isSeparatorVisible = index < model.actionModels.count - 1
      view.configure(model: actionView)
    }
    self.actionViews = actionViews
    setNeedsLayout()
  }
}

private extension HistoryEventCellContentView {
  func setup() {
    layer.masksToBounds = true
    layer.cornerRadius = 16
  }
}
