import UIKit
import TKUIKit

final class BuySellConfirmationViewController: GenericViewViewController<BuySellConfirmationView> {
    private let viewModel: BuySellConfirmationViewModel
    
    init(viewModel: BuySellConfirmationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
        setupViewEventsBinding()
        viewModel.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
}

private extension BuySellConfirmationViewController {
    func setupBindings() {
        viewModel.didUpdateInputValue = { [weak self] text in
            self?.customView.inputTextField.text = text
        }
        
        viewModel.didUpdateConvertedValue = { [weak self] text in
            self?.customView.convertedTextField.text = text
        }
        
        viewModel.didUpdateInputModel = { [weak self] model in
            guard let self else { return }
            self.customView.inputTextField.textFieldInputView.currency = model.tokenSymbol
            self.customView.inputFormatter.maximumFractionDigits = model.tokenFractionDigits ?? 0
            
            self.customView.convertedTextField.textFieldInputView.currency = model.currencySymbol
            self.customView.convertedFormatter.maximumFractionDigits = model.currencyFractionDigits ?? 0
        }
        
        viewModel.didUpdateItemModel = { [weak self] model in
            self?.customView.configure(model: model)
        }
    }
    
    func setupViewEventsBinding() {
        customView.inputTextField.didUpdateText = { [weak self] text in
            self?.viewModel.didEditTopInput(text)
        }
        
        customView.convertedTextField.didUpdateText = { [weak self] text in
            self?.viewModel.didEditBottomInput(text)
        }
    }
}
