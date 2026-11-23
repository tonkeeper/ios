import SnapKit
import UIKit

public final class TKTextInputTextFieldControl: UITextField, TKTextFieldInputViewControl {
    public var didUpdateText: ((String) -> Void)?
    public var didBeginEditing: (() -> Void)?
    public var didEndEditing: (() -> Void)?
    public var shouldPaste: ((String) -> Bool)?

    public var inputText: String {
        get { text ?? "" }
        set { text = animatedAmountView == nil ? newValue : TKAmountDigits.grouped(newValue) }
    }

    override public var text: String? {
        didSet { setNeedsLayout() }
    }

    private var animatedAmountView: SwiftUIHostingView?
    private var animatedAmount: (text: String, font: UIFont)?
    private var hidesOwnGlyphs = false

    public var isActive: Bool {
        isFirstResponder
    }

    public var accessoryView: UIView? {
        get { inputAccessoryView }
        set { inputAccessoryView = newValue }
    }

    public var textFieldState: TKTextFieldState = .inactive {
        didSet {
            didUpdateState()
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func tkNumPadAmountKeyboard() {
        tkNumPadKeyboard()
        guard TKNumPadView.isEnabled, animatedAmountView == nil else { return }
        let view = SwiftUIHostingView()
        view.alpha = 0
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        addSubview(view)
        animatedAmountView = view
        text = TKAmountDigits.grouped(inputText)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        UIView.performWithoutAnimation(updateAnimatedAmount)
    }
}

private extension TKTextInputTextFieldControl {
    func updateAnimatedAmount() {
        guard let animatedAmountView else { return }
        let text = inputText
        let font = font ?? TKTextStyle.body1.font
        let rect = isEditing ? editingRect(forBounds: bounds) : textRect(forBounds: bounds)
        let fits = TKAmountDigits.fits(text, font: font, width: rect.width)
        let hidesOwn = fits && !text.isEmpty
        if hidesOwn != hidesOwnGlyphs {
            hidesOwnGlyphs = hidesOwn
            textColor = hidesOwn ? .clear : .Text.primary
        }
        animatedAmountView.alpha = fits ? 1 : 0
        animatedAmountView.frame = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: max(rect.width, window?.bounds.width ?? 0),
            height: rect.height
        )
        guard animatedAmount?.text != text || animatedAmount?.font != font else { return }
        animatedAmount = (text, font)
        animatedAmountView.setContent {
            TKAnimatedAmountText(text: text, font: font, color: .textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        animatedAmountView.layoutIfNeeded()
    }

    func setup() {
        backgroundColor = .clear
        font = TKTextStyle.body1.font
        textColor = .Text.primary
        tintColor = .Text.accent
        autocapitalizationType = .none
        autocorrectionType = .no
        pasteDelegate = self

        addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        addTarget(self, action: #selector(editingDidBegin), for: .editingDidBegin)
        addTarget(self, action: #selector(editingDidEnd), for: .editingDidEnd)

        snp.makeConstraints { make in
            make.height.equalTo(CGFloat.height)
        }
    }

    @objc func editingChanged() {
        setNeedsLayout()
        didUpdateText?(text ?? "")
    }

    @objc func editingDidBegin() {
        didBeginEditing?()
    }

    @objc func editingDidEnd() {
        didEndEditing?()
    }

    func didUpdateState() {
        tintColor = textFieldState.tintColor
    }
}

extension TKTextInputTextFieldControl: UITextPasteDelegate {
    public func textPasteConfigurationSupporting(
        _ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting,
        transform item: UITextPasteItem
    ) {
        guard let shouldPaste = shouldPaste else {
            item.setDefaultResult()
            return
        }
        Task { @MainActor in
            guard let pasteString = await UIPasteboard.general.readString(), shouldPaste(pasteString) else {
                item.setNoResult()
                return
            }
            item.setDefaultResult()
        }
    }
}

private extension CGFloat {
    static let height: CGFloat = 24
}
