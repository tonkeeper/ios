import UIKit
import TKUIKit
import TKLocalize

final class BrowserSearchBar: UIView {
  
  let glassImageView = UIImageView()
  let textField = UITextField()
  let blurView = TKBlurView()
  let textFieldContainer = UIView()
  
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
    glassImageView.image = .TKUIKit.Icons.Size16.globe
    glassImageView.tintColor = .Icon.secondary
    
    textField.tintColor = .Accent.blue
    textField.textColor = .Text.primary
    textField.font = TKTextStyle.body1.font
    textField.attributedPlaceholder = TKLocales.Browser.SearchField.placeholder.withTextStyle(
      .body1,
      color: .Text.secondary
    )
    textField.addTarget(self, action: #selector(didBecomeActive), for: .editingDidBegin)
    textField.addTarget(self, action: #selector(didBecomeInactive), for: .editingDidEnd)
    textField.keyboardAppearance = .dark
    
    textFieldContainer.backgroundColor = .Background.content
    textFieldContainer.layer.masksToBounds = true
    textFieldContainer.layer.cornerRadius = 16
    
    glassImageView.setContentHuggingPriority(.required, for: .horizontal)
    
    addSubview(blurView)
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
      make.edges.equalTo(self).inset(16)
      make.height.equalTo(48)
    }
    
    glassImageView.snp.makeConstraints { make in
      make.top.left.bottom.equalTo(textFieldContainer).inset(16)
    }
    
    textField.snp.makeConstraints { make in
      make.left.equalTo(glassImageView.snp.right).offset(12)
      make.top.bottom.equalTo(textFieldContainer)
      make.right.equalTo(textFieldContainer).offset(-12)
    }
  }
  
  @objc func didBecomeActive() {
    textField.isUserInteractionEnabled = true
  }
  
  @objc func didBecomeInactive() {
    textField.isUserInteractionEnabled = false
  }
}
