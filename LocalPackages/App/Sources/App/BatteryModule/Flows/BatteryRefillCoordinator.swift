import KeeperCore
import SignRaw
import TKCoordinator
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

public final class BatteryRefillCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didOpenRefundURL: ((_ url: URL, _ title: String) -> Void)?

    private weak var walletTransferSignCoordinator: WalletTransferSignCoordinator?

    private var isNeedToOpenRecharge: Bool = false

    private let wallet: Wallet
    private let jettonMasterAddress: Address?
    private let coreAssembly: TKCore.CoreAssembly
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let promocodeStore: BatteryPromocodeStore
    private let batteryCryptoRechargeMethodsProvider: BatteryCryptoRechargeMethodsProvider

    init(
        router: NavigationControllerRouter,
        wallet: Wallet,
        jettonMasterAddress: Address?,
        coreAssembly: TKCore.CoreAssembly,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) {
        self.wallet = wallet
        self.jettonMasterAddress = jettonMasterAddress
        self.coreAssembly = coreAssembly
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.promocodeStore = keeperCoreMainAssembly.batteryAssembly.batteryPromocodeStore()
        self.batteryCryptoRechargeMethodsProvider = BatteryCryptoRechargeMethodsProvider(
            wallet: wallet,
            balanceService: keeperCoreMainAssembly.servicesAssembly.balanceService(),
            batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
            jettonService: keeperCoreMainAssembly.servicesAssembly.jettonService()
        )
        super.init(router: router)
    }

    override public func start(deeplink: (any CoordinatorDeeplink)? = nil) {
        openBatteryRefill()
    }

    public func handleTonkeeperPublishDeeplink(sign: Data) -> Bool {
        guard let walletTransferSignCoordinator = walletTransferSignCoordinator else { return false }
        walletTransferSignCoordinator.externalSignHandler?(sign)
        walletTransferSignCoordinator.externalSignHandler = nil
        return true
    }

    func didAppear() {
        if isNeedToOpenRecharge {
            isNeedToOpenRecharge = false
            openBatteryRechargeIfNeeded(rechargeMethodsProvider: batteryCryptoRechargeMethodsProvider, promocodeStore: promocodeStore)
        }
    }
}

private extension BatteryRefillCoordinator {
    func openBatteryRefill() {
        let module = BatteryRefillAssembly.module(
            wallet: wallet,
            promocodeStore: promocodeStore,
            rechargeMethodsProvider: batteryCryptoRechargeMethodsProvider,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        module.output.didTapSupportedTransactions = { [weak self] in
            guard let self else { return }
            openSupportedTransactions(wallet: wallet)
        }

        module.output.didTapTransactionsSettings = { [weak self] in
            self?.openTransactionsSettings()
        }

        module.output.didFinish = { [weak self] in
            self?.didFinish?(self)
        }

        module.output.didTapRecharge = { [weak self] rechargeMethod in
            guard let self else { return }
            openRecharge(item: rechargeMethod, promocodeStore: promocodeStore)
        }

        module.output.didOpenRefundURL = { [weak self] url, title in
            self?.didOpenRefundURL?(url, title)
        }

        router.push(viewController: module.view, animated: false, completion: { [weak self] in
            guard let self else { return }
            guard router.rootViewController.presentingViewController != nil else {
                self.isNeedToOpenRecharge = true
                return
            }

            openBatteryRechargeIfNeeded(
                rechargeMethodsProvider: batteryCryptoRechargeMethodsProvider,
                promocodeStore: promocodeStore
            )
        })
    }

    func openSupportedTransactions(wallet: Wallet) {
        let module = BatteryRefillSupportedTransactionsAssembly.module(
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        router.push(viewController: module.view)
    }

    func openTransactionsSettings() {
        let module = BatteryRefillTransactionsSettingsAssembly.module(
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        router.push(viewController: module.view)
    }

    func openRecharge(
        item: BatteryRefillRechargeMethodsModel.RechargeMethodItem,
        promocodeStore: BatteryPromocodeStore
    ) {
        let rechargeToken: TonToken
        let isGift: Bool
        switch item {
        case let .token(token):
            rechargeToken = token
            isGift = false
        case let .gift(token):
            rechargeToken = token
            isGift = true
        }

        let module = BatteryRechargeAssembly.module(
            wallet: wallet,
            token: rechargeToken,
            isGift: isGift,
            promocodeStore: promocodeStore,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        module.output.didTapContinue = { [weak self] payload in
            self?.openConfirmation(payload: payload)
        }

        weak let moduleInput = module.input
        module.output.didSelectTokenPicker = { [weak self] in
            self?.openTokenPicker(token: $0, completion: { token in
                moduleInput?.setToken(token: token)
            })
        }

        router.present(module.view)
    }

    func openConfirmation(payload: BatteryRechargePayload) {
        guard let windowScene = router.rootViewController.windowScene else { return }

        let batteryRechargeSignRawBuilder = BatteryRechargeSignRawBuilder(
            wallet: wallet,
            payload: payload,
            batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService(),
            sendService: keeperCoreMainAssembly.servicesAssembly.sendService(),
            tonProofTokenService: keeperCoreMainAssembly.servicesAssembly.tonProofTokenService(),
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration
        )

        SignRawPresenter.presentSignRaw(
            windowScene: windowScene,
            windowLevel: .signRaw,
            wallet: wallet,
            transferProvider: { try await batteryRechargeSignRawBuilder.getSignRawRequest() },
            resultHandler: nil,
            sendFrom: .tonconnectRemote,
            coreAssembly: coreAssembly,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            didRequireSign: { [weak self] transferData, wallet, coordinator, router throws(WalletTransferSignError) in
                guard let self else {
                    throw .cancelled
                }
                return try await didRequireSign(
                    transferData: transferData,
                    wallet: wallet,
                    coordinator: coordinator,
                    router: router
                )
            }
        )
    }

    func openTokenPicker(token: TonToken, completion: @escaping (TonToken) -> Void) {
        let model = BatteryTokenPickerModel(
            wallet: wallet,
            selectedToken: token,
            balanceStore: keeperCoreMainAssembly.storesAssembly.convertedBalanceStore,
            batteryService: keeperCoreMainAssembly.batteryAssembly.batteryService()
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
            switch token {
            case .tronUSDT: break
            case let .ton(token):
                completion(token)
            }
        }

        module.output.didFinish = { [weak bottomSheetViewController] in
            bottomSheetViewController?.dismiss()
        }

        bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())
    }

    @MainActor
    func didRequireSign(
        transferData: TransferData,
        wallet: Wallet,
        coordinator: Coordinator,
        router: ViewControllerRouter
    ) async throws(WalletTransferSignError) -> SignedTransactions {
        let signCoordinator = WalletTransferSignCoordinator(
            router: router,
            wallet: wallet,
            transferData: transferData,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )

        self.walletTransferSignCoordinator = signCoordinator

        return try await signCoordinator
            .handleSign(parentCoordinator: coordinator)
            .get()
    }

    @MainActor
    func openBatteryRechargeIfNeeded(
        rechargeMethodsProvider: BatteryCryptoRechargeMethodsProvider,
        promocodeStore: BatteryPromocodeStore
    ) {
        guard let jettonMasterAddress else { return }
        ToastPresenter.showToast(configuration: .loading)

        Task {
            guard let item = await rechargeMethodsProvider.getRechargeMethod(jettonMasterAddress: jettonMasterAddress) else {
                ToastPresenter.hideAll()
                ToastPresenter.showToast(configuration: .failed)
                return
            }

            ToastPresenter.hideAll()
            openRecharge(item: item, promocodeStore: promocodeStore)
        }
    }
}
