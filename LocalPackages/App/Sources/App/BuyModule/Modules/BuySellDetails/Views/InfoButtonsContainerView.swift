import UIKit
import TKUIKit
import SnapKit

final class InfoButtonsContainerView: UIView, ConfigurableView {
  
  private let leftButton = TKButton(configuration: .infoButtonConfiguration())
  private let rightButton = TKButton(configuration: .infoButtonConfiguration())
  private let spacerDot: UILabel = {
    let label = UILabel()
    label.attributedText = " · ".withTextStyle(.body2, color: .Text.tertiary)
    label.isHidden = true
    return label
  }()
  
  private let contentStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.distribution = .fillProportionally
    return stackView
  }()
  
  init() {
    super.init(frame: .zero)
    self.setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    struct Button {
      let title: NSAttributedString
      let action: (() -> Void)?
    }
    
    let leftButton: Button?
    let rightButton: Button?
    
    init(leftButton: Button? = nil, rightButton: Button? = nil) {
      self.leftButton = leftButton
      self.rightButton = rightButton
    }
  }
  
  func configure(model: Model) {
    configureButton(leftButton, with: model.leftButton)
    configureButton(rightButton, with: model.rightButton)
    
    spacerDot.isHidden = leftButton.isHidden && rightButton.isHidden

    invalidateIntrinsicContentSize()
  }
}

private extension InfoButtonsContainerView {
  func setup() {
    contentStackView.addArrangedSubview(leftButton)
    contentStackView.addArrangedSubview(spacerDot)
    contentStackView.addArrangedSubview(rightButton)
    addSubview(contentStackView)
    
    setupConstraints()
  }
  
  func setupConstraints() {
    contentStackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
  
  func configureButton(_ button: TKButton, with buttonConfiguration: Model.Button?) {
    if let buttonConfiguration {
      button.isHidden = false
      button.isEnabled = false
      button.configuration.content.title = .attributedString(buttonConfiguration.title)
      button.configuration.action = buttonConfiguration.action
    } else {
      button.isHidden = true
      button.isEnabled = true
      button.configuration.content.title = nil
      button.configuration.action = nil
    }
  }
}

private extension TKButton.Configuration {
  static func infoButtonConfiguration() -> TKButton.Configuration {
    var configuration = TKButton.Configuration.headerAccentButtonConfiguration()
    configuration.padding = .zero
    return configuration
  }
}