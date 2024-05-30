import UIKit
import TKUIKit

public class BuySellConfirmationTextField: UIControl {
    public var isActive: Bool {
        textFieldInputView.isActive
    }
    
    public var isValid = true {
        didSet {
            didUpdateActiveState()
        }
    }
    
    public var text: String! {
        get { textFieldInputView.inputText }
        set {
            textFieldInputView.inputText = newValue
        }
    }
    
    public var placeholder: String {
        get { textFieldInputView.placeholder }
        set { textFieldInputView.placeholder = newValue }
    }
    
    public var didUpdateText: ((String) -> Void)?
    public var didBeginEditing: (() -> Void)?
    public var didEndEditing: (() -> Void)?
    public var shouldPaste: ((String) -> Bool)?
    
    public var textFieldState: TKTextFieldState = .inactive {
        didSet {
            didUpdateState()
        }
    }
    
    let textFieldInputView: BuySellConfirmationTextFieldInputView
    
    public init(textFieldInputView: BuySellConfirmationTextFieldInputView) {
        self.textFieldInputView = textFieldInputView
        super.init(frame: .zero)
        backgroundColor = .Field.background
        layer.borderWidth = 1.5
        layer.cornerRadius = 16
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        textFieldInputView.becomeFirstResponder()
    }
    
    @discardableResult
    public override func resignFirstResponder() -> Bool {
        textFieldInputView.resignFirstResponder()
    }
}

private extension BuySellConfirmationTextField {
    func setup() {
        textFieldInputView.didUpdateText = { [weak self] text in
            self?.didUpdateText?(text)
        }
        
        textFieldInputView.didBeginEditing = { [weak self] in
            self?.didUpdateActiveState()
            self?.didBeginEditing?()
        }
        
        textFieldInputView.didEndEditing = { [weak self] in
            self?.didUpdateActiveState()
            self?.didEndEditing?()
        }
        
        textFieldInputView.shouldPaste = { [weak self] in
            self?.shouldPaste?($0) ?? true
        }
        
        textFieldInputView.padding = UIEdgeInsets(
            top: 20,
            left: 16,
            bottom: 20,
            right: 16
        )
        
        didUpdateState()
        
        addSubview(textFieldInputView)
        
        setupConstraints()
        
        addAction(UIAction(handler: { [weak self] _ in
            self?.textFieldInputView.becomeFirstResponder()
        }), for: .touchUpInside)
    }
    
    func setupConstraints() {
        textFieldInputView.snp.makeConstraints { make in
            make.right.top.left.bottom.equalTo(self)
        }
    }
    
    func didUpdateState() {
        UIView.animate(withDuration: 0.2) { [weak self] in
            guard let self else { return }
            self.textFieldInputView.textFieldState = self.textFieldState
            if self.textFieldState == .active {
                self.layer.borderColor = UIColor.Accent.blue.cgColor
            } else {
                self.layer.borderColor = UIColor.clear.cgColor
            }
        }
    }
    
    func didUpdateActiveState() {
        switch (isActive, isValid) {
        case (false, true):
            textFieldState = .inactive
        case (true, true):
            textFieldState = .active
        case (false, false):
            textFieldState = .error
        case (true, false):
            textFieldState = .error
        }
    }
}
