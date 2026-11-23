import AppUI
import PerpsModels
import TKCoordinator
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

final class PerpsFundingCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didRequestAddFunds: ((_ presentingViewController: UIViewController) -> Void)?
    var didRequestAnotherWallet: (() -> Void)?

    private let context: PerpsFlowContext
    private let passcodeProvider: @Sendable () async -> String?
    private let presentSheet: (TKBottomSheetViewController) -> Void
    private let sheetPresenter: @MainActor () async -> UIViewController?
    private var isLeavingForRegion = false
    private let fundingFlow: PerpsFundingFlow

    init(
        router: NavigationControllerRouter,
        context: PerpsFlowContext,
        passcodeProvider: @escaping @Sendable () async -> String?,
        presentSheet: @escaping (TKBottomSheetViewController) -> Void,
        sheetPresenter: @escaping @MainActor () async -> UIViewController?
    ) {
        self.context = context
        self.passcodeProvider = passcodeProvider
        self.presentSheet = presentSheet
        self.sheetPresenter = sheetPresenter
        fundingFlow = PerpsFundingFlow(
            makeDeposit: { [makeDeposit = context.wallet.makeDeposit] in makeDeposit(sheetPresenter) },
            passcodeProvider: passcodeProvider
        )
        super.init(router: router)
    }

    override func start() {
        context.startFundingRecovery()
    }

    private var format: PerpsFormatting {
        context.format
    }

    func openDeposit(from entry: PerpsDepositEntry, on navigationController: UINavigationController? = nil) {
        guard context.dependencies.access != .restricted else {
            presentSheet(PerpsRegionRestrictionSheet.make())
            return
        }
        fundingFlow.startDeposit { [weak self] start in
            guard let self else { return }
            switch start {
            case .unavailable:
                ToastPresenter.showToast(configuration: .init(title: TKLocales.Perps.DepositForm.unavailable))
            case .keyNotKept:
                ToastPresenter.showToast(configuration: .init(title: TKLocales.Perps.Error.generic))
            case let .ready(deposit, passcodeProvider):
                openDeposit(using: deposit, from: entry, on: navigationController, passcodeProvider: passcodeProvider)
            }
        }
    }

    private func openDeposit(
        using deposit: any PerpsDepositing,
        from entry: PerpsDepositEntry,
        on navigationController: UINavigationController?,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) {
        let track = context.wallet.track
        let hasOtherWallets = context.wallet.hasOtherWallets()
        let listing = PerpsDepositSourceListing(load: { await deposit.availableSources() }) {
            track(.depositStarted(eligibleAssetsCount: $0))
        }
        let viewModel = PerpsDepositAmountViewModel(
            config: PerpsFundingAmountConfig(
                flow: "deposit",
                title: TKLocales.Perps.DepositForm.title,
                asset: { deposit.source },
                initialUnit: .token,
                showsAvailable: false,
                fixedUsdPrice: nil,
                loadBalance: { await deposit.loadBalance() },
                loadLimit: { await deposit.loadLimit() },
                limitIsMaxOnly: true,
                loadMinimum: { [format] in
                    try await deposit.loadMinimum().flatMap { minimum in
                        PerpsDepositErrorText.text(for: .belowMinimum(usd: minimum.usd), format: format)
                            .map { PerpsFundingMinimum(amount: minimum.amount, text: $0) }
                    }
                },
                loadPreferredAsset: { await listing.largestHolding },
                selectAsset: { deposit.selectSource(assetId: $0.source.assetId) },
                review: { try await deposit.review(amount: $0) },
                errorText: { [format] in
                    PerpsDepositErrorText.text(for: deposit.message(for: $0), format: format, hasOtherWallets: hasOtherWallets)
                },
                blocksAsset: { deposit.message(for: $0) == .addressBlocked },
                isRegionRestricted: { deposit.message(for: $0) == .regionRestricted },
                quote: { PerpsFundingQuote(deposit: $0.terms) },
                report: { report in
                    switch report {
                    case let .reviewTapped(usdAmount):
                        track(.depositContinueClicked(assetId: deposit.source.assetId, amountUsd: usdAmount))
                    case .refused(.overBalance):
                        track(.depositFailed(.insufficientBalance, on: .amount))
                    case .refused(.belowMinimum):
                        track(.depositFailed(.belowMinimum, on: .amount))
                    case .refused(.addressBlocked):
                        track(.depositFailed(.addressBlocked, on: .amount))
                    case .blockedInBackground:
                        track(.depositFailed(.addressBlocked, on: .background))
                    case .unreadableQuote:
                        track(.depositFailed(.failed, on: .amount))
                    case let .failed(error):
                        if let failure = PerpsDepositFailure(deposit.message(for: error)) {
                            track(.depositFailed(failure, on: .amount))
                        }
                    }
                }
            ),
            format: format,
            loadPendingReview: { try await deposit.pendingReview() },
            pendingNotice: TKLocales.Perps.DepositForm.resumingPayment
        )
        let viewController = PerpsAmountFormViewController(fundingViewModel: viewModel)
        viewModel.onClose = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onAddFunds = { [weak self, weak viewController] in
            guard let viewController else { return }
            self?.didRequestAddFunds?(viewController)
        }
        if hasOtherWallets {
            viewModel.onChooseAnotherWallet = { [weak self] in
                self?.didRequestAnotherWallet?()
            }
        }
        viewModel.onRegionRestricted = { [weak self, weak viewController] in
            self?.leaveForRegionRestriction(from: viewController)
        }
        viewModel.onChooseAsset = { [weak self, weak viewModel, weak viewController] asset in
            guard let self, let viewController else { return }
            chooseFundingAsset(
                selected: asset,
                subtitle: TKLocales.Perps.Funding.convertedToUsd,
                amountViewController: viewController,
                loadOptions: { await deposit.availableSources().options },
                row: { [format] option in
                    Self.assetRow(option, balanceText: option.balance.flatMap { format.fundingBalance($0, symbol: option.source.symbol) })
                },
                onSelect: { option in
                    deposit.selectSource(assetId: option.source.assetId)
                    viewModel?.assetDidChange(balance: option.balance)
                },
                onDismiss: { viewModel?.requestFocusOnAppear() }
            )
        }
        viewModel.onReviewed = { [weak self, weak viewModel, weak viewController] reviewed in
            guard let navigationController = viewController?.navigationController,
                  navigationController.topViewController === viewController else { return }
            self?.openDepositConfirm(
                reviewed: reviewed,
                deposit: deposit,
                from: entry,
                balance: viewModel?.balance,
                on: navigationController,
                passcodeProvider: passcodeProvider
            )
        }
        push(viewController, on: navigationController)
    }

    /// One list load at a time: a second tap while it loads would stack a second sheet.
    /// A pick switches the open screen in place: a fresh screen would slide in over the
    /// closing sheet and start from an empty balance.
    private func chooseFundingAsset(
        selected: PerpsFundingAssetRow,
        subtitle: String?,
        amountViewController: UIViewController,
        loadOptions: @escaping @MainActor () async -> [PerpsDepositSourceOption],
        loadIcon: (@MainActor (String) async -> URL?)? = nil,
        row: @escaping (PerpsDepositSourceOption) -> PerpsFundingAssetRow,
        onSelect: @escaping (PerpsDepositSourceOption) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        fundingFlow.loadAssets(loadOptions) { [weak self, weak amountViewController] options in
            guard let self, let amountViewController,
                  amountViewController.navigationController?.topViewController === amountViewController
            else { return }
            let assets = options.map(row)
            weak var bottomSheet: TKBottomSheetViewController?
            let sheet = TKBottomSheetViewController(
                contentViewController: TKBottomSheetScrollHostingController(
                    title: TKLocales.Multichain.AssetPicker.chooseTitle,
                    subtitle: subtitle,
                    liveSubtitle: nil
                ) {
                    PerpsFundingAssetSheetView(assets: assets, selected: selected, loadIcon: loadIcon) { asset in
                        if asset.assetId != selected.assetId,
                           let option = options.first(where: { $0.source.assetId == asset.assetId })
                        {
                            onSelect(PerpsDepositSourceOption(source: option.source, balance: option.balance.map {
                                PerpsFundingBalance(amount: $0.amount, usdPrice: $0.usdPrice, iconURL: asset.iconURL)
                            }))
                        }
                        if let bottomSheet {
                            bottomSheet.dismiss(completion: onDismiss)
                        } else {
                            onDismiss()
                        }
                    }
                }
            )
            sheet.didClose = { _ in onDismiss() }
            bottomSheet = sheet
            presentSheet(sheet)
        }
    }

    private static func assetRow(_ option: PerpsDepositSourceOption, balanceText: String?) -> PerpsFundingAssetRow {
        PerpsFundingAssetRow(
            assetId: option.source.assetId,
            symbol: option.source.symbol,
            network: option.source.network,
            iconURL: option.balance?.iconURL,
            balanceText: balanceText
        )
    }

    private func openDepositConfirm(
        reviewed: PerpsReviewedDeposit,
        deposit: any PerpsDepositing,
        from entry: PerpsDepositEntry,
        balance: PerpsFundingBalance?,
        on navigationController: UINavigationController?,
        passcodeProvider: @escaping @Sendable () async -> String?
    ) {
        weak var host: UIViewController?
        let consentPresenter = OperationConsentPresenter(host: { host })
        let viewModel = PerpsDepositConfirmViewModel(
            reviewed: reviewed,
            walletName: deposit.walletName,
            source: deposit.source,
            balance: balance,
            format: format,
            message: { deposit.message(for: $0) },
            hasOtherWallets: context.wallet.hasOtherWallets(),
            passcodeProvider: passcodeProvider,
            consent: consentPresenter.consent,
            requote: reviewed.terms.resumesPayment ? nil : { [amount = reviewed.terms.sourceAmount] in
                try await deposit.review(amount: amount)
            }
        )
        let viewController = PerpsTradeConfirmViewController(viewModel: viewModel)
        host = viewController
        viewController.didLeave = consentPresenter.hostDidLeave
        viewModel.onBack = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onClose = { [weak self, weak viewController] in
            self?.dismissFunding(from: viewController)
        }
        viewModel.onConfirmed = { [track = context.wallet.track, assetId = deposit.source.assetId] operationId in
            track(.depositConfirmed(from: entry, assetId: assetId, operationId: operationId))
        }
        viewModel.onFailure = { [weak self, weak viewController, track = context.wallet.track] message in
            if message == .regionRestricted {
                self?.leaveForRegionRestriction(from: viewController)
            }
            if let failure = PerpsDepositFailure(message) {
                track(.depositFailed(failure, on: .confirm))
            }
        }
        viewModel.onPaid = { [weak self, weak viewController] outcome in
            guard let self else { return }
            switch outcome {
            case .authorizationRequired:
                ToastPresenter.showToast(configuration: .init(title: TKLocales.Perps.DepositForm.resumingPayment))
                viewController?.navigationController?.popViewController(animated: true)
                context.refreshFunding()
            case .registered:
                // The deposit is there to trade with: the user stays where it was started.
                dismissFunding(from: viewController)
                ToastPresenter.showToast(configuration: .init(
                    title: TKLocales.Perps.Toast.depositInProgress,
                    dismissRule: .duration(2)
                ))
                context.refreshFunding()
            }
        }
        push(viewController, on: navigationController)
    }

    func openWithdraw() {
        guard let withdraw = context.wallet.makeWithdraw() else {
            PerpsOperationLog.event("entry", outcome: "unavailable", source: "wallet", fields: ["flow": "withdraw"])
            return
        }
        openWithdraw(using: withdraw, on: nil)
    }

    private func openWithdraw(using withdraw: any PerpsWithdrawing, on navigationController: UINavigationController?) {
        let viewModel = PerpsWithdrawAmountViewModel(
            config: PerpsFundingAmountConfig(
                flow: "withdraw",
                title: TKLocales.Perps.WithdrawForm.title,
                // The amount is typed in the Perps balance, USDC bridged in from Ethereum; the row
                // shows the destination instead.
                asset: { PerpsDepositSource(assetId: "lighter/mainnet/usdc", symbol: "USDC", decimals: 6, network: .ethereum) },
                displayAsset: { [format] balance, loaded in
                    let destination = withdraw.destination
                    let option = loaded.flatMap { $0.source.assetId.lowercased() == destination.assetId.lowercased() ? $0 : nil }
                    return PerpsFundingAssetRow(
                        assetId: destination.assetId,
                        symbol: destination.symbol,
                        network: destination.network,
                        iconURL: balance?.iconURL ?? option?.balance?.iconURL,
                        balanceText: option?.balance.flatMap { format.fundingBalance($0, symbol: destination.symbol) }
                    )
                },
                loadDestination: { await withdraw.loadDestination() },
                initialUnit: .usd,
                // The Perps balance is USDC counted as dollars; the other unit is the destination's token.
                fixedUsdPrice: 1,
                loadIcon: { await withdraw.loadIcon(assetId: withdraw.destination.assetId) },
                loadBalance: { await withdraw.loadBalance() },
                loadLimit: nil,
                requiresLimit: true,
                review: { try await withdraw.review(amount: $0) },
                errorText: { PerpsWithdrawErrorText.text(for: withdraw.message(for: $0)) }
            ),
            format: format
        )
        let viewController = PerpsAmountFormViewController(fundingViewModel: viewModel)
        viewModel.onClose = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onChooseAsset = { [weak self, weak viewModel, weak viewController] asset in
            guard let self, let viewController else { return }
            chooseFundingAsset(
                selected: asset,
                subtitle: nil,
                amountViewController: viewController,
                loadOptions: { await withdraw.availableDestinations() },
                loadIcon: { await withdraw.loadIcon(assetId: $0) },
                row: { [format] option in
                    Self.assetRow(option, balanceText: option.balance.flatMap { format.fundingBalance($0, symbol: option.source.symbol) })
                },
                onSelect: { option in
                    withdraw.selectDestination(assetId: option.source.assetId)
                    // The amount is drawn from the Perps balance, which no destination changes.
                    let balance = viewModel?.balance.map {
                        PerpsFundingBalance(amount: $0.amount, usdPrice: $0.usdPrice, iconURL: option.balance?.iconURL)
                    }
                    viewModel?.assetDidChange(balance: balance, destination: option)
                },
                onDismiss: { viewModel?.requestFocusOnAppear() }
            )
        }
        viewModel.onReviewed = { [weak self, weak viewModel, weak viewController] reviewed in
            guard let navigationController = viewController?.navigationController,
                  navigationController.topViewController === viewController else { return }
            self?.openWithdrawConfirm(
                reviewed: reviewed,
                withdraw: withdraw,
                balance: viewModel?.balance,
                on: navigationController
            )
        }
        push(viewController, on: navigationController)
    }

    private func openWithdrawConfirm(
        reviewed: PerpsReviewedWithdraw,
        withdraw: any PerpsWithdrawing,
        balance: PerpsFundingBalance?,
        on navigationController: UINavigationController?
    ) {
        let viewModel = PerpsWithdrawConfirmViewModel(
            reviewed: reviewed,
            destination: withdraw.destination,
            balance: balance,
            format: format,
            message: { withdraw.message(for: $0) },
            passcodeProvider: passcodeProvider,
            requote: reviewed.terms.requestedAmount.map { amount in { try await withdraw.review(amount: amount) } }
        )
        let viewController = PerpsTradeConfirmViewController(viewModel: viewModel)
        viewModel.onBack = { [weak viewController] in
            viewController?.navigationController?.popViewController(animated: true)
        }
        viewModel.onClose = { [weak self, weak viewController] in
            self?.dismissFunding(from: viewController)
        }
        viewModel.onPaid = { [weak self, weak viewController] _ in
            guard let self else { return }
            // The Perps screen follows the withdrawal in its header and opens it in the history.
            dismissFunding(from: viewController)
            context.refreshFunding()
        }
        push(viewController, on: navigationController)
    }

    private func push(_ viewController: UIViewController, on navigationController: UINavigationController?) {
        if let navigationController {
            navigationController.pushViewController(viewController, animated: true)
        } else {
            router.push(viewController: viewController, animated: true)
        }
    }

    /// Back past the amount screen too: the money it was showing is on its way, so
    /// returning to it would invite a second payment. `next` lands on top of where the flow
    /// was opened, so back from it returns there.
    private func dismissFunding(from viewController: UIViewController?) {
        dismissFunding(in: viewController?.navigationController)
    }

    private func dismissFunding(in navigationController: UINavigationController?) {
        guard let navigationController else { return }
        let remaining = navigationController.viewControllers.filter {
            !($0 is PerpsTradeConfirmViewController<PerpsDepositConfirmViewModel>)
                && !($0 is PerpsTradeConfirmViewController<PerpsWithdrawConfirmViewModel>)
                && !($0 is PerpsAmountFormViewController<PerpsDepositAmountViewModel, PerpsFundingAmountView<PerpsDepositAmountViewModel>>)
                && !($0 is PerpsAmountFormViewController<PerpsWithdrawAmountViewModel, PerpsFundingAmountView<PerpsWithdrawAmountViewModel>>)
        }
        navigationController.setViewControllers(remaining, animated: true)
    }

    private func leaveForRegionRestriction(from viewController: UIViewController?) {
        guard !isLeavingForRegion else { return }
        isLeavingForRegion = true
        PerpsOperationLog.event("region_sheet", outcome: "shown", source: "backend", fields: ["flow": "deposit"])
        viewController?.presentedViewController?.dismiss(animated: true)
        Task { [weak self, weak navigationController = viewController?.navigationController] in
            _ = await self?.sheetPresenter()
            self?.dismissFunding(in: navigationController)
            _ = await self?.sheetPresenter()
            self?.presentSheet(PerpsRegionRestrictionSheet.make())
            self?.isLeavingForRegion = false
        }
    }
}

@MainActor
final class PerpsDepositSourceListing {
    private let sources: Task<PerpsDepositSources, Never>
    private var sendStarted: ((Int?) -> Void)?
    private(set) var startTask: Task<Void, Never>?

    init(load: @escaping @MainActor () async -> PerpsDepositSources, sendStarted: @escaping (Int?) -> Void) {
        self.sendStarted = sendStarted
        sources = Task { await load() }
        startTask = Task { [weak self, sources] in
            let listed = await sources.value
            self?.started(eligibleAssetsCount: listed.isFresh ? listed.options.depositableCount : nil)
        }
    }

    deinit {
        sources.cancel()
        sendStarted?(nil)
    }

    var largestHolding: PerpsDepositSourceOption? {
        get async { await sources.value.options.largestHolding }
    }

    private func started(eligibleAssetsCount: Int?) {
        sendStarted?(eligibleAssetsCount)
        sendStarted = nil
    }
}
