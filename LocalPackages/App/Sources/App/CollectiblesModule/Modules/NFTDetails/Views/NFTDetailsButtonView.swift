import UIKit
import TKUIKit

final class NFTDetailsButtonView: UIView, ConfigurableView {
  struct Model {
    let buttonConfiguration: TKButton.Configuration
    let description: NSAttributedString?
  }
  
  func configure(model: Model) {
    button.configuration = model.buttonConfiguration
    if let description = model.description {
      descriptionLabel.isHidden = false
      descriptionLabel.attributedText = description
    } else {
      descriptionLabel.isHidden = true
      descriptionLabel.attributedText = nil
    }
  }
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 12
    return stackView
  }()
  
  private let button = TKButton()
  private let descriptionLabel = UILabel()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    addSubview(stackView)
    stackView.addArrangedSubview(button)
    stackView.addArrangedSubview(descriptionLabel)
    
    setupConstraints()
  }
  
  private func setupConstraints() {
    stackView.snp.makeConstraints { make in
      make.edges.equalTo(self)
    }
  }
}
