import UIKit
import TKUIKit

final class SwapSettingsView: UIView {
    private let customPriceTextFieldFormatter = SwapSettingsView.textFieldFormatter()
    private var saveButtonBottomConstraint: NSLayoutConstraint?
    
    lazy var navigationBarView: TKNavigationBarContainer = {
        let navigationBarView = TKNavigationBarContainer(barHeight: .navigationBarViewHeight)
        navigationBarView.contentPadding = .zero
        navigationBarView.barPadding = .init(top: 8, left: 16, bottom: 8, right: 16)
        navigationBarView.barViews = [titleView, closeButton]
        navigationBarView.backgroundColor = .Background.page
        return navigationBarView
    }()
    
    lazy var titleView = UILabel()
    
    lazy var closeButton: TKUIHeaderIconButton = {
        let v = TKUIHeaderIconButton()
        v.configure(
            model: TKUIHeaderButtonIconContentView.Model(
                image: .TKUIKit.Icons.Size16.close
            )
        )
        v.tapAreaInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        return v
    }()
    
    lazy var scrollView = UIScrollView()
    lazy var subtitleView = UILabel()
    lazy var descriptionView = UILabel()
    lazy var selectorView = SwapSettingsSelectorView()
    lazy var titleSwitchView = SwapSettingsTitleSwicthView()
    lazy var customPriceTextField: BuySellConfirmationTextField = {
        let textInputControl = TKTextInputTextFieldControl()
        textInputControl.keyboardType = .numberPad
        textInputControl.delegate = customPriceTextFieldFormatter
        let textFieldInputView = BuySellConfirmationTextFieldInputView(textInputControl: textInputControl)
        let textField = BuySellConfirmationTextField(textFieldInputView: textFieldInputView)
        return textField
    }()
    lazy var saveButton = TKButton()
    
    private var isExpertMode = false {
        didSet {
            if isExpertMode {
                didSelectNumber?(expertModeNumber)
            } else {
                didSelectNumber?(defaultModeNumber)
            }
            UIView.animate(withDuration: 0.3) {
                self.updateState()
            }
        }
    }
    
    private var defaultModeNumber = 0 {
        didSet {
            if !isExpertMode {
                didSelectNumber?(defaultModeNumber)
            }
        }
    }
    
    private var expertModeNumber = 0 {
        didSet {
            if isExpertMode {
                didSelectNumber?(expertModeNumber)
            }
        }
    }
    
    var didSelectNumber: ((Int) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .Background.page
        
        navigationBarView.scrollView = scrollView
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
        addSubview(navigationBarView)
        
        scrollView.addSubview(subtitleView)
        
        descriptionView.numberOfLines = .max
        descriptionView.lineBreakMode = .byTruncatingTail
        scrollView.addSubview(descriptionView)
        
        selectorView.didSelectNumber = { [weak self] in
            self?.defaultModeNumber = $0
        }
        scrollView.addSubview(selectorView)
        
        titleSwitchView.didSwitch = { [weak self] isOn in
            self?.endEditing(true)
            self?.isExpertMode = isOn
        }
        scrollView.addSubview(titleSwitchView)
        
        customPriceTextField.didUpdateText = { [weak self] text in
            let number = Int(text) ?? 0
            self?.expertModeNumber = number
        }
        scrollView.addSubview(customPriceTextField)
        
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(saveButton)
        let saveButtonBottomConstraint = saveButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16)
        self.saveButtonBottomConstraint = saveButtonBottomConstraint
        NSLayoutConstraint.activate([
            saveButtonBottomConstraint,
            saveButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
        
        updateState()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBarView.frame = .init(x: 0, y: 0, width: bounds.width, height: .navigationBarViewHeight)
        
        scrollView.frame = bounds
        scrollView.contentInset.top = navigationBarView.additionalInset
        scrollView.verticalScrollIndicatorInsets.top = navigationBarView.additionalInset
        
        let subtitleViewMinX = CGFloat.horizontalPadding
        let subtitleViewMinY = CGFloat.subtitleViewTopPadding
        let subtitleViewSize = subtitleView.sizeThatFits(.init(width: bounds.width - 2 * .horizontalPadding, height: bounds.height))
        
        subtitleView.frame = .init(
            x: subtitleViewMinX,
            y: subtitleViewMinY,
            width: subtitleViewSize.width,
            height: subtitleViewSize.height
        )
        
        let descriptionViewMinX = CGFloat.horizontalPadding
        let descriptionViewMinY = subtitleViewMinY + subtitleViewSize.height
        let descriptionViewSize = descriptionView.sizeThatFits(.init(width: bounds.width - 2 * .horizontalPadding, height: bounds.height))
        
        descriptionView.frame = .init(
            x: descriptionViewMinX,
            y: descriptionViewMinY,
            width: descriptionViewSize.width,
            height: descriptionViewSize.height
        )
        
        let selectorViewMinX = CGFloat.horizontalPadding
        let selectorViewMinY = descriptionViewMinY + descriptionViewSize.height + .selectorViewTopPadding
        let selectorViewSize = selectorView.sizeThatFits(bounds.size)
        
        selectorView.frame = .init(
            x: selectorViewMinX,
            y: selectorViewMinY,
            width: selectorViewSize.width - 2 * .horizontalPadding,
            height: selectorViewSize.height
        )
        
        let titleSwitchViewMinX = CGFloat.horizontalPadding
        let titleSwitchViewMinY = selectorViewMinY + selectorViewSize.height + 32.0
        let titleSwitchViewWidth = bounds.width
        
        titleSwitchView.frame = .init(
            x: titleSwitchViewMinX,
            y: titleSwitchViewMinY,
            width: titleSwitchViewWidth - 2 * .horizontalPadding,
            height: .titleSwitchViewHeight
        )
        
        let customPriceTextFieldMinX = CGFloat.horizontalPadding
        var customPriceTextFieldMinY = titleSwitchViewMinY + .titleSwitchViewHeight
        if isExpertMode {
            customPriceTextFieldMinY += .customPriceTextFieldTopPadding
        }
        let customPriceTextFieldHeight = CGFloat.customPriceTextFieldHeight
        let customPriceTextFieldWidth = bounds.width - 2 * .horizontalPadding
        
        customPriceTextField.frame = .init(
            x: customPriceTextFieldMinX,
            y: customPriceTextFieldMinY,
            width: customPriceTextFieldWidth,
            height: customPriceTextFieldHeight
        )
        
        let totalHeight = customPriceTextFieldMinY + customPriceTextFieldHeight
        scrollView.contentSize = .init(width: bounds.width, height: totalHeight)
    }
    
    private func updateState() {
        let textFieldTransform: CGAffineTransform = isExpertMode ? CGAffineTransform(translationX: 0, y: .customPriceTextFieldTopPadding) : .identity
        let textFieldOpacity = isExpertMode ? 1.0 : 0.0
        self.customPriceTextField.transform = textFieldTransform
        self.customPriceTextField.alpha = textFieldOpacity
    }
    
    func keyboardWillShow(keyboardHeight: CGFloat, animationDuration: Double) {
        saveButtonBottomConstraint?.constant = -(keyboardHeight + 16.0 - safeAreaInsets.bottom)
        UIView.animate(withDuration: animationDuration) { [weak self] in
            self?.layoutIfNeeded()
        }
    }
    
    func keyboardWillHide(animationDuration: Double) {
        saveButtonBottomConstraint?.constant = -16
        UIView.animate(withDuration: animationDuration) { [weak self] in
            self?.layoutIfNeeded()
        }
    }
}

private extension CGFloat {
    static let navigationBarViewHeight: CGFloat = 48.0
    static let subtitleViewTopPadding: CGFloat = 12
    static let selectorViewTopPadding: CGFloat = 12
    static let titleSwitchViewHeight: CGFloat = 96.0
    static let customPriceTextFieldTopPadding = 12.0
    static let customPriceTextFieldHeight: CGFloat = 56
    static let horizontalPadding: CGFloat = 16
}

private extension SwapSettingsView {
    static func textFieldFormatter() -> SendAmountTextFieldFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.decimalSeparator = ""
        numberFormatter.maximumIntegerDigits = 1
        numberFormatter.roundingMode = .down
        let amountInputFormatController = SendAmountTextFieldFormatter(
            currencyFormatter: numberFormatter
        )
        amountInputFormatController.maximumFractionDigits = 2
        amountInputFormatController.inputFormatter.maximumIntegerCharacters = 2
        return amountInputFormatController
    }
}
