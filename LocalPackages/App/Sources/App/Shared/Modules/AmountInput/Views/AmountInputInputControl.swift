import UIKit
import TKUIKit

final class AmountInputInputControl: UIControl {
  
  struct Configuration {
    let symbolViewConfiguration: AmountInputSymbolView.Configuration
  }
  
  var configuration: Configuration? {
    didSet {
      didUpdateConfiguration()
      setNeedsLayout()
      invalidateIntrinsicContentSize()
    }
  }

  private let containerView = TKPassthroughView()
  let inputTextField: UITextField = {
    let textField = UITextField()
    textField.font = .inputFont
    textField.textColor = .Text.primary
    textField.textAlignment = .right
    textField.keyboardType = .decimalPad
    textField.tintColor = .Accent.blue
    return textField
  }()
  private let symbolView = AmountInputSymbolView()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    inputTextField.sizeToFit()
    symbolView.sizeToFit()
    
    symbolView.frame.origin.x = inputTextField.frame.maxX + .symbolOffset
    symbolView.frame.origin.y = inputTextField.frame.height/2 - symbolView.frame.height/2
    
    let containerViewSize = CGSize(width: inputTextField.frame.width + symbolView.frame.width + .symbolOffset,
                                   height: inputTextField.frame.height)
    containerView.frame = CGRect(origin: CGPoint(x: bounds.width/2 - containerViewSize.width/2,
                                                 y: bounds.height/2 - containerViewSize.height/2),
                                 size: containerViewSize)
  }
  
  func setInputValue(string: String?) {
    inputTextField.text = string
    updateSizeIfNeeded()
  }
  
  private func setup() {
    inputTextField.addAction(UIAction(handler: { [weak self] _ in
      self?.didEditText()
    }), for: .editingChanged)
    
    addAction(UIAction(handler: { [weak self] _ in
      self?.inputTextField.becomeFirstResponder()
    }), for: .touchUpInside)

    symbolView.isUserInteractionEnabled = false
    
    addSubview(containerView)
    containerView.addSubview(inputTextField)
    containerView.addSubview(symbolView)
  }
  
  private func didUpdateConfiguration() {
    guard let configuration else {
      symbolView.configuration = nil
      return
    }
    
    symbolView.configuration = configuration.symbolViewConfiguration
  }
  
  func didEditText() {
    updateSizeIfNeeded()
  }
  
  func updateSizeIfNeeded() {
    guard bounds.width > 0 else { return }
    let width = bounds.width - symbolView.bounds.width - .symbolOffset
    let font = calculateFontToFit(font: .inputFont, string: inputTextField.text ?? "", targetWidth: width)
    let aspect = font.pointSize / UIFont.inputFont.pointSize
    
    inputTextField.font = font
    symbolView.transform = CGAffineTransform(scaleX: aspect, y: aspect)
    setNeedsLayout()
  }
  
  func calculateFontToFit(font: UIFont, string: String, targetWidth: CGFloat) -> UIFont {
    let fontWidth = string.width(font: font)
    if fontWidth < targetWidth {
      return font
    }
    let suggestFont = font.withSize(font.pointSize - 1)
    let width = string.width(font: suggestFont)
    if width >= targetWidth {
      return calculateFontToFit(font: suggestFont, string: string, targetWidth: targetWidth)
    } else {
      return suggestFont
    }
  }
}

private extension String {
  func width(font: UIFont) -> CGFloat {
    let constraintRect = CGSize(width: .greatestFiniteMagnitude,
                                height: font.pointSize)
    let boundingBox = self.boundingRect(with: constraintRect,
                                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                                        attributes: [.font: font],
                                        context: nil)
    
    return ceil(boundingBox.width)
  }
}

private extension CGFloat {
  static let symbolOffset: CGFloat = 4
}

private extension UIFont {
  static var inputFont: UIFont {
    UIFont.montserratSemiBold(size: 40)
  }
}
