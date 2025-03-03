import UIKit
import TKUIKit
import TKLocalize
import SnapKit

final class BrowserSearchBar: UIView {
  
  var isCancelButtonOnEdit = false
  
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
  let textFieldContainer = UIView()
  let cancelButton = UIButton(type: .system)
  
  private var textFieldRightConstraint: Constraint?
  private var textFieldRightCancelButtonConstraint: Constraint?
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
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
    }), for: .touchUpInside)
    
    textField.tintColor = .Accent.blue
    textField.textColor = .Text.primary
    textField.font = TKTextStyle.body1.font
    
    textField.addTarget(self, action: #selector(didBecomeActive), for: .editingDidBegin)
    textField.addTarget(self, action: #selector(didBecomeInactive), for: .editingDidEnd)
    textField.keyboardAppearance = .dark
    
    textFieldContainer.backgroundColor = .Background.content
    textFieldContainer.layer.masksToBounds = true
    textFieldContainer.layer.cornerRadius = 16
    
    glassImageView.setContentHuggingPriority(.required, for: .horizontal)
    
    addSubview(blurView)
    addSubview(cancelButton)
    addSubview(textFieldContainer)
    textFieldContainer.addSubview(glassImageView)
    textFieldContainer.addSubview(textField)
    
    setupConstraints()
  }
  
  func setupConstraints() {
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
    
    textField.snp.makeConstraints { make in
      make.left.equalTo(glassImageView.snp.right).offset(12)
      make.top.bottom.equalTo(textFieldContainer)
      make.right.equalTo(textFieldContainer).offset(-12)
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
