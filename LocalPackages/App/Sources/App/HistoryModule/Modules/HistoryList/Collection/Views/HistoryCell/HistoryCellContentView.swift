import UIKit
import TKUIKit

final class HistoryCellContentView: UIView, TKConfigurableView, ReusableView {
  var actionViews = [HistoryCellActionView]()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func sizeThatFits(_ size: CGSize) -> CGSize {
    let height = actionViews.reduce(CGFloat(0)) { partialResult, view in
      return partialResult + view.sizeThatFits(size).height
    }
    return CGSize(width: size.width, height: height)
  }
  
  public override func layoutSubviews() {
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
  
  override var intrinsicContentSize: CGSize {
    return CGSize(width: UIView.noIntrinsicMetric, height: sizeThatFits(.init(width: bounds.width, height: 0)).height)
  }
  
  struct Configuration: Hashable {
    struct Action: Hashable {
      let configuration: HistoryCellActionView.Configuration
      let action: () -> Void
      
      func hash(into hasher: inout Hasher) {
        hasher.combine(configuration)
      }
      
      static func ==(lhs: Action, rhs: Action) -> Bool {
        lhs.configuration == rhs.configuration
      }
    }
    let actions: [Action]
  }
  
  func configure(configuration: Configuration) {
    var actionViews = [HistoryCellActionView]()
    for (index, view) in self.actionViews.enumerated() {
      guard index < configuration.actions.count else {
        view.removeFromSuperview()
        continue
      }
      actionViews.append(view)
    }
    
    configuration.actions.enumerated().forEach { index, action in
      let view: HistoryCellActionView
      if index < actionViews.count {
        view = actionViews[index]
      } else {
        view = HistoryCellActionView()
        actionViews.append(view)
        addSubview(view)
      }
      view.configure(configuration: action.configuration)
      view.isSeparatorVisible = index < configuration.actions.count - 1
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
  
  func prepareForReuse() {
    actionViews.forEach { $0.prepareForReuse() }
  }
}

private extension HistoryCellContentView {
  func setup() {
    layer.masksToBounds = true
    layer.cornerRadius = 16
  }
}
