import UIKit

final class SettingsBackupView: UIView, ConfigurableView {
  
  let stackView = UIStackView()
  let titleLabel = UILabel()
  let subtitleLabel = UILabel()
  let backupManuallyButton = TKButton(configuration: .secondaryLarge)
  let showRecoveryPhraseButton = SettingsListCellContentView()
  let showRecoveryPhraseButtonContainer = UIView()
  let backupDateView = SettingsBackupDateView()
  
  // MARK: - Init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // MARK: - ConfigurableView
  
  struct Model {
    struct BackupManuallyButtonModel {
      let title: String
      let action: () -> Void
    }
    let title: String
    let subtitle: String
    let backupManuallyButtonModel: BackupManuallyButtonModel?
    let backupDateViewModel: SettingsBackupDateView.Model?
    let showRecoveryPhraseButtonModel: SettingsListCellContentView.Model?
    
  }
  
  func configure(model: Model) {
    titleLabel.attributedText = model.title.attributed(with: .h3, alignment: .left, color: .Text.primary)
    subtitleLabel.attributedText = model.subtitle.attributed(with: .body2, alignment: .left, color: .Text.secondary)
    
    if let backupManuallyButtonModel = model.backupManuallyButtonModel {
      backupManuallyButton.isHidden = false
      backupManuallyButton.configure(model: TKButton.Model(title: .string(backupManuallyButtonModel.title)))
      backupManuallyButton.addAction(UIControlClosure.UIAction(handler: {
        backupManuallyButtonModel.action()
      }), for: .touchUpInside)
    } else {
      backupManuallyButton.isHidden = true
    }
    
    if let backupDateViewModel = model.backupDateViewModel {
      backupDateView.isHidden = false
      backupDateView.configure(model: backupDateViewModel)
    } else {
      backupDateView.isHidden = true
    }
    
    if let showRecoveryPhraseButtonModel = model.showRecoveryPhraseButtonModel {
      showRecoveryPhraseButtonContainer.isHidden = false
      showRecoveryPhraseButton.configure(model: showRecoveryPhraseButtonModel)
      showRecoveryPhraseButton.addAction(UIControlClosure.UIAction(handler: {
        showRecoveryPhraseButtonModel.handler?()
      }), for: .touchUpInside)
    } else {
      showRecoveryPhraseButtonContainer.isHidden = true
    }
  }
}

private extension SettingsBackupView {
  func setup() {
    backgroundColor = .Background.page
    
    subtitleLabel.numberOfLines = 0
    
    stackView.axis = .vertical
    
    showRecoveryPhraseButtonContainer.backgroundColor = .Background.content
    showRecoveryPhraseButtonContainer.layer.cornerRadius = 16
    showRecoveryPhraseButtonContainer.layer.masksToBounds = true
    
    addSubview(stackView)
    showRecoveryPhraseButtonContainer.addSubview(showRecoveryPhraseButton)
    stackView.addArrangedSubview(titleLabel)
    stackView.setCustomSpacing(4, after: titleLabel)
    stackView.addArrangedSubview(subtitleLabel)
    stackView.setCustomSpacing(14, after: subtitleLabel)
    stackView.addArrangedSubview(backupManuallyButton)
    stackView.addArrangedSubview(backupDateView)
    stackView.setCustomSpacing(16, after: backupDateView)
    stackView.addArrangedSubview(showRecoveryPhraseButtonContainer)
    
    stackView.isLayoutMarginsRelativeArrangement = true
    stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 0, trailing: 16)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    showRecoveryPhraseButton.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      
      showRecoveryPhraseButton.topAnchor.constraint(equalTo: showRecoveryPhraseButtonContainer.topAnchor),
      showRecoveryPhraseButton.leftAnchor.constraint(equalTo: showRecoveryPhraseButtonContainer.leftAnchor),
      showRecoveryPhraseButton.rightAnchor.constraint(equalTo: showRecoveryPhraseButtonContainer.rightAnchor),
      showRecoveryPhraseButton.bottomAnchor.constraint(equalTo: showRecoveryPhraseButtonContainer.bottomAnchor)
    ])
  }
}
