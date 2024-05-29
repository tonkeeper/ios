import UIKit
import TKUIKit

final class SwapSettingsViewController: GenericViewViewController<SwapSettingsView>, KeyboardObserving {
    private let viewModel: SwapSettingsViewModel
    var didTapClose: (() -> Void)?
    
    init(viewModel: SwapSettingsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupViewBindings()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        registerForKeyboardEvents()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterFromKeyboardEvents()
    }
    
    public func keyboardWillShow(_ notification: Notification) {
        guard let animationDuration = notification.keyboardAnimationDuration,
              let keyboardHeight = notification.keyboardSize?.height else { return }
        customView.keyboardWillShow(keyboardHeight: keyboardHeight, animationDuration: animationDuration)
    }
    
    public func keyboardWillHide(_ notification: Notification) {
        guard let animationDuration = notification.keyboardAnimationDuration else { return }
        customView.keyboardWillHide(animationDuration: animationDuration)
    }
}

private extension SwapSettingsViewController {
    func setup() {
        customView.closeButton.addTapAction { [weak self] in
            self?.didTapClose?()
        }
        
        let titleText = "Settings".withTextStyle(
            .h3,
            color: .Text.primary,
            alignment: .left
        )
        customView.titleView.attributedText = titleText
        
        let subtitleText = "Slippage".withTextStyle(
            .label1,
            color: .Text.primary,
            alignment: .left
        )
        customView.subtitleView.attributedText = subtitleText
        
        let descriptionText = "The amount the price can change\nunfavorably before the trade reverts".withTextStyle(
            .body2,
            color: .Text.secondary,
            alignment: .left
        )
        customView.descriptionView.attributedText = descriptionText
        
        customView.selectorView.configure(
            model: .init(variants: ["1", "3", "5"], symbol: "%")
        )
        customView.selectorView.selectNumber(number: viewModel.currentTolerance)
        
        customView.titleSwitchView.configure(
            model: .init(
                title: "Expert Mode",
                subtitle: "Allows high price impact trades.\nUse at your own risk."
            )
        )
        
        customView.customPriceTextField.textFieldInputView.currency = "%"
        
        customView.saveButton.configuration = .actionButtonConfiguration(category: .primary, size: .large)
        customView.saveButton.configuration.content.title = .plainString("Save")
        customView.saveButton.configuration.action = { [weak self] in
            self?.viewModel.didTapSaveButton()
        }
    }
    
    func setupViewBindings() {
        customView.didSelectNumber = { [weak self] in
            self?.viewModel.selectTolerance(tolerance: $0)
        }
    }
}
