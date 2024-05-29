import UIKit
import TKUIKit

final class SwapSettingsSelectorView: UIView, ConfigurableView {
    private let textFieldFormatter = SwapSettingsSelectorView.textFieldFormatter()
    
    lazy var textField: BuySellConfirmationTextField = {
        let textInputControl = TKTextInputTextFieldControl()
        textInputControl.delegate = textFieldFormatter
        textInputControl.keyboardType = .numberPad
        let textFieldInputView = BuySellConfirmationTextFieldInputView(textInputControl: textInputControl)
        let textField = BuySellConfirmationTextField(textFieldInputView: textFieldInputView)
        return textField
    }()
    
    lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    private var variants: [String] = []
    private var text = "" {
        didSet {
            if textField.text != text {
                textField.text = text
            }
            let number = Int(text) ?? 0
            didSelectNumber?(number)
            updateButtons()
        }
    }
    
    func selectNumber(number: Int) {
        text = "\(number)"
    }
    
    var didSelectNumber: ((Int) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(textField)
        addSubview(stackView)
        
        textField.didUpdateText = { [weak self] text in
            self?.text = text
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(model: Model) {
        textField.textFieldInputView.currency = model.symbol
        
        stackView.subviews.forEach { $0.removeFromSuperview() }
        stackView.arrangedSubviews.forEach { stackView.removeArrangedSubview($0) }
        
        self.variants = model.variants
        for variant in model.variants {
            let button = UIButton()
            button.backgroundColor = .Field.background
            button.layer.cornerRadius = 16.0
            button.layer.borderWidth = 1.5
            button.layer.borderColor = UIColor.clear.cgColor
            
            var buttonText = variant
            if let symbol = model.symbol {
                buttonText += " \(symbol)"
            }
            
            button.titleLabel?.font = TKTextStyle.body1.font
            button.setTitleColor(.Text.primary, for: .normal)
            button.setTitle(buttonText, for: .normal)
            
            button.addAction(.init(handler: { [weak self] _ in
                self?.text = variant
            }), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
        updateLayout(in: bounds.size)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        .init(width: size.width, height: .textFieldHeight + .padding + .stackViewHeight)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(in: bounds.size)
    }
    
    private func updateLayout(in bounds: CGSize) {
        textField.frame = .init(
            x: 0,
            y: 0,
            width: bounds.width,
            height: .textFieldHeight
        )
        
        stackView.frame = .init(
            x: 0,
            y: .textFieldHeight + .padding,
            width: bounds.width,
            height: .stackViewHeight
        )
    }
    
    private func updateButtons() {
        for index in variants.indices {
            let textAtIndex = variants[index]
            if stackView.arrangedSubviews.count > index {
                if let button = stackView.arrangedSubviews[index] as? UIButton {
                    updateButtonSelectionState(button: button, selected: textAtIndex == text)
                }
            }
        }
    }
    
    private func updateButtonSelectionState(button: UIButton, selected: Bool) {
        UIView.animate(withDuration: 0.2) {
            if selected {
                button.layer.borderColor = UIColor.Accent.blue.cgColor
            } else {
                button.layer.borderColor = UIColor.clear.cgColor
            }
        }
    }
}

extension SwapSettingsSelectorView {
    struct Model {
        let variants: [String]
        let symbol: String?
    }
}

private extension CGFloat {
    static let textFieldHeight: CGFloat = 56
    static let stackViewHeight = 56.0
    static let padding = 12.0
}

private extension SwapSettingsSelectorView {
    static func textFieldFormatter() -> SendAmountTextFieldFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.decimalSeparator = ""
        numberFormatter.maximumIntegerDigits = 1
        numberFormatter.roundingMode = .down
        let amountInputFormatController = SendAmountTextFieldFormatter(
            currencyFormatter: numberFormatter
        )
        amountInputFormatController.maximumFractionDigits = 1
        amountInputFormatController.inputFormatter.maximumIntegerCharacters = 1
        return amountInputFormatController
    }
}
