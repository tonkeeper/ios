import KeeperCore
import SignRaw
import TKCoordinator
import TKCore
import TKLocalize
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

public final class NativeSwapCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didRequestOpenBuySell: ((_ isInternalPurchasing: Bool) -> Void)?

    private let wallet: Wallet
    private let fromToken: String?
    private let toToken: String?
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly

    private weak var confirmationCoordinator: NativeSwapTransactionConfirmationCoordinator?

    public init(
        wallet: Wallet,
        fromToken: String?,
        toToken: String?,
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.wallet = wallet
        self.fromToken = fromToken
        self.toToken = toToken
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        super.init(router: router)
    }

    override public func start() {
        openSwap()
    }

    public func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        confirmationCoordinator?.handleTonkeeperPublishDeeplink(sign: sign) ?? false
    }

    override public func didMoveTo(toParent parent: Coordinator?) {
        if parent == nil {
            confirmationCoordinator?.cancelPendingSignerFlow()
        }
    }
}

private extension NativeSwapCoordinator {
    func openSwap() {
        // Create contexts
        let context = AppContext(
            wallet: wallet,
            keeperCoreAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )
        let swapDependencies = SwapDependencies(
            wallet: wallet,
            keeperCoreAssembly: keeperCoreMainAssembly
        )

        // Create ViewModel
        let viewModel = NativeSwapViewModelImplementation(
            context: context,
            swapDependencies: swapDependencies,
            fromToken: fromToken,
            toToken: toToken
        )

        // Create ViewController
        let viewController = NativeSwapViewController(viewModel: viewModel)

        // Setup callbacks
        viewModel.didTapClose = { [weak self] in
            self?.didFinish?(self)
        }

        viewModel.didTapContinue = { [weak self, weak viewModel] model in
            self?.openConfirmation(model: model) { isSend in
                viewModel?.updateFocus(isSend)
            }
        }

        viewModel.didTapPicker = { [weak self, weak viewModel] token, isSend in
            guard let self else { return }

            var pickerToken: TokenPickerModelState.PickerToken = .ton(.ton)
            switch token {
            case let .ton(ton):
                switch ton {
                case .ton:
                    pickerToken = .ton(.ton)
                case let .jetton(jettonItem):
                    pickerToken = .ton(.jetton(jettonItem))
                }
            case .tron:
                pickerToken = .tronUSDT
            }

            openTokenPicker(
                wallet: wallet,
                token: pickerToken,
                mode: isSend ? .send : .receive,
                sourceViewController: router.rootViewController,
                completion: { [weak viewModel] token in
                    viewModel?.updateWithToken(token, isSend: isSend)
                }
            )
        }

        viewController.overrideUserInterfaceStyle = .dark
        viewController.modalPresentationStyle = .fullScreen
        router.push(viewController: viewController)
    }

    func openTokenPicker(
        wallet: Wallet,
        token: TokenPickerModelState.PickerToken,
        mode: NativeSwapTokenPickerModel.Mode,
        sourceViewController: UIViewController,
        completion: @escaping (KeeperCore.Token) -> Void
    ) {
        let model = NativeSwapTokenPickerModel(
            wallet: wallet,
            selectedToken: token,
            balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            swapAssetsStore: keeperCoreMainAssembly.storesAssembly.swapAssetsStore,
            mode: mode
        )

        let module = TokenPickerAssembly.module(
            wallet: wallet,
            model: model,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        let bottomSheetViewController = TKBottomSheetViewController(
            contentViewController: module.view,
            ignoreBottomSafeArea: true
        )

        module.output.didSelectToken = { token in
            let sendToken: KeeperCore.Token = {
                switch token {
                case let .ton(token):
                    switch token {
                    case .ton:
                        .ton(.ton)
                    case let .jetton(jettonInfo):
                        .ton(.jetton(jettonInfo))
                    }
                case .tronUSDT:
                    .tron(.usdt)
                }
            }()
            completion(sendToken)
        }

        module.output.didFinish = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        bottomSheetViewController.present(fromViewController: sourceViewController)
    }

    func openConfirmation(
        model: NativeSwapTransactionConfirmationModel,
        onEditFocus: @escaping (Bool?) -> Void
    ) {
        let coordinator = NativeSwapTransactionConfirmationCoordinator(
            wallet: wallet,
            model: model,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: router
        )

        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        coordinator.didClose = { [weak self, weak coordinator] in
            self?.didFinish?(self)
            self?.removeChild(coordinator)
        }

        coordinator.didTapEdit = { [weak self, weak coordinator] isSend in
            self?.removeChild(coordinator)
            onEditFocus(isSend)
        }

        coordinator.didRequestOpenBuySell = { [weak self, weak coordinator] isInternalPurchasing in
            self?.didRequestOpenBuySell?(isInternalPurchasing)
            self?.didFinish?(self)
            self?.removeChild(coordinator)
        }

        confirmationCoordinator = coordinator

        addChild(coordinator)
        coordinator.start(deeplink: nil)
    }
}
