import UIKit
import TKUIKit

public final class TKRecoveryPhraseItemView: UIView, ConfigurableView {
  private let indexLabel = UILabel()
  private let wordLabel = UILabel()
  
  private var word = ""
  private var index = 0
  private var indexTextStyle: TKTextStyle = .body2
  private var wordTextStyle: TKTextStyle = .body1
  
  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let textStyles = getFittedTextStyles()
    indexTextStyle = textStyles.indexTextStyle
    wordTextStyle = textStyles.wordTextStyle
    reconfigure()
    
    indexLabel.sizeToFit()
    wordLabel.sizeToFit()
    
    indexLabel.frame = CGRect(
      x: 0,
      y: bounds.height - indexLabel.bounds.height - 2,
      width: .indexWidth,
      height: indexLabel.frame.height
    )
    wordLabel.frame = CGRect(
      x: .indexWidth + .wordLeftSpacing,
      y: 0,
      width: bounds.width - indexLabel.frame.width - .wordLeftSpacing,
      height: bounds.height
    )
  }
  
  private func getFittedTextStyles() -> (wordTextStyle: TKTextStyle, indexTextStyle: TKTextStyle) {
    func isTextStyleFit(_ textStyle: TKTextStyle) -> Bool {
      textStyle.lineHeight <= bounds.height
    }
    let textStyles: [(TKTextStyle, TKTextStyle)] = [(.body1, .body2), (.body2, .body3), (.body3, .body4)]
    guard let firstFitted = textStyles.first(where: { $0.0.lineHeight <= bounds.height } ) else {
      return (.body3, .body4)
    }
    return firstFitted
  }
  
  // MARK: - ConfigurableView
  
  public struct Model {
    let index: Int
    let word: String
    
    public init(index: Int, word: String) {
      self.index = index
      self.word = word
    }
  }
  
  public func configure(model: Model) {
    self.index = model.index
    self.word = model.word
    reconfigure()
  }
}

private extension TKRecoveryPhraseItemView {
  func setup() {
    addSubview(indexLabel)
    addSubview(wordLabel)
  }
  
  func reconfigure() {
    indexLabel.attributedText = "\(index)."
      .withTextStyle(
        indexTextStyle,
        color: .Text.secondary,
        alignment: .left
      )
    wordLabel.attributedText = word
      .withTextStyle(
        wordTextStyle,
        color: .Text.primary,
        alignment: .left
      )
  }
}

private extension CGFloat {
  static let indexWidth: CGFloat = 24
  static let wordLeftSpacing: CGFloat = 4
}
