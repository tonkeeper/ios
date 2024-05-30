import UIKit
import AnyFormatKit

final class SendAmountTextFieldFormatter: NSObject {
  
  var maximumFractionDigits: Int = 0 {
    didSet {
      currencyFormatter.maximumFractionDigits = maximumFractionDigits
    }
  }
  
  let currencyFormatter: NumberFormatter
  let inputFormatter: SumTextInputFormatter
  
  init(currencyFormatter: NumberFormatter) {
    self.currencyFormatter = currencyFormatter
    self.inputFormatter = SumTextInputFormatter(numberFormatter: currencyFormatter)
    self.inputFormatter.maximumIntegerCharacters = .maximumIntegerDigits
  }
  
  var groupingSeparator: String? {
    currencyFormatter.groupingSeparator
  }
  
  func unformatString(_ string: String?) -> String? {
    inputFormatter.unformat(string)
  }
  
  func formatString(_ string: String?) -> String? {
    inputFormatter.format(string)
  }
}

private extension SendAmountTextFieldFormatter {
  func notifyEditingChanged(at textField: UITextField) {
    textField.sendActions(for: .editingChanged)
    NotificationCenter.default.post(
      name: UITextField.textDidChangeNotification,
      object: textField
    )
  }
}

extension SendAmountTextFieldFormatter: UITextFieldDelegate {
  func textField(_ textField: UITextField,
                 shouldChangeCharactersIn range: NSRange,
                 replacementString string: String) -> Bool {
    let currentText = textField.text ?? ""
    guard string != inputFormatter.decimalSeparator || !currentText.isEmpty else { return false }
    guard Set(string).isSubset(of: .validCharactes) else { return false }
    
    let result = inputFormatter.formatInput(
      currentText: currentText,
      range: range,
      replacementString: inputFormatter.unformat(string) ?? ""
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

private extension Set<Character> {
  static let validCharactes: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", ",", " "]
}
