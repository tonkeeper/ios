import BigInt
import KeeperCore
import TKCoordinator
import TKCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

/// In-app placement a deeplink was opened from, when it is not derivable from the deeplink itself.
enum DeeplinkOrigin {
    case app
    case banner
}

/// Outcome of a send deeplink that cannot reach the send form, thrown so every handler reports it
/// the same way.
enum SendDeeplinkFailure: Error {
    case scamRecipient
    case invalidRecipient
    case unsupported
    case assetUnavailable
}

func modalFlowNavigationController(rootViewController: UIViewController) -> UINavigationController? {
    if let navigationController = rootViewController as? UINavigationController {
        return navigationController
    }
    if let tabBarController = rootViewController as? UITabBarController {
        return tabBarController.selectedViewController as? UINavigationController
    }
    return rootViewController.navigationController
}

extension MainCoordinator {
    func migrationSource(fromStories: Bool, origin: DeeplinkOrigin) -> MigrationSource {
        if fromStories {
            return .story
        }
        switch origin {
        case .banner: return .banner
        case .app: return .deeplink
        }
    }

    func openSendDeeplink(
        transfer: Deeplink.TransferData,
        sendSource: SendAnalyticsSource
    ) {
        runSendDeeplinkTask(expirationTimestamp: transfer.expirationTimestamp, sendSource: sendSource) { wallet in
            try await self.handleSendDeeplink(
                transfer: transfer,
                wallet: wallet,
                sendSource: sendSource
            )
        }
    }

    func openMultichainSendDeeplink(
        candidates: MultichainRecipientCandidates,
        sendSource: SendAnalyticsSource
    ) {
        runSendDeeplinkTask(expirationTimestamp: nil, sendSource: sendSource) { wallet in
            try await self.handleMultichainSendDeeplink(
                candidates: candidates,
                wallet: wallet,
                sendSource: sendSource
            )
        }
    }

    func openEvmSendDeeplink(
        transfer: Deeplink.EvmTransferData,
        sendSource: SendAnalyticsSource
    ) {
        runSendDeeplinkTask(expirationTimestamp: nil, sendSource: sendSource) { wallet in
            try await self.handleEvmSendDeeplink(
                transfer: transfer,
                wallet: wallet,
                sendSource: sendSource
            )
        }
    }

    private func runSendDeeplinkTask(
        expirationTimestamp: Int64?,
        sendSource: SendAnalyticsSource,
        handle: @escaping @Sendable (Wallet) async throws -> Void
    ) {
        deeplinkHandleTask?.cancel()

        ToastPresenter.hideAll()
        ToastPresenter.showToast(configuration: .loading)

        if let expirationTimestamp {
            let expirationDate = Date(timeIntervalSince1970: TimeInterval(expirationTimestamp))
            guard Date() <= expirationDate else {
                let configuration = ToastPresenter.Configuration(title: TKLocales.Toast.linkExpired)
                ToastPresenter.hideAll()
                ToastPresenter.showToast(configuration: configuration)
                return
            }
        }

        let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore
        let entrySource = depositAnalyticsSource(for: sendSource)

        let deeplinkHandleTask = Task {
            do {
                let wallet = try walletsStore.activeWallet
                try await handle(wallet)
            } catch InsufficientFundsError.unknownJetton {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.deeplinkHandleTask = nil
                    ToastPresenter.hideAll()
                    ToastPresenter.showToast(
                        configuration: ToastPresenter.Configuration(
                            title: TKLocales.InsufficientFunds.unknownToken,
                            dismissRule: .default
                        )
                    )
                }
            } catch let InsufficientFundsError.insufficientFunds(jettonInfo, balance, requiredAmount, wallet, isInternalPurchasing) {
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    self?.deeplinkHandleTask = nil

                    ToastPresenter.hideAll()

                    self?.configureAndShowInsufficientPopup(
                        wallet: wallet,
                        buttonTitle: TKLocales.InsufficientFunds.rechargeWallet,
                        amount: requiredAmount,
                        tokenSymbol: jettonInfo?.symbol ?? jettonInfo?.name,
                        fractionDigits: jettonInfo?.fractionDigits ?? 2,
                        balance: balance,
                        isInternalPurchasing: isInternalPurchasing,
                        entrySource: entrySource
                    )
                }
            } catch let InsufficientFundsError.blockchainFee(wallet, balance, amount) {
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    self?.deeplinkHandleTask = nil

                    ToastPresenter.hideAll()

                    guard let self else {
                        return
                    }

                    let tonToken = TonToken.ton
                    let amountFormatter = self.keeperCoreMainAssembly.formattersAssembly.amountFormatter
                    let feeFormatted = amountFormatter.format(amount: amount, fractionDigits: tonToken.fractionDigits)
                    let balanceFormatted = amountFormatter.format(amount: balance, fractionDigits: tonToken.fractionDigits)
                    let caption = TKLocales.InsufficientFunds.feeRequired(feeFormatted, balanceFormatted)
                    let buttonTitle = TKLocales.InsufficientFunds.buyTokenTitle(tonToken.symbol)

                    self.configureAndShowInsufficientPopup(
                        wallet: wallet,
                        caption: caption,
                        buttonTitle: buttonTitle,
                        amount: amount,
                        tokenSymbol: tonToken.symbol,
                        fractionDigits: tonToken.fractionDigits,
                        balance: balance,
                        isInternalPurchasing: true,
                        entrySource: entrySource
                    )
                }
            } catch let failure as SendDeeplinkFailure {
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    self?.deeplinkHandleTask = nil
                    ToastPresenter.hideAll()
                    self?.showSendDeeplinkFailure(failure)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.deeplinkHandleTask = nil
                    ToastPresenter.hideAll()
                    ToastPresenter.showToast(configuration: .failed)
                }
            }
        }

        self.deeplinkHandleTask = deeplinkHandleTask
    }

    private func showSendDeeplinkFailure(_ failure: SendDeeplinkFailure) {
        switch failure {
        case .scamRecipient:
            ToastPresenter.showToast(configuration: .init(title: TKLocales.Send.scamAddress))
        case .invalidRecipient:
            ToastPresenter.showToast(configuration: .init(title: TKLocales.Send.invalidAddress))
        case .unsupported:
            ToastPresenter.showToast(configuration: .failed)
        case .assetUnavailable:
            showMultichainSendLoadError()
        }
    }

    /// `asset_id` wins over `jetton`; with neither, the asset is picked in the send flow instead of
    /// defaulting to TON — the chains offered are the ones the recipient address is valid on.
    private func handleSendDeeplink(
        transfer: Deeplink.TransferData,
        wallet: Wallet,
        sendSource: SendAnalyticsSource
    ) async throws {
        guard let multichainState = multichainSendState(for: wallet) else {
            try await handleLegacyWalletSendDeeplink(
                transfer: transfer,
                wallet: wallet,
                sendSource: sendSource
            )
            return
        }

        if let assetId = transfer.assetId {
            try await handlePinnedAssetSendDeeplink(
                transfer: transfer,
                assetId: assetId,
                wallet: wallet,
                multichainState: multichainState,
                sendSource: sendSource
            )
            return
        }

        if transfer.jettonAddress != nil {
            try await handleLegacyWalletSendDeeplink(
                transfer: transfer,
                wallet: wallet,
                sendSource: sendSource
            )
            return
        }

        try await handleAssetPickerSendDeeplink(
            transfer: transfer,
            wallet: wallet,
            multichainState: multichainState,
            sendSource: sendSource
        )
    }

    private func handleLegacyWalletSendDeeplink(
        transfer: Deeplink.TransferData,
        wallet: Wallet,
        sendSource: SendAnalyticsSource
    ) async throws {
        let recipient = try await recipientResolver.resolverRecipient(
            string: transfer.recipient,
            network: wallet.network
        )

        let plan = LegacySendDeeplinkPlan(
            assetId: transfer.assetId,
            jettonAddress: transfer.jettonAddress,
            amount: transfer.amount,
            recipientChain: recipient.isTon ? .ton : .tron
        )

        try await handleLegacySendDeeplink(
            recipient: recipient,
            wallet: wallet,
            amount: plan.amount,
            jettonAddress: plan.jettonAddress,
            comment: transfer.comment,
            successReturn: transfer.successReturn,
            sendSource: sendSource
        )
    }

    private func handlePinnedAssetSendDeeplink(
        transfer: Deeplink.TransferData,
        assetId: String,
        wallet: Wallet,
        multichainState: MultichainWalletState,
        sendSource: SendAnalyticsSource
    ) async throws {
        guard let input = await multichainSendInput(
            wallet: wallet,
            multichainState: multichainState,
            assetId: assetId,
            amount: transfer.amount ?? 0
        ),
            let chain = input.item.asset.asset.chain,
            multichainState.addresses.contains(where: { $0.chain == chain })
        else {
            throw SendDeeplinkFailure.assetUnavailable
        }

        let recipient = try await resolveMultichainRecipient(
            transfer.recipient,
            chain: chain,
            wallet: wallet
        )

        finishSendDeeplinkTask {
            self.openMultichainSend(
                wallet: wallet,
                multichainState: multichainState,
                entry: .enterAmount(input),
                sendSource: sendSource,
                recipient: recipient,
                comment: transfer.comment,
                successReturn: transfer.successReturn
            )
        }
    }

    /// The amount is left behind: without a pinned asset it is denominated in a token the user has
    /// not chosen yet, so it must not land on whatever they pick.
    private func handleAssetPickerSendDeeplink(
        transfer: Deeplink.TransferData,
        wallet: Wallet,
        multichainState: MultichainWalletState,
        sendSource: SendAnalyticsSource
    ) async throws {
        if let candidates = MultichainRecipientCandidates(string: transfer.recipient),
           !candidates.chains.contains(.ton)
        {
            try await handleMultichainSendDeeplink(
                candidates: candidates,
                wallet: wallet,
                sendSource: sendSource,
                comment: transfer.comment,
                successReturn: transfer.successReturn
            )
            return
        }

        // A TON address or a domain becomes a recipient only through the resolver, which is also
        // where scam recipients are rejected. The resolved recipient goes to the picker as it is:
        // rebuilding it from its address alone would drop the DNS name the form and the
        // confirmation screen display.
        let recipient = try await resolveMultichainRecipient(
            transfer.recipient,
            chain: .ton,
            wallet: wallet
        )
        guard multichainState.addresses.contains(where: { $0.chain == .ton }) else {
            throw SendDeeplinkFailure.invalidRecipient
        }

        finishSendDeeplinkTask {
            self.openMultichainSend(
                wallet: wallet,
                multichainState: multichainState,
                entry: .tokenPicker(allowedChains: [.ton], initialChain: .ton),
                sendSource: sendSource,
                recipient: recipient,
                comment: transfer.comment,
                successReturn: transfer.successReturn
            )
        }
    }

    private func resolveMultichainRecipient(
        _ string: String,
        chain: MultichainChain,
        wallet: Wallet
    ) async throws -> MultichainRecipient {
        guard chain == .ton else {
            guard let recipient = MultichainRecipient(string: string, chain: chain, network: wallet.network) else {
                throw SendDeeplinkFailure.invalidRecipient
            }
            return recipient
        }

        let resolved = try await recipientResolver.resolverRecipient(
            string: string,
            network: wallet.network
        )
        guard case let .ton(tonRecipient) = resolved else {
            throw SendDeeplinkFailure.invalidRecipient
        }
        guard !tonRecipient.isScam else {
            throw SendDeeplinkFailure.scamRecipient
        }
        return MultichainRecipient(
            chain: .ton,
            address: tonRecipient.recipientAddress.addressString,
            domain: tonRecipient.recipientAddress.name
        )
    }

    private func handleLegacySendDeeplink(
        recipient: LegacyRecipient,
        wallet: Wallet,
        amount: BigUInt?,
        jettonAddress: Address?,
        comment: String?,
        successReturn: URL?,
        sendSource: SendAnalyticsSource
    ) async throws {
        if recipient.isScam {
            throw SendDeeplinkFailure.scamRecipient
        }

        var token: SendV3Item = .ton(.token(.ton, amount: 0))

        switch recipient {
        case let .ton(tonRecipient):
            if let jettonAddress {
                let fundsValidator = keeperCoreMainAssembly.loadersAssembly.insufficientFundsValidator()
                let jettonBalance = try await fundsValidator.resolveJettonBalance(
                    jettonAddress: jettonAddress, requiredAmount: amount ?? 0, wallet: wallet
                )

                let jettonTransferController = keeperCoreMainAssembly.jettonTransferTransactionConfirmationController(
                    wallet: wallet,
                    recipient: tonRecipient,
                    jettonItem: jettonBalance.item,
                    amount: amount ?? 0,
                    comment: nil
                )

                try await fundsValidator.validateFundsIfNeeded(
                    wallet: wallet,
                    confirmationController: jettonTransferController
                )

                token = .ton(.token(.jetton(jettonBalance.item), amount: amount ?? 0))
            } else {
                token = .ton(.token(.ton, amount: amount ?? 0))
            }

        case .tron:
            guard wallet.tron != nil else {
                throw SendDeeplinkFailure.unsupported
            }
            token = .tron(TronSendData.Item.usdt(amount: amount ?? 0))
        }

        guard !Task.isCancelled else { return }
        await MainActor.run {
            self.deeplinkHandleTask = nil
            ToastPresenter.hideAll()
            self.openSendResolvingMultichain(
                wallet: wallet,
                sendInput: .direct(item: token),
                sendSource: sendSource,
                recipient: recipient,
                comment: comment,
                successReturn: successReturn
            )
        }
    }

    private func handleMultichainSendDeeplink(
        candidates: MultichainRecipientCandidates,
        wallet: Wallet,
        sendSource: SendAnalyticsSource,
        comment: String? = nil,
        successReturn: URL? = nil
    ) async throws {
        let multichainState = multichainSendState(for: wallet)
        let resolution = MultichainSendRecipientResolver().resolveDeeplink(
            candidates: candidates,
            walletChains: multichainState.map { $0.addresses.map(\.chain) },
            network: wallet.network
        )

        switch resolution {
        case let .send(recipient, availableChains):
            guard let multichainState else {
                throw SendDeeplinkFailure.assetUnavailable
            }
            finishSendDeeplinkTask {
                self.openMultichainSend(
                    wallet: wallet,
                    multichainState: multichainState,
                    entry: .tokenPicker(
                        allowedChains: availableChains,
                        initialChain: recipient.chain
                    ),
                    sendSource: sendSource,
                    recipient: recipient,
                    comment: comment,
                    successReturn: successReturn
                )
            }
        case .legacy:
            let legacyRecipient = try await recipientResolver.resolverRecipient(
                string: candidates.address,
                network: wallet.network
            )
            try await handleLegacySendDeeplink(
                recipient: legacyRecipient,
                wallet: wallet,
                amount: nil,
                jettonAddress: nil,
                comment: comment,
                successReturn: successReturn,
                sendSource: sendSource
            )
        case .unsupported:
            throw SendDeeplinkFailure.invalidRecipient
        }
    }

    private func handleEvmSendDeeplink(
        transfer: Deeplink.EvmTransferData,
        wallet: Wallet,
        sendSource: SendAnalyticsSource
    ) async throws {
        guard let multichainState = multichainSendState(for: wallet) else {
            throw SendDeeplinkFailure.invalidRecipient
        }

        let assetResolver = MultichainSendAssetResolver(
            multichainAssetBalanceProvider: keeperCoreMainAssembly.multichainAssembly.multichainAssetBalanceProvider,
            assetDetailsService: keeperCoreMainAssembly.servicesAssembly.assetDetailsService()
        )
        let probeController = EvmSendAssetProbeController(
            resolveAsset: { await assetResolver.resolveAsset(for: $0, multichainState: $1) },
            isTransferSupported: keeperCoreMainAssembly.multichainAssembly.chainKitService.isTransferSupported(asset:)
        )

        let resolution = await probeController.resolve(
            transfer: transfer,
            multichainState: multichainState
        )

        switch resolution {
        case let .send(asset, chain):
            finishSendDeeplinkTask {
                self.openMultichainSend(
                    wallet: wallet,
                    multichainState: multichainState,
                    entry: .enterAmount(
                        MultichainSendInput(
                            item: MultichainSendItem(asset: asset, amount: transfer.amount ?? 0)
                        )
                    ),
                    sendSource: sendSource,
                    recipient: MultichainRecipient(chain: chain, address: transfer.recipient),
                    comment: nil
                )
            }
        case let .picker(allowedChains):
            // The picked asset decides the chain, and the send form re-resolves the recipient onto
            // it — the seed chain only has to be one the address is valid on.
            let seedChain = MultichainChain.allCases.first(where: allowedChains.contains)
            finishSendDeeplinkTask {
                self.openMultichainSend(
                    wallet: wallet,
                    multichainState: multichainState,
                    entry: .tokenPicker(allowedChains: allowedChains, initialChain: nil),
                    sendSource: sendSource,
                    recipient: seedChain.map { MultichainRecipient(chain: $0, address: transfer.recipient) },
                    comment: nil
                )
            }
        case .assetUnavailable:
            throw SendDeeplinkFailure.assetUnavailable
        case .unsupported:
            throw SendDeeplinkFailure.invalidRecipient
        }
    }

    private func finishSendDeeplinkTask(_ completion: () -> Void) {
        guard !Task.isCancelled else { return }
        deeplinkHandleTask = nil
        ToastPresenter.hideAll()
        completion()
    }

    private func configureAndShowInsufficientPopup(
        wallet: Wallet,
        caption: String? = nil,
        buttonTitle: String,
        amount: BigUInt?,
        tokenSymbol: String?,
        fractionDigits: Int,
        balance: BigUInt,
        isInternalPurchasing: Bool,
        entrySource: DepositAnalyticsSource
    ) {
        var buyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        buyButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(buttonTitle)
        )
        buyButtonConfiguration.action = { [weak self] in
            self?.router.dismiss(animated: true) {
                self?.openBuy(
                    wallet: wallet,
                    isInternalPurchasing: isInternalPurchasing,
                    entrySource: entrySource
                )
            }
        }

        let builder = InfoPopupBottomSheetConfigurationBuilder(
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )
        let configuration = builder.insufficientTokenConfiguration(
            walletLabel: wallet.metaData.label,
            caption: caption,
            tokenSymbol: tokenSymbol ?? TonToken.ton.symbol,
            tokenFractionalDigits: fractionDigits,
            required: amount ?? 0,
            available: balance,
            buttons: [buyButtonConfiguration]
        )

        openInsufficientFundsPopup(configuration: configuration)
    }

    func openSignRawSendDeeplink(
        recipient: String,
        jettonMaster: Address?,
        amount: BigUInt?,
        bin: String?,
        stateInit: String?,
        expirationTimestamp: Int64?,
        sendSource: SendAnalyticsSource
    ) {
        deeplinkHandleTask?.cancel()

        ToastPresenter.hideAll()
        ToastPresenter.showToast(configuration: .loading)

        if let expirationTimestamp {
            let expirationDate = Date(
                timeIntervalSince1970: TimeInterval(expirationTimestamp)
            )
            guard Date() <= expirationDate else {
                let configuration = ToastPresenter.Configuration(title: TKLocales.Toast.linkExpired)
                ToastPresenter.hideAll()
                ToastPresenter.showToast(configuration: configuration)
                return
            }
        }

        let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore

        let deeplinkHandleTask = Task {
            do {
                let wallet = try walletsStore.activeWallet

                let recipient = try await self.recipientResolver.resolverTonRecipient(string: recipient, network: wallet.network)

                guard let amount = amount else { return }

                var jettonTransferBin: String?
                var jettonRecipient: TonRecipient?

                if let jettonMaster {
                    let jettonWallet = try await keeperCoreMainAssembly.servicesAssembly
                        .blockchainService().getWalletAddress(
                            jettonMaster: jettonMaster.toRaw(),
                            owner: wallet.address.toRaw(),
                            network: wallet.network
                        )
                    jettonRecipient = try await self.recipientResolver
                        .resolverTonRecipient(
                            string: jettonWallet.toRaw(),
                            network: wallet.network
                        )

                    let builder = Builder()
                    try JettonTransferData(
                        queryId: UInt64(UnsignedTransferBuilder.newWalletQueryId()),
                        amount: amount,
                        toAddress: recipient.recipientAddress.address,
                        responseAddress: wallet.address,
                        forwardAmount: BigUInt(stringLiteral: "1"),
                        forwardPayload: bin.map {
                            try Cell.fromBase64(src: $0.fixBase64())
                        },
                        customPayload: nil
                    ).storeTo(builder: builder)

                    jettonTransferBin = try builder.endCell().toBoc()
                        .base64EncodedString()
                }

                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.deeplinkHandleTask = nil
                    ToastPresenter.hideAll()
                    self.openTransferSignRaw(
                        wallet: wallet,
                        recipient: jettonRecipient ?? recipient,
                        amount: jettonRecipient != nil ? BigUInt(stringLiteral: "50000000") : amount,
                        payload: jettonTransferBin ?? bin,
                        stateInit: stateInit,
                        sendFrom: .tonconnectRemote,
                        initiatedBy: sendSource.initiatedBy,
                        utm: sendSource.utm
                    )
                }
            } catch {
                await MainActor.run {
                    self.deeplinkHandleTask = nil
                    ToastPresenter.hideAll()
                    ToastPresenter.showToast(configuration: .failed)
                }
            }
        }

        self.deeplinkHandleTask = deeplinkHandleTask
    }

    func openRampDeeplink(
        flow: RampFlow,
        parameters: RampDeeplinkParameters,
        entrySource: DepositAnalyticsSource,
        utm: UtmParameters
    ) {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }

        switch flow {
        case .deposit:
            openDeposit(
                wallet: wallet,
                entrySource: entrySource,
                initialDeeplink: parameters,
                utm: utm
            )
        case .withdraw:
            openWithdraw(
                wallet: wallet,
                entrySource: entrySource,
                initialDeeplink: parameters,
                utm: utm
            )
        }
    }

    func openStakingDeeplink(utm: UtmParameters) {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }
        guard !keeperCoreMainAssembly.configurationAssembly.configuration.flag(\.stakingDisabled, network: wallet.network) else { return }
        openStake(wallet: wallet, initiatedBy: .deepLink, utm: utm)
    }

    func openPoolDetailsDeeplink(poolAddress: Address, utm: UtmParameters) {
        deeplinkHandleTask?.cancel()

        ToastPresenter.hideAll()
        ToastPresenter.showToast(configuration: .loading)

        let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore
        let stakingService = keeperCoreMainAssembly.servicesAssembly.stackingService()
        let stakingStore = keeperCoreMainAssembly.storesAssembly.stackingPoolsStore

        let deeplinkHandleTask = Task {
            do {
                let wallet = try walletsStore.activeWallet
                let stakingPools = try await stakingService.loadStakingPools(wallet: wallet)
                await stakingStore.setStackingPools(stakingPools, wallet: wallet)
                guard let stakingPool = stakingPools.first(where: { $0.address == poolAddress }) else {
                    await MainActor.run {
                        self.deeplinkHandleTask = nil
                        ToastPresenter.hideAll()
                        ToastPresenter.showToast(configuration: .failed)
                    }
                    return
                }
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.deeplinkHandleTask = nil
                    ToastPresenter.hideAll()
                    self.router.dismiss(animated: true) { [weak self = self] in
                        self?.openStakingItemDetails(
                            wallet: wallet,
                            stakingPoolInfo: stakingPool,
                            initiatedBy: .deepLink,
                            utm: utm
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    self.deeplinkHandleTask = nil
                    ToastPresenter.hideAll()
                    ToastPresenter.showToast(configuration: .failed)
                }
                return
            }
        }

        self.deeplinkHandleTask = deeplinkHandleTask
    }

    func handleDappDeeplink(url: URL, analyticsFrom: DappOpenSource = .deepLink, utm: UtmParameters = .empty) -> Bool {
        deeplinkHandleTask?.cancel()
        ToastPresenter.hideAll()
        ToastPresenter.showToast(configuration: .loading)

        let task = Task { [weak self] in
            defer {
                ToastPresenter.hideAll()
            }
            guard let self else { return }
            let browserController = keeperCoreMainAssembly.browserExploreController()
            let lang = Locale.current.languageCode ?? "en"

            let getApp: (URL, PopularAppsResponseData) -> PopularApp? = { url, data in
                if let app = data.apps.first(with: url.host, at: \.url?.host) {
                    return app
                } else if let app = data.categories
                    .first(where: { $0.apps.contains(with: url.host, at: \.url?.host) })?
                    .apps.first(with: url.host, at: \.url?.host)
                {
                    return app
                } else {
                    return nil
                }
            }

            let appSettings = coreAssembly.appSettings
            let catalogMode: DappCatalogMode = .multichain
            if let popularAppsResponse = try? await browserController.loadPopularApps(lang: lang),
               let app = getApp(url, popularAppsResponse)
            {
                openDapp(
                    popularApp: app,
                    url: url,
                    analyticsFrom: analyticsFrom,
                    catalogMode: catalogMode,
                    utm: utm
                )
            } else if
                let host = url.host,
                appSettings.isDappOpenWarningDoNotShow(host) || appSettings.dappHostWhiteList.contains(host)
            {
                openDapp(title: nil, url: url, analyticsFrom: analyticsFrom, utm: utm)
            } else {
                ToastPresenter.hideAll()
                let warningModule = OpenDappWarningPopupAssembly.module(
                    url: url,
                    keeperCoreAssembly: keeperCoreMainAssembly,
                    coreAssembly: coreAssembly
                )
                let bottomSheetViewController = TKBottomSheetViewController(contentViewController: warningModule.view)

                warningModule.output.didTapOpen = { [weak bottomSheetViewController] url, title in
                    bottomSheetViewController?.dismiss { [weak self = self] in
                        self?.openDapp(title: title, url: url, analyticsFrom: analyticsFrom, utm: utm)
                    }
                }

                bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())
            }
        }

        deeplinkHandleTask = task
        return true
    }

    /// Catalog asset ids are multichain-only; legacy swaps fall back to defaults.
    func openSwapDeeplink(fromToken: String?, toToken: String?, utm: UtmParameters) {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }

        let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
        let carriesCatalogAssetIds = MultichainSwapInitialAssetSelection.isCatalogAssetId(fromToken)
            || MultichainSwapInitialAssetSelection.isCatalogAssetId(toToken)

        if configuration.flag(\.nativeSwapDisabled, network: wallet.network) {
            openWebSwap(
                wallet: wallet,
                fromToken: carriesCatalogAssetIds ? nil : fromToken,
                toToken: carriesCatalogAssetIds ? nil : toToken,
                initiatedBy: .deepLink,
                utm: utm
            )
            return
        }

        if let multichainState = wallet.multichainWalletState {
            openMultichainSwap(
                wallet: wallet,
                multichainState: multichainState,
                nativeSwapContext: NativeSwapContext(utm: utm),
                initialSelection: MultichainSwapInitialAssetSelection(
                    deeplinkSendAssetId: fromToken,
                    deeplinkReceiveAssetId: toToken
                ),
                initiatedBy: .deepLink
            )
            return
        }

        openNativeSwap(
            wallet: wallet,
            nativeSwapContext: NativeSwapContext(
                fromTokenSymbol: carriesCatalogAssetIds ? nil : fromToken,
                toTokenSymbol: carriesCatalogAssetIds ? nil : toToken,
                utm: utm
            ),
            initiatedBy: .deepLink
        )
    }

    func openActionDeeplink(eventId: String) {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil

        let service = keeperCoreMainAssembly.servicesAssembly.historyService()
        let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore

        ToastPresenter.hideAll()
        ToastPresenter.showToast(configuration: .loading)

        let deeplinkHandleTask = Task {
            do {
                let wallet = try walletsStore.activeWallet
                let event = try await service.loadEvent(wallet: wallet, eventId: eventId)
                guard let action = event.actions.first else {
                    await MainActor.run {
                        self.deeplinkHandleTask = nil
                        ToastPresenter.hideAll()
                        ToastPresenter.showToast(configuration: .failed)
                    }
                    return
                }

                await MainActor.run {
                    self.deeplinkHandleTask = nil
                    ToastPresenter.hideAll()
                    self.openHistoryEventDetails(
                        wallet: wallet,
                        event: AccountEventDetailsEvent(
                            accountEvent: event,
                            action: action
                        ),
                        network: wallet.network,
                        fromViewController: nil
                    )
                }
            } catch {
                await MainActor.run {
                    self.deeplinkHandleTask = nil
                    ToastPresenter.hideAll()
                    ToastPresenter.showToast(configuration: .failed)
                }
            }
        }

        self.deeplinkHandleTask = deeplinkHandleTask
    }

    func openReceiveDeeplink() {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }
        openReceive(tokens: getRampTokens(wallet: wallet), wallet: wallet)
    }

    func openBackupDeeplink() {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }

        openBackup(wallet: wallet, source: .deepLink)
    }

    func openAddWalletDeeplink() {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil
        openAddWallet(router: ViewControllerRouter(rootViewController: router.rootViewController))
    }

    func openMysteryRaffleDeeplink() {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil

        guard
            let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
            case .multichain = wallet.multichain
        else {
            return
        }

        let raffleStore = keeperCoreMainAssembly.storesAssembly.raffleStore
        guard raffleStore.getState().isEmpty else {
            openMysteryRaffle(source: .deepLink)
            return
        }

        MysteryRaffleCoordinator.presentLoading(
            from: self,
            rootViewController: router.rootViewController,
            source: .deepLink,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            openDeeplink: { [weak self] in self?.handleRaffleDeeplink($0) },
            openMigration: { [weak self] onFinish in
                self?.openMigrationDeeplink(source: .raffle, onFinish: onFinish)
            }
        )
    }

    func openMigrationDeeplink(source: MigrationSource, onFinish: (() -> Void)? = nil) {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet,
              wallet.isMultichain,
              let navigationController = modalFlowNavigationController(rootViewController: router.rootViewController)
        else {
            onFinish?()
            return
        }

        let coordinator = WalletMigrationCoordinator(
            wallet: wallet,
            source: source,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: NavigationControllerRouter(rootViewController: navigationController),
            depositPendingTracker: depositPendingTracker
        )
        coordinator.didRequestOpenMerchantURL = { [weak self] url, fromViewController in
            self?.openBuySellItemURL(url, fromViewController: fromViewController)
        }
        coordinator.didFinish = { [weak self, weak coordinator] _ in
            self?.removeChild(coordinator)
            onFinish?()
        }
        migrationCoordinator = coordinator
        addChild(coordinator)
        coordinator.start()
    }

    func handleBatteryDeeplink(_ payload: Deeplink.Battery, utm: UtmParameters) {
        let walletStore = keeperCoreMainAssembly.storesAssembly.walletsStore
        guard let wallet = try? walletStore.activeWallet else { return }
        if keeperCoreMainAssembly.configurationAssembly.configuration.flag(\.batteryDisabled, network: wallet.network) {
            return
        }

        let service = keeperCoreMainAssembly.batteryAssembly.batteryService()
        let promocodeStore = keeperCoreMainAssembly.batteryAssembly.batteryPromocodeStore()

        if let promocode = payload.promocode {
            Task {
                await promocodeStore.setResolveState(.resolving(promocode: promocode))
                do {
                    try await service.verifyPromocode(wallet: wallet, promocode: promocode)
                    await promocodeStore.setResolveState(.success(promocode: promocode))
                } catch {
                    await promocodeStore.setResolveState(.failed(promocode: promocode))
                }
            }
        }

        self.openBattery(
            wallet: wallet,
            jettonMasterAddress: payload.masterJettonAddress,
            initiatedBy: .deepLink,
            utm: utm
        )
    }

    func handleStoryDeeplink(storyId: String) {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil

        ToastPresenter.hideAll()
        ToastPresenter.showToast(configuration: .loading)

        deeplinkHandleTask = Task { @MainActor in
            do {
                try await mainCoordinatorStoriesController?.handleDeeplinkStory(
                    storyId: storyId,
                    walletId: activeWalletScopeId
                )
                self.deeplinkHandleTask = nil
                ToastPresenter.hideAll()
            } catch {
                self.deeplinkHandleTask = nil
                ToastPresenter.hideAll()
                ToastPresenter.showToast(configuration: .failed)
            }
        }
    }
}
