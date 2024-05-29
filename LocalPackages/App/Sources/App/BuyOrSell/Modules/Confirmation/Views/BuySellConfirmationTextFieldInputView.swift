import UIKit
import SnapKit
import TKUIKit

public final class BuySellConfirmationTextFieldInputView: UIControl, TKTextFieldInputViewControl {
    // MARK: - TKTextFieldInputViewControl
    
    public var isActive: Bool {
        textInputControl.isActive
    }
    public var inputText: String {
        get { textInputControl.inputText }
        set {
            textInputControl.inputText = newValue
            updateTextAction()
            updateLayout(in: bounds.size)
        }
    }
    public var textFieldState: TKTextFieldState = .inactive {
        didSet {
            didUpdateState()
        }
    }
    public var accessoryView: UIView? {
        get { textInputControl.accessoryView }
        set { textInputControl.accessoryView = newValue }
    }
    public var didUpdateText: ((String) -> Void)?
    public var didBeginEditing: (() -> Void)?
    public var didEndEditing: (() -> Void)?
    public var shouldPaste: ((String) -> Bool)?
    
    public var padding: UIEdgeInsets = .zero {
        didSet {
            updateLayout(in: bounds.size)
        }
    }
    
    private var inputControlYOffset: CGFloat {
        placeholder.isEmpty ? 0 : .inputControlYOffset
    }
    
    // MARK: - Properties
    
    public var placeholder: String = "" {
        didSet {
            placeholderLabel.attributedText = placeholder.withTextStyle(
                .body1,
                color: .Text.secondary,
                alignment: .left
            )
            updateLayout(in: bounds.size)
        }
    }
    
    public var currency: String? {
        didSet {
            currencyLabel.attributedText = currency?.withTextStyle(
                .body1,
                color: .Text.secondary
            )
            updateLayout(in: bounds.size)
        }
    }
    
    // MARK: - Subviews
    
    private let textInputControl: TKTextFieldInputViewControl
    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.isUserInteractionEnabled = false
        label.layer.anchorPoint = .init(x: 0, y: 0.5)
        return label
    }()
    private let currencyLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.isUserInteractionEnabled = false
        return label
    }()
    
    // MARK: - Init
    
    public init(textInputControl: TKTextFieldInputViewControl) {
        self.textInputControl = textInputControl
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - First Responder
    
    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        textInputControl.becomeFirstResponder()
    }
    
    @discardableResult
    public override func resignFirstResponder() -> Bool {
        textInputControl.resignFirstResponder()
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout(in: bounds.size)
        updateTextInputAndPlaceholderLayoutAndScale()
    }
}

private extension BuySellConfirmationTextFieldInputView {
    func setup() {
        addSubview(textInputControl)
        addSubview(currencyLabel)
        addSubview(placeholderLabel)
        
        textInputControl.didUpdateText = { [weak self] in
            guard let self else { return }
            self.inputText = $0
            self.didUpdateText?(self.inputText)
            self.updateTextAction()
        }
        
        textInputControl.didBeginEditing = { [weak self] in
            self?.didBeginEditing?()
        }
        
        textInputControl.didEndEditing = { [weak self] in
            self?.didEndEditing?()
        }
        
        textInputControl.shouldPaste = { [weak self] in
            self?.shouldPaste?($0) ?? true
        }
        
        addAction(UIAction(handler: { [weak self] _ in
            self?.textInputControl.becomeFirstResponder()
        }), for: .touchUpInside)
    }
    
    func updateLayout(in: CGSize) {
        
        let currencyLabelBounds = CGSize(
            width: bounds.width - padding.left - padding.right,
            height: bounds.height - padding.top - padding.bottom
        )
        let currencyLabelSize: CGSize
        if inputText.isEmpty {
            currencyLabelSize = .zero
        } else {
            currencyLabelSize = currencyLabel.sizeThatFits(currencyLabelBounds)
        }
        
        let textInputControTextWidth = inputText.width(font: .inputFont)
        let textInputControlWidth = min(
            textInputControTextWidth,
            bounds.width - padding.left - padding.right - currencyLabelSize.width - .currencyLabelLeadingPadding
        )
        let textInputControlHeight = bounds.height - padding.top - padding.bottom
        let textInputControlMinX = padding.left
        let textInputControlMinY = inputControlYOffset + (bounds.height - textInputControlHeight) / 2.0
        
        textInputControl.frame = .init(
            x: textInputControlMinX,
            y: textInputControlMinY,
            width: textInputControlWidth,
            height: textInputControlHeight
        )
        
        let currencyLabelHeight = currencyLabelSize.height
        let currencyLabelWidth = currencyLabelSize.width
        let currencyLabelMinX = textInputControlMinX + textInputControlWidth + .currencyLabelLeadingPadding
        let currencyLabelMinY = inputControlYOffset + (bounds.height - currencyLabelHeight) / 2.0
        
        currencyLabel.frame = .init(
            x: currencyLabelMinX,
            y: currencyLabelMinY,
            width: currencyLabelWidth,
            height: currencyLabelHeight
        )
    }
    
    func updateTextInputAndPlaceholderLayoutAndScale() {
        updateTextInputControlPosition(isNeedToMove: !placeholder.isEmpty && !inputText.isEmpty)
        updatePlaceholderScaleAndPosition(isTop: !placeholder.isEmpty && !inputText.isEmpty)
    }
    
    func updateTextInputControlPosition(isNeedToMove: Bool) {
        let textInputControlTransform: CGAffineTransform = isNeedToMove ? CGAffineTransform(translationX: 0, y: .inputControlYOffset) : .identity
        textInputControl.transform = textInputControlTransform
    }
    
    func updatePlaceholderScaleAndPosition(isTop: Bool) {
        let scale: CGFloat = isTop ? .placeholderScale : 1
        let transform = isTop ? CGAffineTransform(scaleX: .placeholderScale, y: .placeholderScale) : .identity
        placeholderLabel.transform = transform
        let horizontalSpace = bounds.width - padding.left - padding.right
        let sizeThatFits = placeholderLabel.sizeThatFits(CGSize(width: horizontalSpace, height: 0))
        let size = CGSize(width: min(horizontalSpace, sizeThatFits.width), height: sizeThatFits.height)
        let y: CGFloat = isTop ? 12 : padding.top
        let frame = CGRect(
            x: padding.left,
            y: y,
            width: size.width * scale,
            height: size.height * scale
        )
        placeholderLabel.frame = frame
    }
    
    func clearButtonAction() {
        inputText = ""
        didUpdateText?(inputText)
        updateTextAction()
    }
    
    func updateTextAction() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
            self.updateTextInputAndPlaceholderLayoutAndScale()
        }
    }
    
    func didUpdateState() {
        textInputControl.textFieldState = textFieldState
    }
}

private extension CGFloat {
    static let placeholderScale: CGFloat = 0.75
    static let placeholderTopMargin: CGFloat = 12
    static let inputControlYOffset: CGFloat = 8
    static let currencyLabelLeadingPadding: CGFloat = 4
}

private extension String {
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

private extension UIFont {
  static var inputFont: UIFont = TKTextStyle.body1.font
}
