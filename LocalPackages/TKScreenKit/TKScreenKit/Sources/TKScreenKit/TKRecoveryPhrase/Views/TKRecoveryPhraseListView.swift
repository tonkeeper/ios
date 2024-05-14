import UIKit
import TKUIKit

public final class TKRecoveryPhraseListView: UIView, ConfigurableView {
  
  private let leftColumnView = TKRecoveryPhraseColumnView()
  private let rightColumnView = TKRecoveryPhraseColumnView()

  // MARK: - Init

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let columnWidth = (bounds.width - .leftPaddig - .spacing)/2
    
    let leftColumnFrame = CGRect(
      x: .leftPaddig,
      y: 0,
      width: columnWidth,
      height: bounds.height
    )
    
    let rightColumnFrame = CGRect(
      x: leftColumnFrame.maxX + .spacing,
      y: 0,
      width: columnWidth,
      height: bounds.height
    )
    
    leftColumnView.frame = leftColumnFrame
    rightColumnView.frame = rightColumnFrame
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
    
    leftColumnView.configure(model: TKRecoveryPhraseColumnView.Model(items: Array(leftWords)))
    rightColumnView.configure(model: TKRecoveryPhraseColumnView.Model(items: Array(rightWords)))
  }
}

private extension TKRecoveryPhraseListView {
  func setup() {
    addSubview(leftColumnView)
    addSubview(rightColumnView)
  }
}

private extension CGFloat {
  static let leftPaddig: CGFloat = 16
  static let spacing: CGFloat = 16
}

