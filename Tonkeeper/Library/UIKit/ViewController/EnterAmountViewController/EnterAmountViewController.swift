//
//  EnterAmountViewController.swift
//  Tonkeeper
//
//  Created by Grigory on 1.6.23..
//

import UIKit

final class EnterAmountViewController: GenericViewController<EnterAmountView> {
  
  var didChangeText: ((String?) -> Void)?
  
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
}

private extension EnterAmountViewController {
  func setup() {
    customView.amountTextField.addTarget(
      self,
      action: #selector(textDidChange(textField:)),
      for: .editingChanged
    )
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


