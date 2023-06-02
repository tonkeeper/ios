//
//  TextFieldFormatter.swift
//  Tonkeeper
//
//  Created by Grigory on 2.6.23..
//

import UIKit
import AnyFormatKit

final class TextFieldFormatController: NSObject {
  private let numberFormatter: NumberFormatter
  private let currencyFormatter: SumTextInputFormatter
  
  init(numberFormatter: NumberFormatter) {
    self.numberFormatter = numberFormatter
    self.currencyFormatter = SumTextInputFormatter(numberFormatter: numberFormatter)
    self.currencyFormatter.maximumIntegerCharacters = numberFormatter.maximumIntegerDigits
  }
  
  func getUnformattedString(_ string: String?) -> String? {
    currencyFormatter.unformat(string)
  }
  
  func getUnformattedNumber(_ string: String?) -> NSNumber? {
    currencyFormatter.unformatNumber(string)
  }
}

private extension TextFieldFormatController {
  func stringWithoutDecimalSeparator(string: String) -> String {
    string.components(separatedBy: CharacterSet(charactersIn: "0123456789").inverted).joined()
  }
  
  func notifyEditingChanged(at textField: UITextField) {
    textField.sendActions(for: .editingChanged)
    NotificationCenter.default.post(
      name: UITextField.textDidChangeNotification,
      object: textField
    )
  }
}

extension TextFieldFormatController: UITextFieldDelegate {
  func textField(_ textField: UITextField,
                 shouldChangeCharactersIn range: NSRange,
                 replacementString string: String) -> Bool {
    let currentText = textField.text ?? ""
    let onlyDigitsCurrentText = stringWithoutDecimalSeparator(string: currentText)
    print(onlyDigitsCurrentText)
    
    guard onlyDigitsCurrentText.count < .amountLimitLength || string.isEmpty else { return false }
    guard string != currencyFormatter.decimalSeparator || !currentText.isEmpty else { return false }
    
    let result = currencyFormatter.formatInput(
      currentText: currentText ?? "",
      range: range,
      replacementString: string
    )
    textField.text = result.formattedText
    textField.setCursorLocation(result.caretBeginOffset)
    notifyEditingChanged(at: textField)
    
    return false
  }
  
  func textFieldDidBeginEditing(_ textField: UITextField) {
    let offset = currencyFormatter.getCaretOffset(for: textField.text ?? "")
    textField.setCursorLocation(offset)
  }
}

private extension Int {
  static let amountLimitLength: Int = 16
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
