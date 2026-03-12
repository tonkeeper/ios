import Combine
import SnapKit
import TKLocalize
import TKUIKit
import UIKit

final class BrowserSearchBar: UIView {
    var isCancelButtonOnEdit = false
    var cancelButtonAction: (() -> Void)?
    var clearButtonAction: (() -> Void)?

    var placeholder: String? {
        didSet {
            textField.attributedPlaceholder = placeholder?.withTextStyle(
                .body1,
                color: .Text.secondary
            )
        }
    }

    var isBlur = true {
        didSet {
            blurView.isHidden = !isBlur
        }
    }

    var padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16) {
        didSet {
            textFieldContainer.snp.remakeConstraints { make in
                make.left.bottom.top.equalTo(self).inset(padding)
                make.height.equalTo(48)
                textFieldRightConstraint = make.right.equalTo(self).offset(-16).constraint
                textFieldRightCancelButtonConstraint = make.right.equalTo(cancelButton.snp.left).offset(-16).constraint
            }
            textFieldRightCancelButtonConstraint?.deactivate()
        }
    }

    let glassImageView = UIImageView()
    let textField = UITextField()
    let blurView = TKBlurView()
    let glassView = TKGlassView()
    let textFieldContainer = UIView()
    let cancelButton = UIButton(type: .system)
    private lazy var clearButton: TKButton = {
        let button = TKButton()
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)

        button.configuration = TKButton.Configuration(
            content: .init(icon: .TKUIKit.Icons.Size16.xmarkCircle),
            contentPadding: .zero,
            padding: .zero,
            iconTintColor: .Icon.secondary,
            contentAlpha: [.normal: 1, .disabled: 0.48, .highlighted: 0.48],
            action: { [weak self] in
                self?.textField.text = nil
                self?.clearButtonAction?()
            }
        )
        return button
    }()

    private var textFieldRightConstraint: Constraint?
    private var textFieldRightCancelButtonConstraint: Constraint?

    private let applyGlassEffect: Bool

    init(applyGlassEffect: Bool = false) {
        self.applyGlassEffect = applyGlassEffect

        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func becomeFirstResponder() -> Bool {
        textField.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        textField.resignFirstResponder()
    }

    override var canBecomeFirstResponder: Bool {
        textField.canBecomeFirstResponder
    }

    override var canResignFirstResponder: Bool {
        textField.canResignFirstResponder
    }
}

private extension BrowserSearchBar {
    func setup() {
        glassImageView.image = .TKUIKit.Icons.Size16.magnifyingGlass
        glassImageView.tintColor = .Icon.secondary

        cancelButton.setTitle(TKLocales.Actions.cancel, for: .normal)
        cancelButton.setTitleColor(.Accent.blue, for: .normal)
        cancelButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
        cancelButton.alpha = 0
        cancelButton.titleLabel?.font = TKTextStyle.label1.font
        cancelButton.addAction(UIAction(handler: { [weak self] _ in
            self?.textField.resignFirstResponder()
            self?.textField.text = nil
            self?.clearButton.isHidden = true
            self?.cancelButtonAction?()
        }), for: .touchUpInside)

        textField.tintColor = .Accent.blue
        textField.textColor = .Text.primary
        textField.font = TKTextStyle.body1.font

        textField.addTarget(self, action: #selector(didBecomeActive), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(didBecomeInactive), for: .editingDidEnd)
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        textField.keyboardAppearance = .dark

        if applyGlassEffect {
            glassView.layer.masksToBounds = true
            glassView.layer.cornerRadius = 24
            blurView.isHidden = true
        } else {
            textFieldContainer.backgroundColor = .Background.content
            textFieldContainer.layer.masksToBounds = true
            textFieldContainer.layer.cornerRadius = 16
            glassView.isHidden = true
        }

        glassImageView.setContentHuggingPriority(.required, for: .horizontal)

        clearButton.isHidden = true

        addSubview(blurView)
        addSubview(cancelButton)
        addSubview(textFieldContainer)
        textFieldContainer.addSubview(glassView)
        textFieldContainer.addSubview(glassImageView)
        textFieldContainer.addSubview(textField)
        textFieldContainer.addSubview(clearButton)

        setupConstraints()
    }

    func setupConstraints() {
        glassView.snp.makeConstraints { make in
            make.edges.equalTo(textFieldContainer)
        }

        blurView.snp.makeConstraints { make in
            make.edges.equalTo(self)
        }

        textFieldContainer.snp.makeConstraints { make in
            make.left.bottom.top.equalTo(self).inset(padding)
            make.height.equalTo(48)
            textFieldRightConstraint = make.right.equalTo(self).offset(-16).constraint
            textFieldRightCancelButtonConstraint = make.right.equalTo(cancelButton.snp.left).offset(-16).constraint
        }
        textFieldRightCancelButtonConstraint?.deactivate()

        glassImageView.snp.makeConstraints { make in
            make.top.left.bottom.equalTo(textFieldContainer).inset(16)
        }

        clearButton.snp.makeConstraints { make in
            make.right.equalTo(textFieldContainer).inset(16)
            make.centerY.equalTo(textFieldContainer)
            make.height.width.equalTo(16)
        }

        textField.snp.makeConstraints { make in
            make.left.equalTo(glassImageView.snp.right).offset(12)
            make.top.bottom.equalTo(textFieldContainer)
            make.right.equalTo(clearButton.snp.left).inset(-8)
        }

        cancelButton.snp.makeConstraints { make in
            make.right.equalTo(self).offset(-16)
            make.centerY.equalTo(textFieldContainer)
            make.height.equalTo(48)
        }
    }

    @objc func didBecomeActive() {
        if isCancelButtonOnEdit {
            showCancelButton()
        }
    }

    @objc func didBecomeInactive() {
        hideCancelButton()
    }

    @objc func textFieldDidChange() {
        clearButton.isHidden = textField.text?.isEmpty ?? true
    }

    func showCancelButton() {
        textFieldRightConstraint?.deactivate()
        textFieldRightCancelButtonConstraint?.activate()
        UIView.animate(withDuration: 0.2) {
            self.cancelButton.alpha = 1
            self.layoutIfNeeded()
        }
    }

    func hideCancelButton() {
        textFieldRightCancelButtonConstraint?.deactivate()
        textFieldRightConstraint?.activate()
        UIView.animate(withDuration: 0.2) {
            self.cancelButton.alpha = 0
            self.layoutIfNeeded()
        }
    }
}
