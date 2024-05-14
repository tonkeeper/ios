import UIKit
import TKUIKit

public final class TKRecoveryPhraseColumnView: UIView, ConfigurableView {
  
  private var itemViews = [TKRecoveryPhraseItemView]()
  
  public override func layoutSubviews() {
    super.layoutSubviews()

    let spacing: CGFloat = CGFloat(itemViews.count - 1) * .spacing
    let calculatedItemHeight = (bounds.height - spacing) / CGFloat(itemViews.count)
    let itemHeight = min(calculatedItemHeight, .maximumItemHeight)
    var itemY: CGFloat = 0
    for itemView in itemViews {
      itemView.frame = CGRect(
        x: 0,
        y: itemY,
        width: bounds.width,
        height: itemHeight
      )
      itemY += itemHeight + .spacing
    }
  }

  // MARK: - ConfigurableView
  
  public struct Model {
    let items: [TKRecoveryPhraseItemView.Model]
  }
  
  public func configure(model: Model) {
    itemViews.forEach { $0.removeFromSuperview() }
    model.items.forEach {
      let view = TKRecoveryPhraseItemView()
      view.configure(model: $0)
      itemViews.append(view)
      addSubview(view)
    }
  }
}

private extension CGFloat {
  static let spacing: CGFloat = 8
  static let maximumItemHeight: CGFloat = 24
}
