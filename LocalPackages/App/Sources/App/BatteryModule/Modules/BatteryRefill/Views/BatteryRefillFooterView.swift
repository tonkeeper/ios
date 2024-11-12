import UIKit
import TKUIKit

final class BatteryRefillFooterView: UIView {
  
  struct Configuration {
    let description: NSAttributedString
    let restoreButtonModel: TKPlainButton.Model
    
    init(description: String,
         restoreButtonTitle: String,
         restoreButtonAction: @escaping () -> Void) {
      self.description = description.withTextStyle(.body2, color: .Text.tertiary, alignment: .center, lineBreakMode: .byWordWrapping)
      self.restoreButtonModel = TKPlainButton.Model(
        title: restoreButtonTitle.withTextStyle(.body2, color: .Text.secondary, alignment: .center),
        icon: nil,
        action: restoreButtonAction
      )
    }
    
  }
  
  var configuration: Configuration? {
    didSet {
      didUpdateConfiguration()
    }
  }
  
  private let descriptionLabel = UILabel()
  private let restoreButton = TKPlainButton()
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    descriptionLabel.numberOfLines = 0
    
    addSubview(stackView)
    stackView.addArrangedSubview(descriptionLabel)
    stackView.addArrangedSubview(restoreButton)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self).inset(UIEdgeInsets(top: 0, left: 32, bottom: 0, right: 32))
    }
  }
  
  private func didUpdateConfiguration() {
    guard let configuration else { return }
    descriptionLabel.attributedText = configuration.description
    restoreButton.configure(model: configuration.restoreButtonModel)
  }
}
