import KeeperCore
import SignRaw
import TKCoordinator
import TKCore
import TKLocalize
import TKScreenKit
import TKUIKit
import TonSwift
import UIKit

final class NativeSwapCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didRequestOpenBuySell: ((_ isInternalPurchasing: Bool) -> Void)?

    private let wallet: Wallet
    private let nativeSwapContext: NativeSwapContext
    private let initiatedBy: InitiatedBy
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly

    private weak var confirmationCoordinator: NativeSwapTransactionConfirmationCoordinator?
    private var tokenUpdateTask: Task<Void, Never>?

    init(
        wallet: Wallet,
        nativeSwapContext: NativeSwapContext,
        initiatedBy: InitiatedBy,
        router: NavigationControllerRouter,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.wallet = wallet
        self.nativeSwapContext = nativeSwapContext
        self.initiatedBy = initiatedBy
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        super.init(router: router)
    }

    override func start() {
        openSwap()
    }

    func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        confirmationCoordinator?.handleTonkeeperPublishDeeplink(sign: sign) ?? false
    }

    override func didMoveTo(toParent parent: Coordinator?) {
        if parent == nil {
            tokenUpdateTask?.cancel()
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
        let tokenizedAssetResolver = NativeSwapTokenizedAssetResolver(
            assetDetailsService: swapDependencies.tradingAssetDetailsService,
            network: wallet.network
        )
        seedClassifications(
            nativeSwapContext: nativeSwapContext,
            tokenizedAssetResolver: tokenizedAssetResolver
        )

        // Create ViewModel
        let viewModel = NativeSwapViewModelImplementation(
            context: context,
            swapDependencies: swapDependencies,
            tokenizedAssetResolver: tokenizedAssetResolver,
            nativeSwapContext: nativeSwapContext
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

        viewModel.didTapPicker = { [weak self, weak viewModel] token, counterpartToken, isSend in
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
            case let .tron(token):
                pickerToken = .tron(token)
            }

            openTokenPicker(
                wallet: wallet,
                token: pickerToken,
                counterpartToken: counterpartToken,
                tokenizedAssetResolver: tokenizedAssetResolver,
                mode: isSend ? .send : .receive,
                sourceViewController: router.rootViewController,
                completion: { [weak self, weak viewModel] token in
                    guard let self else {
                        return
                    }
                    tokenUpdateTask?.cancel()
                    tokenUpdateTask = Task { @MainActor in
                        await viewModel?.updateWithTokenIfAllowed(token, isSend: isSend)
                    }
                }
            )
        }

        viewController.modalPresentationStyle = .fullScreen
        router.push(viewController: viewController)
    }

    func openTokenPicker(
        wallet: Wallet,
        token: TokenPickerModelState.PickerToken,
        counterpartToken: KeeperCore.Token,
        tokenizedAssetResolver: NativeSwapTokenizedAssetResolver,
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
            counterpartToken: counterpartToken,
            tokenizedAssetResolver: tokenizedAssetResolver,
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
                case let .tron(token):
                    .tron(token)
                }
            }()
            completion(sendToken)
        }

        module.output.didFinish = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        bottomSheetViewController.present(fromViewController: sourceViewController)
    }

    func seedClassifications(
        nativeSwapContext: NativeSwapContext,
        tokenizedAssetResolver: NativeSwapTokenizedAssetResolver
    ) {
        seedClassification(
            tokenData: nativeSwapContext.from,
            tokenizedAssetResolver: tokenizedAssetResolver
        )
        seedClassification(
            tokenData: nativeSwapContext.to,
            tokenizedAssetResolver: tokenizedAssetResolver
        )
    }

    func seedClassification(
        tokenData: NativeSwapContext.TokenData,
        tokenizedAssetResolver: NativeSwapTokenizedAssetResolver
    ) {
        guard case let .prefetched(token, category) = tokenData,
              let category
        else {
            return
        }

        tokenizedAssetResolver.setClassification(category, for: token)
    }

    func openConfirmation(
        model: NativeSwapTransactionConfirmationModel,
        onEditFocus: @escaping (Bool?) -> Void
    ) {
        let coordinator = NativeSwapTransactionConfirmationCoordinator(
            wallet: wallet,
            model: model,
            initiatedBy: initiatedBy,
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
