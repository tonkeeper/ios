import UIKit
import TKUIKit

final class StoriesButtonView: UIView, ConfigurableView {
  lazy var storiesButton: TKButton = {
    var configuration = TKButton.Configuration.actionButtonConfiguration(
      category: .primary,
      size: .medium
    )
    configuration.backgroundColors = [
      .normal: .white,
      .highlighted: .white.withAlphaComponent(0.44)
    ]
    configuration.textColor = .black
    return TKButton(configuration: configuration)
  }()
  
  let storiesButtonContainer: TKPaddingContainerView = {
    let container = TKPaddingContainerView()
    container.padding = .storiesButtonPadding
    return container
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  struct Model {
    let action: () -> Void
    let title: String
  }
  
  func configure(model: Model) {
    storiesButton.configuration.content = .init(title: .plainString(model.title))
    storiesButton.configuration.action = { 
      model.action()
    }
  }
  
  func hideButton() {
    super.isHidden = true
  }
  
  func showButton() {
    super.isHidden = false
  }
}

private extension StoriesButtonView {
  func setup() {
    addSubview(storiesButtonContainer)
    storiesButtonContainer.setViews([storiesButton])
    setupConstraints()
  }
  
  func setupConstraints() {
    storiesButtonContainer.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      storiesButtonContainer.topAnchor.constraint(equalTo: topAnchor),
      storiesButtonContainer.leftAnchor.constraint(equalTo: leftAnchor),
      storiesButtonContainer.rightAnchor.constraint(equalTo: rightAnchor),
      storiesButtonContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: .bottomSpacing),
    ])
  }
}

private extension UIEdgeInsets {
  static let storiesButtonPadding = UIEdgeInsets(
    top: 0,
    left: 32,
    bottom: 0,
    right: 32
  )
}

private extension CGFloat {
  static let bottomSpacing: CGFloat = 4
}
