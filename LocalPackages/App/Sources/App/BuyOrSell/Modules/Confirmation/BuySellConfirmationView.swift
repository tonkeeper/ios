import UIKit
import TKUIKit

final class BuySellConfirmationView: UIView, ConfigurableView, UITextFieldDelegate {
    lazy var inputFormatter = Self.textFieldFormatter()
    lazy var convertedFormatter = Self.textFieldFormatter()

    lazy var imageView = BuySellConfirmationImageView()
    lazy var titleView = TKTitleDescriptionView(size: .big)
        
    lazy var inputTextField: BuySellConfirmationTextField = {
        let textInputControl = TKTextInputTextFieldControl()
        textInputControl.delegate = inputFormatter
        textInputControl.keyboardType = .decimalPad
        let textFieldInputView = BuySellConfirmationTextFieldInputView(textInputControl: textInputControl)
        textFieldInputView.placeholder = "You pay"
        let inputTextField = BuySellConfirmationTextField(textFieldInputView: textFieldInputView)
        return inputTextField
    }()
    
    lazy var convertedTextField: BuySellConfirmationTextField = {
        let textInputControl = TKTextInputTextFieldControl()
        textInputControl.delegate = convertedFormatter
        textInputControl.keyboardType = .decimalPad
        let textFieldInputView = BuySellConfirmationTextFieldInputView(textInputControl: textInputControl)
        textFieldInputView.placeholder = "You get"
        let inputTextField = BuySellConfirmationTextField(textFieldInputView: textFieldInputView)
        return inputTextField
    }()
    
    lazy var descriptionLabel = UILabel()
    lazy var footerView = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.page
        
        imageView.backgroundColor = .Background.content
        imageView.layer.cornerRadius = .imageViewCornerRadius
        imageView.contentMode = .scaleAspectFill
        addSubview(imageView)
        
        addSubview(titleView)
        
        addSubview(inputTextField)
        addSubview(convertedTextField)
        
        descriptionLabel.numberOfLines = .max
        addSubview(descriptionLabel)
        
        addSubview(footerView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(in: bounds.size)
    }
    
    func configure(model: Model) {
        imageView.configure(model: model.imageModel)
        titleView.configure(model: .init(title: model.title, bottomDescription: model.subtitle))
    }
}

private extension BuySellConfirmationView {
    func updateLayout(in bounds: CGSize) {
        let imageViewMinX = (bounds.width - .imageViewSize) / 2.0
        let imageViewMinY = safeAreaInsets.top
        
        imageView.frame = .init(
            x: imageViewMinX,
            y: imageViewMinY,
            width: .imageViewSize,
            height: .imageViewSize
        )
        
        let titleViewSize = CGSize(width: bounds.width, height: 60)
        let titleViewMinX = (bounds.width - titleViewSize.width) / 2.0
        let titleViewMinY = imageViewMinY + .imageViewSize + .titleViewTopPadding
        
        titleView.frame = .init(
            x: titleViewMinX,
            y: titleViewMinY,
            width: titleViewSize.width,
            height: titleViewSize.height
        )
        
        let inputTextFieldMinX = CGFloat.horizontalPadding
        let inputTextFieldMinY = titleViewMinY + titleViewSize.height + .inputTextFieldTopPadding
        let inputTextFieldWidth = bounds.width - 2 * .horizontalPadding
        let inputTextFieldHeight = CGFloat.inputTextFieldHeight
        
        inputTextField.frame = .init(
            x: inputTextFieldMinX,
            y: inputTextFieldMinY,
            width: inputTextFieldWidth,
            height: inputTextFieldHeight
        )
        
        let convertedTextFieldMinX = CGFloat.horizontalPadding
        let convertedTextFieldMinY = inputTextFieldMinY + inputTextFieldHeight + .convertedTextFieldTopPadding
        let convertedTextFieldWidth = bounds.width - 2 * .horizontalPadding
        let convertedTextFieldHeight = CGFloat.convertedTextFieldHeight
        
        convertedTextField.frame = .init(
            x: convertedTextFieldMinX,
            y: convertedTextFieldMinY,
            width: convertedTextFieldWidth,
            height: convertedTextFieldHeight
        )
        
        let descriptionLabelBounds = CGSize(
            width: bounds.width - 2 * .descriptionLabelHorizontalPadding,
            height: bounds.height
        )
        let descriptionLabelSize = descriptionLabel.sizeThatFits(descriptionLabelBounds)
        let descriptionLabelMinX = CGFloat.descriptionLabelHorizontalPadding
        let descriptionLabelMinY = convertedTextFieldMinY + convertedTextFieldHeight + .descriptionLabelTopPadding
        
        descriptionLabel.frame = .init(
            x: descriptionLabelMinX,
            y: descriptionLabelMinY,
            width: descriptionLabelSize.width,
            height: descriptionLabelSize.height
        )
    }
}

extension BuySellConfirmationView {
    struct Model {
        let imageModel: BuySellConfirmationImageView.Model
        let title: String
        let subtitle: String
    }
}

private extension BuySellConfirmationView {
    static func textFieldFormatter() -> SendAmountTextFieldFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.groupingSeparator = " "
        numberFormatter.groupingSize = 3
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.decimalSeparator = Locale.current.decimalSeparator
        numberFormatter.maximumIntegerDigits = 16
        numberFormatter.roundingMode = .down
        let amountInputFormatController = SendAmountTextFieldFormatter(
            currencyFormatter: numberFormatter
        )
        amountInputFormatController.maximumFractionDigits = 16
        return amountInputFormatController
    }
}

private extension CGFloat {
    static let imageViewSize = 72.0
    static let imageViewCornerRadius = 20.0
    static let titleViewTopPadding = 20.0
    static let inputTextFieldTopPadding = 32.0
    static let inputTextFieldHeight = 64.0
    static let convertedTextFieldTopPadding = 16.0
    static let convertedTextFieldHeight = 64.0
    static let descriptionLabelHorizontalPadding = 32.0
    static let descriptionLabelTopPadding = 12.0
    
    static let horizontalPadding = 16.0
}
