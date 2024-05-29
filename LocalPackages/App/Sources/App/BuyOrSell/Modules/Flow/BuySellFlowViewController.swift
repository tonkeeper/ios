import UIKit
import TKUIKit
import SnapKit

final class BuySellFlowViewController: UIViewController, KeyboardObserving {
    let flowNavigationController = UINavigationController()
    let continueButton = TKButton()
    var didTapContinueButton: (() -> Void)?
    
    private var continueButtonBottomConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        continueButton.configuration = .actionButtonConfiguration(category: .primary, size: .large)
        continueButton.configuration.content.title = .plainString("Continue")
        continueButton.configuration.action = didTapContinueButton
        
        flowNavigationController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(flowNavigationController)
        view.addSubview(flowNavigationController.view)
        flowNavigationController.didMove(toParent: self)
        
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(continueButton)
        
        let flowNavigationControllerConstraints: [NSLayoutConstraint] = [
            flowNavigationController.view.topAnchor.constraint(equalTo: view.topAnchor),
            flowNavigationController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            flowNavigationController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            flowNavigationController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        
        let continueButtonBottomConstraint = continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        self.continueButtonBottomConstraint = continueButtonBottomConstraint
        
        let continueButtonConstraints: [NSLayoutConstraint] = [
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            continueButtonBottomConstraint,
        ]
        
        NSLayoutConstraint.activate(flowNavigationControllerConstraints)
        NSLayoutConstraint.activate(continueButtonConstraints)
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
        guard let keyboardSize = notification.keyboardSize,
              let animationDuration = notification.keyboardAnimationDuration
        else { return }
        updateButtonBottomConstraint(keyBoardHeight: -(keyboardSize.height - view.safeAreaInsets.bottom + 16), animationDuration: animationDuration)
    }
    
    func keyboardWillHide(_ notification: Notification) {
        updateButtonBottomConstraint(keyBoardHeight: -16, animationDuration: notification.keyboardAnimationDuration ?? 0)
    }
}

private extension BuySellFlowViewController {
    func updateButtonBottomConstraint(keyBoardHeight: CGFloat, animationDuration: Double) {
        continueButtonBottomConstraint?.constant = keyBoardHeight

        UIView.animate(withDuration: animationDuration) { [weak self] in
//            self?.view.layoutIfNeeded()
        }
    }
}
