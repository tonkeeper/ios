import BigInt
import KeeperCore
import TKFeatureFlags
import TKLocalize
import TKUIKit
import TonSwift
import UIKit

extension MainCoordinator {
    func openSendDeeplink(
        recipient: String,
        amount: BigUInt?,
        comment: String?,
        jettonAddress: Address?,
        expirationTimestamp: Int64?,
        successReturn: URL?,
        sendSource: SendAnalyticsSource
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

        let deeplinkHandleTask = Task {
            do {
                let wallet = try walletsStore.activeWallet
                let recipient = try await self.recipientResolver.resolverRecipient(string: recipient, network: wallet.network)

                var token: SendV3Item = .ton(.token(.ton, amount: 0))

                if recipient.isScam {
                    ToastPresenter.hideAll()
                    ToastPresenter.showToast(configuration: .init(title: TKLocales.Send.scamAddress))
                    return
                }

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
                    if wallet.isTronTurnOn {
                        token = .tron(TronSendData.Item.usdt(amount: amount ?? 0))
                    } else if wallet.isTronAvailable {
                        openReceiveTRC20Popup(wallet: wallet)
                        self.deeplinkHandleTask = nil
                        ToastPresenter.hideAll()
                        return
                    }
                }

                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.deeplinkHandleTask = nil
                    ToastPresenter.hideAll()
                    self.openSend(
                        wallet: wallet,
                        sendInput: .direct(item: token),
                        sendSource: sendSource,
                        recipient: recipient,
                        comment: comment,
                        successReturn: successReturn
                    )
                }
            } catch InsufficientFundsError.unknownJetton {
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
                        isInternalPurchasing: isInternalPurchasing
                    )
                }
            } catch let InsufficientFundsError.blockchainFee(wallet, balance, amount) {
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
                        isInternalPurchasing: true
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

    private func configureAndShowInsufficientPopup(
        wallet: Wallet,
        caption: String? = nil,
        buttonTitle: String,
        amount: BigUInt?,
        tokenSymbol: String?,
        fractionDigits: Int,
        balance: BigUInt,
        isInternalPurchasing: Bool
    ) {
        var buyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        buyButtonConfiguration.content = TKButton.Configuration.Content(
            title: .plainString(buttonTitle)
        )
        buyButtonConfiguration.action = { [weak self] in
            self?.router.dismiss(animated: true) {
                self?.openBuy(wallet: wallet, isInternalPurchasing: isInternalPurchasing)
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
        expirationTimestamp: Int64?
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
                        sendFrom: .tonconnectRemote
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

    func openBuyDeeplink() {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }
        openBuy(wallet: wallet)
    }

    func openStakingDeeplink() {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }
        guard !keeperCoreMainAssembly.configurationAssembly.configuration.flag(\.stakingDisabled, network: wallet.network) else { return }
        openStake(wallet: wallet)
    }

    func openPoolDetailsDeeplink(poolAddress: Address) {
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
                    self.router.dismiss(animated: true) { [weak self] in
                        self?.openStakingItemDetails(
                            wallet: wallet,
                            stakingPoolInfo: stakingPool
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

    func handleDappDeeplink(url: URL) -> Bool {
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
            if let popularAppsResponse = try? await browserController.loadPopularApps(lang: lang),
               let app = getApp(url, popularAppsResponse)
            {
                openDapp(title: app.name, url: url)
            } else if
                let host = url.host,
                appSettings.isDappOpenWarningDoNotShow(host) || appSettings.dappHostWhiteList.contains(host)
            {
                openDapp(title: nil, url: url)
            } else {
                ToastPresenter.hideAll()
                let warningModule = OpenDappWarningPopupAssembly.module(
                    url: url,
                    keeperCoreAssembly: keeperCoreMainAssembly,
                    coreAssembly: coreAssembly
                )
                let bottomSheetViewController = TKBottomSheetViewController(contentViewController: warningModule.view)

                warningModule.output.didTapOpen = { [weak bottomSheetViewController] url, title in
                    bottomSheetViewController?.dismiss { [weak self] in
                        self?.openDapp(title: title, url: url)
                    }
                }

                bottomSheetViewController.present(fromViewController: router.rootViewController.topPresentedViewController())
            }
        }

        deeplinkHandleTask = task
        return true
    }

    func openExchangeDeeplink(provider: String?) {
        guard let provider else {
            openBuyDeeplink()
            return
        }

        deeplinkHandleTask?.cancel()

        ToastPresenter.hideAll()
        ToastPresenter.showToast(configuration: .loading)

        let buySellService = keeperCoreMainAssembly.buySellAssembly.buySellMethodsService()
        let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore
        let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
        let currencyStore = keeperCoreMainAssembly.storesAssembly.currencyStore
        let tonkeeperAPI = keeperCoreMainAssembly.tonkeeperAPIAssembly.api

        let deeplinkHandleTask = Task {
            do {
                let wallet = try walletsStore.activeWallet
                let mercuryoSecret = await configuration.mercuryoSecret
                let currency = currencyStore.getState()

                let fiatMethods = try await buySellService.loadFiatMethods(countryCode: nil)
                guard let fiatMethod = fiatMethods.categories.flatMap({ $0.items }).first(where: { $0.id == provider }),
                      let methodURL = try await fiatMethod.actionURL(
                          walletAddress: wallet.friendlyAddress,
                          tronAddress: wallet.tron?.address,
                          currency: currency,
                          mercuryoParameters: FiatMethodItem.MercuryoParameters(
                              secret: mercuryoSecret,
                              ipProvider: { try? await tonkeeperAPI.getIP() }
                          )
                      )
                else {
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
                    self.router.dismiss(animated: true) { [weak self] in
                        guard let fromViewController = self?.router.rootViewController else { return }
                        self?.openBuySellItemURL(methodURL, fromViewController: fromViewController)
                    }
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

    func openSwapDeeplink(fromToken: String?, toToken: String?) {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }

        let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
        if configuration.flag(\.nativeSwapDisabled, network: wallet.network) {
            openWebSwap(wallet: wallet, fromToken: fromToken, toToken: toToken)
        } else {
            openNativeSwap(wallet: wallet)
        }
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
                        network: wallet.network
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

        var tokens: [Token] = [.ton(.ton)]
        if wallet.isTronAvailable {
            tokens.append(.tron(.usdt))
        }

        openReceive(tokens: tokens, wallet: wallet)
    }

    func openBackupDeeplink() {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil
        guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.activeWallet else { return }

        openBackup(wallet: wallet)
    }

    func handleBatteryDeeplink(_ payload: Deeplink.Battery) {
        let walletStore = keeperCoreMainAssembly.storesAssembly.walletsStore
        guard let wallet = try? walletStore.activeWallet else { return }
        if keeperCoreMainAssembly.configurationAssembly.configuration.flag(\.batteryDisabled, network: wallet.network) { return }

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
            jettonMasterAddress: payload.masterJettonAddress
        )
    }

    func handleStoryDeeplink(storyId: String) {
        deeplinkHandleTask?.cancel()
        deeplinkHandleTask = nil

        ToastPresenter.hideAll()
        ToastPresenter.showToast(configuration: .loading)

        deeplinkHandleTask = Task { @MainActor in
            do {
                try await mainCoordinatorStoriesController?.handleDeeplinkStory(storyId: storyId)
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
