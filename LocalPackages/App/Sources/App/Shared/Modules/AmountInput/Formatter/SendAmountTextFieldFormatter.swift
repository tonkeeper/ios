import AnyFormatKit
import KeeperCore
import UIKit

final class SendAmountTextFieldFormatter: NSObject {
    var maximumFractionDigits: Int = 0 {
        didSet {
            currencyFormatter.maximumFractionDigits = maximumFractionDigits
        }
    }

    private let currencyFormatter: NumberFormatter
    private let inputFormatter: SumTextInputFormatter

    init(currencyFormatter: NumberFormatter) {
        self.currencyFormatter = currencyFormatter
        self.currencyFormatter.decimalSeparator = AmountFormatter.Configuration.defaultLocale.decimalSeparator ?? "."
        self.currencyFormatter.usesGroupingSeparator = false
        self.inputFormatter = SumTextInputFormatter(numberFormatter: currencyFormatter)
        self.inputFormatter.maximumIntegerCharacters = .maximumIntegerDigits
    }

    func unformatString(_ string: String?) -> String? {
        AmountInputFormatter.normalizedString(
            string,
            decimalSeparator: inputFormatter.decimalSeparator,
            interpretsLeadingZeroAsFractionalShortcut: false
        )
    }
}

private extension SendAmountTextFieldFormatter {
    var decimalSeparator: String {
        inputFormatter.decimalSeparator
    }

    func notifyEditingChanged(at textField: UITextField) {
        textField.sendActions(for: .editingChanged)
        NotificationCenter.default.post(
            name: UITextField.textDidChangeNotification,
            object: textField
        )
    }

    func normalizedInput(
        _ string: String,
        interpretsLeadingZeroAsFractionalShortcut: Bool = true
    ) -> String? {
        AmountInputFormatter.normalizedString(
            string,
            decimalSeparator: decimalSeparator,
            maximumIntegerDigits: .maximumIntegerDigits,
            maximumFractionDigits: maximumFractionDigits,
            interpretsLeadingZeroAsFractionalShortcut: interpretsLeadingZeroAsFractionalShortcut
        )
    }

    func updatedText(
        currentText: String,
        range: NSRange,
        replacementString string: String
    ) -> (text: String, caretOffset: Int)? {
        guard let textRange = Range(range, in: currentText) else { return nil }

        let prefix = String(currentText[..<textRange.lowerBound]) + string
        let rawText = currentText.replacingCharacters(in: textRange, with: string)
        let isDeleting = string.isEmpty && range.length > 0

        guard let normalizedText = normalizedInput(
            rawText,
            interpretsLeadingZeroAsFractionalShortcut: !isDeleting
        ),
            let normalizedPrefix = normalizedInput(
                prefix,
                interpretsLeadingZeroAsFractionalShortcut: !isDeleting
            )
        else {
            return nil
        }

        return (
            normalizedText,
            min(normalizedPrefix.utf16.count, normalizedText.utf16.count)
        )
    }
}

extension SendAmountTextFieldFormatter: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let currentText = textField.text ?? ""
        guard let result = updatedText(
            currentText: currentText,
            range: range,
            replacementString: string
        ) else { return false }

        textField.text = result.text
        textField.setCursorLocation(result.caretOffset)
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
