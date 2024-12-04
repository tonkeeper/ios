import UIKit
import TKUIKit

public final class AccountEventCellContentView: UIView, ConfigurableView, ReusableView {
  var actionViews = [AccountEventCellActionView]()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
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
  
  public override var intrinsicContentSize: CGSize {
    return CGSize(width: UIView.noIntrinsicMetric, height: sizeThatFits(.init(width: bounds.width, height: 0)).height)
  }
  
  public struct Model {
    public struct Action {
      public let configuration: AccountEventCellActionView.Model
      public let action: () -> Void
      public init(configuration: AccountEventCellActionView.Model, action: @escaping () -> Void) {
        self.configuration = configuration
        self.action = action
      }
    }
    public let actions: [Action]
    public init(actions: [Action]) {
      self.actions = actions
    }
  }
  
  public func configure(model: Model) {
    var actionViews = [AccountEventCellActionView]()
    for (index, view) in self.actionViews.enumerated() {
      guard index < model.actions.count else {
        view.removeFromSuperview()
        continue
      }
      actionViews.append(view)
    }
    
    model.actions.enumerated().forEach { index, action in
      let view: AccountEventCellActionView
      if index < actionViews.count {
        view = actionViews[index]
      } else {
        view = AccountEventCellActionView()
        actionViews.append(view)
        addSubview(view)
      }
      view.configure(model: action.configuration)
      view.isSeparatorVisible = index < model.actions.count - 1
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
  
  public func prepareForReuse() {
    actionViews.forEach { $0.prepareForReuse() }
  }
}

private extension AccountEventCellContentView {
  func setup() {
    layer.masksToBounds = true
    layer.cornerRadius = 16
  }
}
