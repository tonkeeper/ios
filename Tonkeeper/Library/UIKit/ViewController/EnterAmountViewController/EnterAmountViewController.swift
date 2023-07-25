//
//  EnterAmountViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 1.6.23..
//

import UIKit

final class EnterAmountViewController: GenericViewController<EnterAmountView> {
  
  var didChangeText: ((String?) -> Void)?
  var didTapTokenButton: (() -> Void)?
  
  var tokenCode: String? {
    didSet {
      customView.tokenSelectionButton.title = tokenCode
    }
  }
  
  var text: String? {
    customView.amountTextField.text
  }

  var formatController: AmountInputFormatController? {
    didSet {
      customView.amountTextField.delegate = formatController
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setup()
  }
  
  @discardableResult
  override func becomeFirstResponder() -> Bool {
    super.becomeFirstResponder()
    return customView.amountTextField.becomeFirstResponder()
  }
  
  func updatePrimaryCurrencyValue(_ value: String?,
                                  currencyCode: String?) {
    customView.amountTextField.text = value
    customView.currencyLabel.text = currencyCode
    updateFontsToFit()
  }
  
  func updateSecondaryCurrencyButtonTitle(_ title: String?) {
    UIView.performWithoutAnimation {
      self.customView.secondaryCurrencyButton.setTitle(title, for: .normal)
      self.customView.secondaryCurrencyButton.layoutIfNeeded()
    }
  }
  
  func setInput(_ input: String) {
    guard let selectedRange = customView.amountTextField.selectedTextRange else { return }
    
    let selectionStart = customView.amountTextField.offset(from: customView.amountTextField.beginningOfDocument, to: selectedRange.start)
    let selectionEnd = customView.amountTextField.offset(from: customView.amountTextField.beginningOfDocument, to: selectedRange.end)
    
    let currentText = customView.amountTextField.text ?? ""
    
    let startIndex = currentText.startIndex
    let selectionStartIndex = currentText.index(startIndex, offsetBy: selectionStart)
    let selectionEndIndex = currentText.index(startIndex, offsetBy: selectionEnd)
  
    var result = currentText
    result.replaceSubrange(selectionStartIndex..<selectionEndIndex, with: input)
    result = formatController?.unformatString(result) ?? ""
    result = formatController?.formatString(result) ?? ""
    
    customView.amountTextField.text = result
    if let newPosition = customView.amountTextField.position(from: customView.amountTextField.beginningOfDocument, offset: selectionEnd + result.count - currentText.count) {
      customView.amountTextField.selectedTextRange = customView.amountTextField.textRange(from: newPosition, to: newPosition)
    }
    
    updateFontsToFit()
    didChangeText?(customView.amountTextField.text)
  }
  
  func deleteBackward() {
    let textField = customView.amountTextField
    let currentText = textField.text ?? ""
    guard !currentText.isEmpty,
          let selectedRange = textField.selectedTextRange else { return }
    
    let selectionStart = textField.offset(from: textField.beginningOfDocument, to: selectedRange.start)
    let selectionEnd = textField.offset(from: textField.beginningOfDocument, to: selectedRange.end)
    
    guard selectionStart > 0 || (selectionEnd - selectionStart) > 0 else { return }
    
    var result = currentText
    
    let startIndex = currentText.startIndex
    let selectionStartIndex = currentText.index(startIndex, offsetBy: selectionStart)
    let selectionEndIndex = currentText.index(startIndex, offsetBy: selectionEnd)
    
    if selectionEnd - selectionStart > 0 {
      result.replaceSubrange(selectionStartIndex..<selectionEndIndex, with: "")
    } else {
      var deleteCharIndex = currentText.index(before: selectionStartIndex)
      let deleteChar = currentText[deleteCharIndex..<selectionStartIndex]
      if deleteChar == (formatController?.groupingSeparator ?? " ") {
        deleteCharIndex = currentText.index(before: deleteCharIndex)
      }
      result.replaceSubrange(deleteCharIndex..<selectionStartIndex, with: "")
    }
    
    result = formatController?.unformatString(result) ?? ""
    result = formatController?.formatString(result) ?? ""
    
    customView.amountTextField.text = result
    let newCursorPositionOffset = selectionStart - (currentText.count - result.count)
    if let newPosition = textField.position(from: textField.beginningOfDocument, offset: newCursorPositionOffset) {
      textField.selectedTextRange = textField.textRange(from: newPosition, to: newPosition)
    }

    updateFontsToFit()
    didChangeText?(result)
  }
}

private extension EnterAmountViewController {
  func setup() {
    customView.amountTextField.addTarget(
      self,
      action: #selector(textDidChange(textField:)),
      for: .editingChanged
    )
  
    customView.amountTextField.inputView = UIView()
    customView.tokenSelectionButton.addAction(.init(handler: { [weak self] in
      self?.didTapTokenButton?()
    }), for: .touchUpInside)
  }
  
  @objc
  func textDidChange(textField: UITextField) {
    updateFontsToFit()
    didChangeText?(textField.text)
  }
  
  func updateFontsToFit() {
    guard customView.amountWidthLimit > 0 else { return }
    let amountString = customView.amountTextField.text ?? ""
    let currencyCodeString = customView.currencyLabel.text ?? ""
    let amountWidth = amountString.width(font: EnterAmountView.amountTextStyle.font)
    let currencyCodeWidth = currencyCodeString.width(font: EnterAmountView.currencyCodeTextStyle.font)
    
    if amountWidth + currencyCodeWidth + EnterAmountView.amountCurrencyCodeSpace >= customView.amountWidthLimit {
      let amountSmallerFont = makeSmallerFont(
        EnterAmountView.amountTextStyle.font,
        string: amountString,
        width: customView.amountWidthLimit - currencyCodeWidth - EnterAmountView.amountCurrencyCodeSpace)
      let fontDelta = EnterAmountView.amountTextStyle.font.pointSize - amountSmallerFont.pointSize
      let currencyCodeSmallerFont = EnterAmountView.currencyCodeTextStyle.font.withSize(EnterAmountView.currencyCodeTextStyle.font.pointSize - fontDelta)
      customView.amountTextField.font = amountSmallerFont
      customView.currencyLabel.font = currencyCodeSmallerFont
    } else {
      customView.amountTextField.font = EnterAmountView.amountTextStyle.font
      customView.currencyLabel.font = EnterAmountView.currencyCodeTextStyle.font
    }
  }
  
  func makeSmallerFont(_ font: UIFont, string: String, width: CGFloat) -> UIFont {
    let smallerFont = font.withSize(font.pointSize - 1)
    let stringWidth = string.width(font: smallerFont)
    if stringWidth >= width {
      return makeSmallerFont(smallerFont, string: string, width: width)
    } else {
      return smallerFont
    }
  }
}

extension String {
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


