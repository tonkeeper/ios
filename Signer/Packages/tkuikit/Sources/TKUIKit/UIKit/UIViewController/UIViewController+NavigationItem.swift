import UIKit

public extension UIViewController {
  func setupBackButton() {
    let backButton = TKButton.iconHeaderButton()
    backButton.configure(
      model: .init(
        contentModel: .init(image: .TKUIKit.Icons.Button.Header.back),
        action: { [weak self] in
          self?.navigationController?.popViewController(animated: true)
        }
      )
    )
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
  }
  
  func setCloseButton(closure: @escaping () -> Void) {
    let backButton = TKButton.iconHeaderButton()
    backButton.configure(
      model: .init(
        contentModel: .init(image: .TKUIKit.Icons.Button.Header.close),
        action: {
          closure()
        }
      )
    )
    navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
  }
}
