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
  
  public override func sizeThatFits(_ size: CGSize) -> CGSize {
    let wordWidth = size.width - .indexWidth - .wordLeftSpacing
    let textStyles = getTextStylesToFit(
      word: word,
      wordWidth: wordWidth,
      height: size.height
    )
    let resultSize = CGSize(width: size.width, height: textStyles.wordTextStyle.lineHeight)
    return resultSize
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    let wordWidth = bounds.width - .indexWidth - .wordLeftSpacing
    let textStyles = getTextStylesToFit(
      word: word,
      wordWidth: wordWidth,
      height: bounds.height
    )
    indexTextStyle = textStyles.indexTextStyle
    wordTextStyle = textStyles.wordTextStyle
    reconfigure()
    
    indexLabel.sizeToFit()
    wordLabel.sizeToFit()
    
    wordLabel.frame = CGRect(
      x: .indexWidth + .wordLeftSpacing,
      y: bounds.height - wordLabel.frame.height,
      width: wordWidth,
      height: wordLabel.frame.height
    )
    
    indexLabel.frame = CGRect(
      x: 0,
      y: bounds.height - indexLabel.frame.height - 1,
      width: .indexWidth,
      height: indexLabel.frame.height
    )
  }
  
  private func getTextStylesToFit(word: String,
                                  wordWidth: CGFloat,
                                  height: CGFloat) -> (wordTextStyle: TKTextStyle, indexTextStyle: TKTextStyle) {
    func isTextStyleFit(_ textStyle: TKTextStyle) -> Bool {
      let widthToFit = word.boundingRect(
        with: CGSize(
          width: .greatestFiniteMagnitude,
          height: textStyle.lineHeight
        ),
        options: .usesLineFragmentOrigin,
        attributes: textStyle.getAttributes(
          color: .clear
        ),
        context: nil
      ).width
      let isHeightFit = textStyle.lineHeight <= height
      let isWidthFit = widthToFit <= wordWidth
      return isWidthFit && isHeightFit
    }
    let textStyles: [(TKTextStyle, TKTextStyle)] = [(.body1, .body2), (.body2, .body3), (.body3, .body4)]
    let result = textStyles.first(where: { isTextStyleFit($0.0) }) ?? (.body3, .body4)
    return result
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
    setNeedsLayout()
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
