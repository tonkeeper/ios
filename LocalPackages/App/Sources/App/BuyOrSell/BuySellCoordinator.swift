import UIKit
import TKCoordinator
import TKUIKit
import KeeperCore
import TKCore
import TKScreenKit

final class BuySellCoordinator: RouterCoordinator<NavigationControllerRouter> {
    enum Step {
        case start
        case operators
        case confirmation(itemModel: BuySellItemModel, type: BuySellConfirmationType, currency: Currency)
        case webView(url: URL, viewController: UIViewController)
    }
    
    private var currentStep: Step? = Step.start
    private var tab: BuySellTab = .buy
    
    var didFinish: (() -> Void)?
    
    func destinationAction() {
        switch currentStep {
        case .start:
            openTab()
        case .operators:
            openOperators()
        case let .confirmation(itemModel, type, currency):
            openConfirmation(itemModel: itemModel, type: type, currency: currency)
        case .webView(let url, let viewController):
            openWebView(url: url, fromViewController: viewController)
        case nil:
            break
        }
    }
    
    private let flowViewController = BuySellFlowViewController()
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    
    private let buyInputController: BuyInputController
    private let sellInputController: SellInputController
    private let operatorsController: OperatorsController    
    private let settingsController: SettingsController
    private let confirmationInputController: ConfirmationInputController
    
    init(
        router: NavigationControllerRouter,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        buyInputController: BuyInputController,
        sellInputController: SellInputController,
        operatorsController: OperatorsController,
        settingsController: SettingsController,
        confirmationInputController: ConfirmationInputController
    ) {
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.buyInputController = buyInputController
        self.sellInputController = sellInputController
        self.operatorsController = operatorsController
        self.settingsController = settingsController
        self.confirmationInputController = confirmationInputController
        super.init(router: router)
    }
    
    public override func start() {
        router.push(viewController: flowViewController)
        flowViewController.navigationController?.setNavigationBarHidden(true, animated: false)
        
        flowViewController.didTapContinueButton = { [weak self] in
            guard let self else { return }
            self.destinationAction()
        }
        
        openTab()
    }
}

private extension BuySellCoordinator {
    func openTab() {
        currentStep = .operators
        
        let buyModule = BuyAssembly.module(buyInputController: buyInputController)
        let sellModule = SellAssembly.module(sellInputController: sellInputController)
        
        let tabModule = BuySellTabAssembly.module(
            buyViewController: buyModule.view,
            sellViewController: sellModule.view
        )
        
        tabModule.view.didSelectBuyTab = { [weak self] in
            self?.tab = .buy
        }
        
        tabModule.view.didSelectSellTab = { [weak self] in
            self?.tab = .sell
        }
        
        tabModule.view.didTapClose = { [weak self] in
            self?.didFinish?()
        }
        
        flowViewController.flowNavigationController.pushViewController(tabModule.view, animated: false)
    }
    
    func openOperators() {
        let module = BuySellOperatorAssembly.module(
            operatorsController: operatorsController,
            settingsController: settingsController
        )
        
        module.output.didTapBack = { [weak self] in
            self?.currentStep = .operators
            self?.flowViewController.flowNavigationController.popViewController(animated: true)
        }
        
        module.output.didTapClose = { [weak self] in
            self?.didFinish?()
        }
        
        module.output.didUpdateIsContinueButtonLoading = { [weak self] isLoading in
            self?.setContinueButton(loading: isLoading)
        }
        
        module.output.didTapOperator = { [weak self] itemModel, currency in
            guard let self else { return }
            self.currentStep = .confirmation(itemModel: itemModel, type: self.tab.asConfiramtionType, currency: currency)
        }
        
        module.output.didTapCurrencyPicker = { [weak self] selectedCurrency in
            self?.openCurrencyPicker(
                selectedCurrency: selectedCurrency,
                didSelect: { [module] currency in
                    module.input.setCurrency(currency: currency)
                }
            )
        }
        
        flowViewController.flowNavigationController.pushViewController(module.view, animated: true)
    }
    
    func openConfirmation(itemModel: BuySellItemModel, type: BuySellConfirmationType, currency: Currency) {
        if let actionURL = itemModel.actionURL {
            currentStep = .webView(url: actionURL, viewController: router.rootViewController)
        } else if let actionURLPath = itemModel.actionButton?.url, let actionURL = URL(string: actionURLPath) {
            currentStep = .webView(url: actionURL, viewController: router.rootViewController)
        } else {
            currentStep = nil
        }
        
        let module = BuySellConfirmationAssembly.module(
            itemModel: itemModel,
            type: type,
            currency: currency,
            confirmationInputController: confirmationInputController
        )
        
        module.view.navigationItem.setupBackButton { [weak self] in
            self?.currentStep = .confirmation(itemModel: itemModel, type: type, currency: currency)
            self?.flowViewController.flowNavigationController.popViewController(animated: true)
        }
        
        module.view.setupRightCloseButton { [weak self] in
            self?.didFinish?()
        }
        
        module.output.didUpdateIsContinueButtonLoading = { [weak self] isLoading in
            self?.setContinueButton(loading: isLoading)
        }
        
        flowViewController.flowNavigationController.pushViewController(module.view, animated: true)
    }
    
    func openCurrencyPicker(selectedCurrency: Currency, didSelect: @escaping (Currency) -> Void) {
        let module = CurrencyPickerAssembly.module(selectedCurrency: selectedCurrency, settingsController: settingsController)
        let navigationController = TKNavigationController(rootViewController: module.view)
        navigationController.configureDefaultAppearance()
        
        module.view.setupRightCloseButton { [weak self] in
            self?.router.dismiss()
        }
        
        module.output.didSelectCurrency = { currency in
            didSelect(currency)
        }

        router.present(navigationController, animated: true)
    }
    
    func openWebView(url: URL, fromViewController: UIViewController) {
      let webViewController = TKWebViewController(url: url)
      let navigationController = UINavigationController(rootViewController: webViewController)
      navigationController.modalPresentationStyle = .fullScreen
      navigationController.configureDefaultAppearance()
      fromViewController.present(navigationController, animated: true)
    }
}

private extension BuySellCoordinator {
    func setContinueButton(loading isLoading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.flowViewController.continueButton.configuration.showsLoader = isLoading
        }
    }
}

private extension BuySellTab {
    var asConfiramtionType: BuySellConfirmationType {
        switch self {
        case .buy:
            return .buy
        case .sell:
            return .sell
        }
    }
}
