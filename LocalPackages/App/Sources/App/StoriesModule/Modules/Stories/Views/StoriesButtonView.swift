import UIKit
import TKUIKit

final class StoriesButtonView: UIView, ConfigurableView {
  private var baseButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(
    category: .overlay,
    size: .medium
  )
  
  lazy var storiesButton = TKButton(configuration: baseButtonConfiguration)
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
    let buttonConfiguration = TKButton.Configuration(content: .init(title: TKButton.Configuration.Content.Title.plainString(model.title)), action: model.action)
        
    storiesButton.isHidden = false
    storiesButton.configuration = buttonConfiguration
  }
  
  func hideButton() {
    storiesButton.isHidden = true
  }
  
  func showButton() {
    storiesButton.isHidden = false
  }
}

private extension StoriesButtonView {
  func setup() {
    
    storiesButtonContainer.addSubview(storiesButton)
    addSubview(storiesButtonContainer)
  }
}

private extension UIEdgeInsets {
  static let storiesButtonPadding = UIEdgeInsets(
    top: 0,
    left: 0,
    bottom: 30,
    right: 0
  )
}
