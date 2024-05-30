import UIKit
import TKUIKit
import KeeperCore

final class SwapInfoViewController: GenericViewViewController<SwapInfoView> {
    private let viewModel: SwapInfoViewModel
    
    private let sendAmountTextFieldFormatter = amountTextFieldFormatter()
    private let receiveAmountTextFieldFormatter = amountTextFieldFormatter()
    
    init(viewModel: SwapInfoViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Swap"
        setup()
        setupViewBindings()
        setupViewModelBindings()
        viewModel.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        viewModel.viewWillAppear()
    }
}

private extension SwapInfoViewController {
    func setup() {
        customView.swapTokensView.sendSwapTokensView.textFieldControl.delegate = sendAmountTextFieldFormatter
        customView.swapTokensView.receiveSwapTokensView.textFieldControl.delegate = receiveAmountTextFieldFormatter
    }
    
    func setupViewBindings() {
        customView.swapTokensView.didUpdateInputSendToken = { [weak self] inputText in
            self?.viewModel.swapInfoController.setSendInput(inputText)
        }
        
        customView.swapTokensView.didSelectSendToken = { [weak self] in
            self?.viewModel.didTapSendTokenPickerButton()
        }
        
        customView.swapTokensView.didUpdateInputReceiveToken = { [weak self] inputText in
            self?.viewModel.swapInfoController.setReceiveInput(inputText)
        }
        
        customView.swapTokensView.didSelectReceiveToken = { [weak self] in
            self?.viewModel.didTapReceiveTokenPickerButton()
        }
        
        customView.swapTokensView.didSwapTokens = { [weak self] in
            self?.viewModel.didTapSwapTokensButton()
        }
        
        customView.swapTokensView.didTapMaxButton = { [weak self] in
            self?.viewModel.swapInfoController.toggleMax()
        }
    }
    
    func setupViewModelBindings() {
        viewModel.didUpdateModel = { [weak self] model in
            self?.customView.swapTokensView.configure(model: model)
        }
        
        viewModel.didUpdateContinueButton = { [weak self] configuration in
            self?.customView.continueButton.configuration = configuration
        }
        
        viewModel.didUpdateSendToken = { [weak self] token in
            self?.customView.swapTokensView.sendSwapTokensView.textFieldControl.text = ""
            self?.sendAmountTextFieldFormatter.maximumFractionDigits = token?.tokenFractionDigits ?? 0
        }
        
        viewModel.didUpdateReceiveToken = { [weak self] token in
            self?.customView.swapTokensView.receiveSwapTokensView.textFieldControl.text = ""
            self?.receiveAmountTextFieldFormatter.maximumFractionDigits = token?.tokenFractionDigits ?? 0
        }
        
        viewModel.didUpdateSendTokenInput = { [weak self] inputText in
            self?.customView.swapTokensView.sendSwapTokensView.textFieldControl.text = inputText
        }
        
        viewModel.didUpdateReceiveTokenInput = { [weak self] inputText in
            self?.customView.swapTokensView.receiveSwapTokensView.textFieldControl.text = inputText
        }
    }
}

private extension SwapInfoViewController {
    static func amountTextFieldFormatter() -> SendAmountTextFieldFormatter {
        let numberFormatter = NumberFormatter()
        numberFormatter.groupingSeparator = " "
        numberFormatter.groupingSize = 3
        numberFormatter.usesGroupingSeparator = true
        numberFormatter.decimalSeparator = Locale.current.decimalSeparator
        numberFormatter.maximumIntegerDigits = 16
        numberFormatter.roundingMode = .down
        let amountInputFormatController = SendAmountTextFieldFormatter(
            currencyFormatter: numberFormatter
        )
        amountInputFormatController.maximumFractionDigits = 16
        return amountInputFormatController
    }
}

private extension Token {
    var tokenFractionDigits: Int {
        switch self {
        case .ton:
            return TonInfo.fractionDigits
        case .jetton(let jettonItem):
            return jettonItem.jettonInfo.fractionDigits
        }
    }
}
