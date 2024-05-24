import UIKit
import TKUIKit
import AnyFormatKit
import KeeperCore

final class InputAmountTextFieldFormatter: NSObject {
  
  private let groupingSeparator = FormattersConstants.groupingSeparator
  private let fractionalSeparator = FormattersConstants.fractionalSeparator
  
  var maximumFractionDigits: Int = 0 {
    didSet {
      numberFormatter.maximumFractionDigits = maximumFractionDigits
    }
  }
  
  private let numberFormatter: NumberFormatter
  private let inputFormatter: SumTextInputFormatter
  
  override init() {
    self.numberFormatter = .createInputAmountNumberFormatter()
    self.inputFormatter = SumTextInputFormatter(numberFormatter: numberFormatter)
    self.inputFormatter.maximumIntegerCharacters = numberFormatter.maximumIntegerDigits
  }
  
  func unformatString(_ string: String?) -> String? {
    inputFormatter.unformat(string)
  }
  
  func formatString(_ string: String?) -> String? {
    inputFormatter.format(string)
  }
}

private extension InputAmountTextFieldFormatter {
  func notifyEditingChanged(at textField: UITextField) {
    textField.sendActions(for: .editingChanged)
    NotificationCenter.default.post(
      name: UITextField.textDidChangeNotification,
      object: textField
    )
  }
}

extension InputAmountTextFieldFormatter: UITextFieldDelegate {
  func textField(_ textField: UITextField,
                 shouldChangeCharactersIn range: NSRange,
                 replacementString string: String) -> Bool {
    let currentText = textField.text ?? ""
    let inputText = string
      .replacingOccurrences(of: ",", with: fractionalSeparator)
      .replacingOccurrences(of: ".", with: fractionalSeparator)
    guard inputText != inputFormatter.decimalSeparator || !currentText.isEmpty else { return false }
    guard Set(inputText).isSubset(of: .validCharactes) else { return false }
    
    let result = inputFormatter.formatInput(
      currentText: currentText,
      range: range,
      replacementString: inputFormatter.unformat(inputText) ?? ""
    )
    
    textField.text = result.formattedText
    textField.setCursorLocation(result.caretBeginOffset)
    notifyEditingChanged(at: textField)
    return false
  }
}

extension InputAmountTextFieldFormatter: TKTextInputTextViewFormatterDelegate {
  func textView(_ textView: TKTextInputTextViewControl, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    let currentText = textView.text ?? ""
    let inputText = text
      .replacingOccurrences(of: ",", with: fractionalSeparator)
      .replacingOccurrences(of: ".", with: fractionalSeparator)
    guard inputText != inputFormatter.decimalSeparator || !currentText.isEmpty else { return false }
    guard Set(inputText).isSubset(of: .validCharactes) else { return false }
    
    let result = inputFormatter.formatInput(
      currentText: currentText,
      range: range,
      replacementString: inputFormatter.unformat(inputText) ?? ""
    )
    
    textView.inputText = result.formattedText
    textView.textViewDidChange(textView)
    return false
  }
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

private extension NumberFormatter {
  static func createInputAmountNumberFormatter() -> NumberFormatter {
    let numberFormatter = NumberFormatter()
    numberFormatter.groupingSize = 3
    numberFormatter.usesGroupingSeparator = true
    numberFormatter.groupingSeparator = FormattersConstants.groupingSeparator
    numberFormatter.decimalSeparator = FormattersConstants.fractionalSeparator
    numberFormatter.maximumIntegerDigits = 16
    numberFormatter.roundingMode = .down
    return numberFormatter
  }
}

private extension Set<Character> {
  static let validCharactes: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", ","]
}
