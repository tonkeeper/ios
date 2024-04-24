import UIKit
import TKUIKit

final class ReceiveButtonsView: UIView, ConfigurableView {
  
  let copyButton = TKUIActionButton(category: .secondary, size: .medium)
  let shareButton = TKButton(configuration: .actionButtonConfiguration(category: .secondary, size: .medium))
  
  private let stackView: UIStackView = {
    let stackView = UIStackView()
    stackView.axis = .horizontal
    stackView.spacing = 12
    return stackView
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let copyButtonModel: TKUIActionButton.Model
    let copyButtonAction: () -> Void
    let shareButtonConfiguration: TKButton.Configuration
  }
  
  func configure(model: Model) {
    copyButton.configure(model: model.copyButtonModel)
    copyButton.addTapAction(model.copyButtonAction)
    
    shareButton.configuration = model.shareButtonConfiguration
  }
}

private extension ReceiveButtonsView {
  func setup() {
    
    addSubview(stackView)
    stackView.addArrangedSubview(copyButton)
    stackView.addArrangedSubview(shareButton)

    setupConstraints()
  }
  
  func setupConstraints() {
    stackView.translatesAutoresizingMaskIntoConstraints = false
    
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.centerXAnchor.constraint(equalTo: centerXAnchor)
    ])
  }
}

private extension CGFloat {
  static let containerPadding: CGFloat = 24
  static let addressTopInset: CGFloat = 12
}
