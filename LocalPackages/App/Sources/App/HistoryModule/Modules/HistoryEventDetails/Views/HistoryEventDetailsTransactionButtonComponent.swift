import UIKit
import TKUIKit

struct HistoryEventDetailsTransactionButtonComponent: TKPopUp.Item {
  func getView() -> UIView {
    let view = HistoryEventDetailsTransactionButtonView(
      configuration: configuration
    )
    return view
  }
  
  private let configuration: HistoryEventDetailsTransactionButtonView.Configuration
  public let bottomSpace: CGFloat
  
  init(configuration: HistoryEventDetailsTransactionButtonView.Configuration,
       bottomSpace: CGFloat) {
    self.configuration = configuration
    self.bottomSpace = bottomSpace
  }
}

final class HistoryEventDetailsTransactionButtonView: UIView {
  
  struct Configuration {
    let title: NSAttributedString
    let action: () -> Void
  }
  
  private let configuration: Configuration

  init(configuration: Configuration) {
    self.configuration = configuration
    super.init(frame: .zero)
    setup()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func setup() {
    var buttonConfiguration = TKButton.Configuration.actionButtonConfiguration(
      category: .secondary, 
      size: .small
    )
    buttonConfiguration.content = TKButton.Configuration.Content(
      title: .attributedString(configuration.title),
      icon: .TKUIKit.Icons.Size16.globe
    )
    buttonConfiguration.spacing = 8
    buttonConfiguration.action = configuration.action
    let button = TKButton()
    button.configuration = buttonConfiguration
    
    addSubview(button)
    button.snp.makeConstraints { make in
      make.top.bottom.equalTo(self)
      make.centerX.equalTo(self)
      make.left.greaterThanOrEqualTo(self).priority(.medium)
      make.right.lessThanOrEqualTo(self).priority(.medium)
    }
  }
}
