import UIKit
import TKUIKit

class HistoryEventCell: TKCollectionViewContainerCell<HistoryEventCellContentView> {
  override init(frame: CGRect) {
    super.init(frame: frame)
    isSeparatorEnabled = false
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

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
    
    invalidateIntrinsicContentSize()
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let height = actionViews.reduce(CGFloat(0)) { partialResult, view in
      return partialResult + view.sizeThatFits(size).height
      
    }
    return CGSize(width: size.width, height: height)
  }
  
  override var intrinsicContentSize: CGSize {
    return CGSize(width: UIView.noIntrinsicMetric, height: sizeThatFits(.init(width: bounds.width, height: 0)).height)
  }
  
  func prepareForReuse() {
    actionViews.forEach { $0.prepareForReuse() }
  }
  
  struct Model {
    struct Action {
      let model: HistoryEventActionView.Model
      let action: () -> Void
    }
    let actions: [Action]
  }
  
  func configure(model: Model) {
    var actionViews = [HistoryEventActionView]()
    for (index, actionView) in self.actionViews.enumerated() {
      guard index < model.actions.count else {
        actionView.removeFromSuperview()
        continue
      }
      actionViews.append(actionView)
    }
    model.actions.enumerated().forEach { index, action in
      let view: HistoryEventActionView
      if index < actionViews.count {
        view = actionViews[index]
      } else {
        view = HistoryEventActionView()
        actionViews.append(view)
        addSubview(view)
      }
      view.isSeparatorVisible = index < model.actions.count - 1
      view.configure(model: action.model)
      view.enumerateEventHandlers { action, targetAction, event, stop in
        if let action = action {
          view.removeAction(action, for: event)
        }
      }
      view.addAction(UIAction(handler: { _ in
        action.action()
      }), for: .touchUpInside)
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
