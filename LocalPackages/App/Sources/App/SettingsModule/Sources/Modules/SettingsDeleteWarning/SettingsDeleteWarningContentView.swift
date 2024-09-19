import UIKit
import TKUIKit
import TKLocalize

final class SettingsDeleteWarningContentView: TKView {
  
  var didToggle: ((Bool) -> Void)?
  var didTapBackup: (() -> Void)?
  
  private var isSelected = false {
    didSet {
      didToggle?(isSelected)
      tickButton.isSelected = isSelected
    }
  }
  
  private let tickButton = SettingsDeleteWarningTickButton()
  private let stackView = UIStackView()
  
  override func setup() {
    backgroundColor = .Background.content
    layer.cornerRadius = 16
    layer.cornerCurve = .continuous
    
    tickButton.label.attributedText = TKLocales.SignOutWarning.tickDescription.withTextStyle(
      .body1,
      color: .Text.primary,
      alignment: .left,
      lineBreakMode: .byWordWrapping
    )
    
    tickButton.addAction(UIAction(handler: { [weak self] _ in
      self?.isSelected.toggle()
    }), for: .touchUpInside)
    
    stackView.axis = .vertical
    
    let backupButton = TKButton()
    let backupButtonConfiguration = TKButton.Configuration(
      content: TKButton.Configuration.Content(title: .plainString(TKLocales.SignOutWarning.tickBackUp)),
      contentPadding: .zero,
      padding: .zero,
      textStyle: .label1,
      textColor: .Accent.blue,
      contentAlpha: [.normal: 1, .highlighted: 0.48],
      action: { [weak self] in
        self?.didTapBackup?()
      }
    )
    backupButton.configuration = backupButtonConfiguration
    
    let backupButtonContainer = UIView()
    backupButtonContainer.addSubview(backupButton)
    backupButton.snp.makeConstraints { make in
      make.top.bottom.equalTo(backupButtonContainer)
      make.left.equalTo(backupButtonContainer).offset(40)
    }
    
    addSubview(stackView)
    stackView.addArrangedSubview(tickButton)
    stackView.setCustomSpacing(8, after: tickButton)
    stackView.addArrangedSubview(backupButtonContainer)
    
    setupConstraints()
  }
  
  override func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.top.bottom.equalTo(self).inset(16)
      make.left.right.equalTo(self).inset(16)
    }
  }
}

private final class SettingsDeleteWarningTickButton: UIControl {
  
  override var isSelected: Bool {
    didSet {
      tickView.isSelected = isSelected
    }
  }
  
  override var isHighlighted: Bool {
    didSet {
      tickView.alpha = isHighlighted ? 0.48 : 1
      label.alpha = isHighlighted ? 0.48 : 1
    }
  }
  
  let tickView = TKTickView()
  let label = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func setup() {
    label.numberOfLines = 0
    
    addSubview(tickView)
    addSubview(label)
    setupConstraints()
  }
  
  func setupConstraints() {
    tickView.snp.makeConstraints { make in
      make.top.left.equalTo(self)
    }
    
    label.snp.makeConstraints { make in
      make.top.equalTo(self)
      make.left.equalTo(tickView.snp.right).offset(12)
      make.right.equalTo(self)
      make.bottom.equalTo(self)
    }
  }
}
