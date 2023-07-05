//
//  AmountInputFormatController.swift
//  Tonkeeper
//
//  Created by Grigory on 5.7.23..
//

import UIKit
import AnyFormatKit

final class AmountInputFormatController: NSObject {
  private let currencyFormatter: NumberFormatter
  private let inputFormatter: SumTextInputFormatter
  
  init(currencyFormatter: NumberFormatter) {
    self.currencyFormatter = currencyFormatter
    self.inputFormatter = SumTextInputFormatter(numberFormatter: currencyFormatter)
    self.inputFormatter.maximumIntegerCharacters = .maximumIntegerDigits
  }
  
  func getUnformattedString(_ string: String?) -> String? {
    inputFormatter.unformat(string)
  }
}

private extension AmountInputFormatController {
  func notifyEditingChanged(at textField: UITextField) {
    textField.sendActions(for: .editingChanged)
    NotificationCenter.default.post(
      name: UITextField.textDidChangeNotification,
      object: textField
    )
  }
}

extension AmountInputFormatController: UITextFieldDelegate {
  func textField(_ textField: UITextField,
                 shouldChangeCharactersIn range: NSRange,
                 replacementString string: String) -> Bool {
    let currentText = textField.text ?? ""
    guard string != inputFormatter.decimalSeparator || !currentText.isEmpty else { return false }
    
    let result = inputFormatter.formatInput(
      currentText: currentText,
      range: range,
      replacementString: string
    )
    
    textField.text = result.formattedText
    textField.setCursorLocation(result.caretBeginOffset)
    notifyEditingChanged(at: textField)
    return false
  }
}

private extension Int {
  static let maximumIntegerDigits = 16
}

private extension UITextField {
  func setCursorLocation(_ location: Int) {
    guard let cursorLocation = position(from: beginningOfDocument, offset: location) else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.selectedTextRange = self.textRange(from: cursorLocation, to: cursorLocation)
    }
  }
}
