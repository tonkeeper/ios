import Foundation
import AnyFormatKit
import TKUIKit

final class SlippagePercentageTextFieldFormatter: NSObject {
  
  var maximumInputValue: Decimal = 50
  
  var maximumFractionDigits: Int = 0 {
    didSet {
      numberFormatter.maximumFractionDigits = maximumFractionDigits
    }
  }
  
  private let numberFormatter: NumberFormatter
  private let inputFormatter: SumTextInputFormatter
  
  init(numberFormatter: NumberFormatter) {
    self.numberFormatter = numberFormatter
    self.inputFormatter = SumTextInputFormatter(numberFormatter: numberFormatter)
    self.inputFormatter.maximumIntegerCharacters = 3
  }
  
  var groupingSeparator: String? {
    numberFormatter.groupingSeparator
  }
  
  func unformatString(_ string: String?) -> String? {
    inputFormatter.unformat(string)
  }
  
  func formatString(_ string: String?) -> String? {
    inputFormatter.format(string)
  }
}

extension SlippagePercentageTextFieldFormatter: TKTextInputTextViewFormatterDelegate {
  func textView(_ textView: TKTextInputTextViewControl, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    let currentText = textView.text ?? ""
    let inputText = text.replacingOccurrences(of: ",", with: ".")
    guard inputText != inputFormatter.decimalSeparator || !currentText.isEmpty else { return false }
    guard Set(inputText).isSubset(of: .validCharactes) else { return false }
    
    let result = inputFormatter.formatInput(
      currentText: currentText,
      range: range,
      replacementString: inputFormatter.unformat(inputText) ?? ""
    )
    
    if let decimalValue = Decimal(string: result.formattedText), decimalValue > maximumInputValue {
      return false
    }
    
    textView.inputText = result.formattedText
    textView.textViewDidChange(textView)

    return false
  }
}

private extension Set<Character> {
  static let validCharactes: Set<Character> = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", ","]
}
