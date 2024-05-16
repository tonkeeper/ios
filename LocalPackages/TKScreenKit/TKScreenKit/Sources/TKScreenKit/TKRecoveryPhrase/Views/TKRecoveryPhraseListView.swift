import UIKit
import TKUIKit

public final class TKRecoveryPhraseListView: UIView, ConfigurableView {
  
  private var leftColumnItemViews = [TKRecoveryPhraseItemView]()
  private var rightColumnItemViews = [TKRecoveryPhraseItemView]()

  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let verticalItemsCount = max(leftColumnItemViews.count, rightColumnItemViews.count)
    let columnWidth = (bounds.width - .leftPaddig - .columnSpacing)/2
    let verticalSpacing: CGFloat = CGFloat(verticalItemsCount - 1) * .itemSpacing
    let calculatedItemHeight = (bounds.height - .topPadding - verticalSpacing) / CGFloat(verticalItemsCount)
    let itemHeight = min(calculatedItemHeight, .maximumItemHeight)
    let itemResultHeight = (leftColumnItemViews + rightColumnItemViews).map {
      $0.sizeThatFits(
        CGSize(
          width: columnWidth,
          height: itemHeight
        )
      ).height
    }.min() ?? itemHeight
    
    func layoutItems(_ items: [TKRecoveryPhraseItemView], originX: CGFloat, width: CGFloat, height: CGFloat) {
      var itemY: CGFloat = .topPadding
      for item in items {
        item.frame = CGRect(
          x: originX,
          y: itemY,
          width: columnWidth,
          height: itemResultHeight
        )
        itemY += itemResultHeight + .itemSpacing
      }
    }
    
    layoutItems(leftColumnItemViews, originX: .columnSpacing, width: columnWidth, height: itemResultHeight)
    layoutItems(rightColumnItemViews, originX: columnWidth + (.columnSpacing * 2), width: columnWidth, height: itemResultHeight)
  }

  // MARK: - ConfigurableView

  public struct Model {
    let wordModels: [TKRecoveryPhraseItemView.Model]
    
    public init(wordModels: [TKRecoveryPhraseItemView.Model]) {
      self.wordModels = wordModels
    }
  }

  public func configure(model: Model) {
    let halfIndex = Int((Float(model.wordModels.count) / 2).rounded(.up))
    let leftWords = model.wordModels[0..<halfIndex]
    let rightWords = model.wordModels[halfIndex..<model.wordModels.count]
    
    leftColumnItemViews.forEach { $0.removeFromSuperview() }
    rightColumnItemViews.forEach { $0.removeFromSuperview() }
    
    leftWords.forEach { model in
      let view = TKRecoveryPhraseItemView()
      view.configure(model: model)
      addSubview(view)
      leftColumnItemViews.append(view)
    }
    
    rightWords.forEach { model in
      let view = TKRecoveryPhraseItemView()
      view.configure(model: model)
      addSubview(view)
      rightColumnItemViews.append(view)
    }
  }
}

private extension CGFloat {
  static let topPadding: CGFloat = 16
  static let leftPaddig: CGFloat = 16
  static let columnSpacing: CGFloat = 16
  static let itemSpacing: CGFloat = 8
  static let maximumItemHeight: CGFloat = 24
}

