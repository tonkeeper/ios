import UIKit
import TKUIKit
import SnapKit

protocol SendEditFlowViewControllerChild: UIViewController {
  var bottomInset: CGFloat { get set }
}

final class SendEditFlowViewController: UIViewController, KeyboardObserving {
  let flowNavigationController = UINavigationController()
  let buttonsView = SendEditButtonsView()
  
  private var buttonsViewSafeAreaBottomConstraint: Constraint?
  private var buttonsViewViewBottomConstraint: Constraint?
  
  private var keyboardHeight: CGFloat = 0 {
    didSet {
      if keyboardHeight.isZero {
        buttonsViewViewBottomConstraint?.isActive = false
        buttonsViewSafeAreaBottomConstraint?.isActive = true
      } else {
        buttonsViewSafeAreaBottomConstraint?.isActive = false
        buttonsViewViewBottomConstraint?.update(inset: keyboardHeight)
        buttonsViewViewBottomConstraint?.isActive = true
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
      
    addChild(flowNavigationController)
    view.addSubview(flowNavigationController.view)
    flowNavigationController.didMove(toParent: self)
    
    view.addSubview(buttonsView)
    
    flowNavigationController.view.snp.makeConstraints { make in
      make.edges.equalTo(self.view)
    }
    buttonsView.snp.makeConstraints { make in
      make.left.right.equalTo(self.view)
      buttonsViewSafeAreaBottomConstraint = make.bottom.equalTo(self.view.safeAreaLayoutGuide).constraint
      buttonsViewViewBottomConstraint = make.bottom.equalTo(self.view).constraint
    }
    buttonsViewViewBottomConstraint?.deactivate()
    
    var backButtonConfiguration = buttonsView.backButton.configuration
    backButtonConfiguration.content.title = .plainString("Back")
    
    var nextButtonConfiguration = buttonsView.nextButton.configuration
    nextButtonConfiguration.content.title = .plainString("Next")
    
    buttonsView.backButton.configuration = backButtonConfiguration
    buttonsView.nextButton.configuration = nextButtonConfiguration
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    registerForKeyboardEvents()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    unregisterFromKeyboardEvents()
  }
  
  func keyboardWillShow(_ notification: Notification) {
    guard let keyboardSize = notification.keyboardSize else { return }
    keyboardHeight = keyboardSize.height

    let additionalHeight = keyboardHeight - view.safeAreaInsets.bottom + buttonsView.systemLayoutSizeFitting(CGSize(width: view.bounds.width, height: 0)).height
    flowNavigationController.viewControllers.forEach { $0.additionalSafeAreaInsets.bottom = additionalHeight }
  }
  
  func keyboardWillHide(_ notification: Notification) {
    keyboardHeight = 0
    
    let additionalHeight = buttonsView.systemLayoutSizeFitting(CGSize(width: view.bounds.width, height: 0)).height
    flowNavigationController.viewControllers.forEach { $0.additionalSafeAreaInsets.bottom = additionalHeight }
  }
  
  func setIsNextAvailable(_ isAvailable: Bool) {
    buttonsView.nextButton.isEnabled = isAvailable
  }
}
