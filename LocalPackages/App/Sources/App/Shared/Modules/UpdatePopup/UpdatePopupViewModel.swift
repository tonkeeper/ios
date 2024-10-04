import Foundation
import KeeperCore
import TKLocalize
import UIKit
import TKUIKit

protocol UpdatePopupModuleOutput: AnyObject {
  var didTapUpdate: (() -> Void)? { get set }
  var didTapClose: (() -> Void)? { get set }
}

protocol UpdatePopupModuleInput: AnyObject {
  func setConfiguration(_ configuration: UpdatePopupConfiguration)
}

protocol UpdatePopupViewModel: AnyObject {
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)? { get set }
  
  func viewDidLoad()
}

struct UpdatePopupConfiguration {
  struct Button {
    let title: String
    let category: TKUIActionButtonCategory
    let action: () -> Void
  }
  
  let icon: UIImage
  let title: String
  let caption: String?
  let buttons: [Button]
}

final class UpdatePopupViewModelImplementation: UpdatePopupViewModel, UpdatePopupModuleOutput, UpdatePopupModuleInput {
  
  // MARK: - UpdatePopupModuleOutput
  
  var didTapUpdate: (() -> Void)?
  var didTapClose: (() -> Void)?
  
  // MARK: - UpdatePopupModuleInput
  
  func setConfiguration(_ configuration: UpdatePopupConfiguration) {
    self.configuration = configuration
  }
  
  // MARK: - UpdatePopupViewModel
  
  var didUpdateConfiguration: ((TKModalCardViewController.Configuration) -> Void)?
  
  func viewDidLoad() {
    guard let configuration else { return }
    let model = buildModalCardModel(configuration: configuration)
    didUpdateConfiguration?(model)
  }
  
  // MARK: - Configuration
  
  private var configuration: UpdatePopupConfiguration?
}

private extension UpdatePopupViewModelImplementation {
  
  func buildModalCardModel(configuration: UpdatePopupConfiguration) -> TKModalCardViewController.Configuration {
    
    let buttons: [TKModalCardViewController.Configuration.Item] = configuration.buttons.enumerated().map { index, button in
        .button(TKModalCardViewController.Configuration.Button(
          title: button.title,
          size: .large,
          category: button.category,
          isEnabled: true,
          isActivity: false,
          tapAction: { _, _ in
            button.action()
          }
        ),
                bottomSpacing: index == configuration.buttons.count - 1 ? 0 : 16)
    }
    
    var items = [TKModalCardViewController.Configuration.Item]()
    
    let headerView = UpdatePopupHeaderView()
    headerView.image = configuration.icon
    items.append(
      .customView(headerView, bottomSpacing: 16)
    )
    items.append(
      .text(
        TKModalCardViewController.Configuration.Text(
          text: configuration.title.withTextStyle(
            .h2,
            color: .Text.primary,
            alignment: .center,
            lineBreakMode: .byWordWrapping
          ),
          numberOfLines: 0
        ),
        bottomSpacing: 4
      )
    )
    items.append(
      .text(
        TKModalCardViewController.Configuration.Text(
          text: configuration.caption?.withTextStyle(
            .body1,
            color: .Text.secondary,
            alignment: .center,
            lineBreakMode: .byWordWrapping
          ),
          numberOfLines: 0
        ),
        bottomSpacing: 32
      )
    )
    items.append(contentsOf: buttons)
    
    let header = TKModalCardViewController.Configuration.Header(
      items: items
    )
    
    return TKModalCardViewController.Configuration(
      header: header,
      actionBar: nil
    )
  }
}
