import UIKit
import TKUIKit
import KeeperCore

final class SwapConfirmationViewController: GenericViewViewController<SwapConfirmationView> {
    private let viewModel: SwapConfirmationViewModel
    
    private let sendAmountTextFieldFormatter = textFieldFormatter()
    private let receiveAmountTextFieldFormatter = textFieldFormatter()
    
    var didTapCancel: (() -> Void)?
    var didTapClose: (() -> Void)?
    
    init(viewModel: SwapConfirmationViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
        setupViewModelBindings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        viewModel.viewWillAppear()
    }
}
private extension SwapConfirmationViewController {
    func setup() {
        let titleViewText = "Confirm Swap".withTextStyle(.h3, color: .Text.primary, alignment: .left)
        customView.titleView.attributedText = titleViewText
        
        customView.closeButton.addTapAction { [weak self] in
            self?.didTapClose?()
        }
        
        var cancelButtonConfiguration: TKButton.Configuration = .actionButtonConfiguration(category: .secondary, size: .large)
        cancelButtonConfiguration.content = .init(title: .plainString("Cancel"))
        cancelButtonConfiguration.action = { [weak self] in
            self?.didTapCancel?()
        }
        customView.cancelButton.configuration = cancelButtonConfiguration
        
        var confirmButtonConfiguration: TKButton.Configuration = .actionButtonConfiguration(category: .primary, size: .large)
        confirmButtonConfiguration.content = .init(title: .plainString("Confirm"))
        confirmButtonConfiguration.action = { [weak self] in
            self?.viewModel.didTapConfirmButton()
        }
        customView.confirmButton.configuration = confirmButtonConfiguration
        
        customView.swapTokensView.sendSwapTokensView.textFieldControl.delegate = sendAmountTextFieldFormatter
        customView.swapTokensView.receiveSwapTokensView.textFieldControl.delegate = receiveAmountTextFieldFormatter
    }
    
    func setupViewModelBindings() {
        viewModel.didUpdateModel = { [weak self] model in
            self?.customView.swapTokensView.configure(model: model)
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
        
        viewModel.didUpdateButtons = { [weak self] in
            self?.customView.successFlowView.state = $0
        }
    }
}

private extension SwapConfirmationViewController {
    static func textFieldFormatter() -> SendAmountTextFieldFormatter {
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
