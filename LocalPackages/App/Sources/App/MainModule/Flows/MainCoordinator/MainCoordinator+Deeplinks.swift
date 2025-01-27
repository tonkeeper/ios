import UIKit
import TKUIKit
import KeeperCore
import TonSwift
import BigInt
import TKLocalize

extension MainCoordinator {
  
  func openSendDeeplink(recipient: String,
                        amount: BigUInt?,
                        comment: String?,
                        jettonAddress: Address?,
                        expirationTimestamp: Int64?,
                        successReturn: URL?) {

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
        let recipient = try await self.recipientResolver.resolverRecipient(string: recipient, isTestnet: wallet.isTestnet)

        let token: Token

        if let jettonAddress {
          let fundsValidator = keeperCoreMainAssembly.loadersAssembly.insufficientFundsValidator()
          let jettonBalance = try await fundsValidator.resolveJettonBalance(
            jettonAddress: jettonAddress, requiredAmount: amount ?? 0, wallet: wallet
          )

          let jettonTransferController = keeperCoreMainAssembly.jettonTransferTransactionConfirmationController(
            wallet: wallet,
            recipient: recipient,
            jettonItem: jettonBalance.item,
            amount: amount ?? 0,
            comment: nil
          )

          try await fundsValidator.validateFundsIfNeeded(
            wallet: wallet,
            sendItem: .token(.jetton(jettonBalance.item), amount: amount ?? 0),
            confirmationController: jettonTransferController
          )

          token = .jetton(jettonBalance.item)
        } else {
          token = .ton
        }
        
        guard !Task.isCancelled else { return }
        await MainActor.run {
          self.deeplinkHandleTask = nil
          ToastPresenter.hideAll()
          self.openSend(
            wallet: wallet,
            token: token,
            recipient: recipient,
            amount: amount,
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
      } catch let InsufficientFundsError.insufficientFunds(jettonInfo, balance, requiredAmount, wallet, isInappPurchaseAvailable) {
        await MainActor.run { [weak self] in
          self?.deeplinkHandleTask = nil

          ToastPresenter.hideAll()


          self?.configureAndShowInsufficientPopup(wallet: wallet,
                                                  buttonTitle: TKLocales.InsufficientFunds.rechargeWallet,
                                                  amount: requiredAmount,
                                                  tokenSymbol: jettonInfo?.symbol ?? jettonInfo?.name,
                                                  fractionDigits: jettonInfo?.fractionDigits ?? 2,
                                                  balance: balance,
                                                  isInAppPurchase: isInappPurchaseAvailable)
        }
      } catch let InsufficientFundsError.blockchainFee(wallet, balance, amount) {
        await MainActor.run { [weak self] in
          self?.deeplinkHandleTask = nil

          ToastPresenter.hideAll()

          guard let self else {
            return
          }

          let tonToken = Token.ton
          let amountFormatter = self.keeperCoreMainAssembly.formattersAssembly.amountFormatter
          let feeFormatted = amountFormatter.formatAmount(amount, fractionDigits: tonToken.fractionDigits, maximumFractionDigits: 2)
          let balanceFormatted = amountFormatter.formatAmount(balance, fractionDigits: tonToken.fractionDigits, maximumFractionDigits: 2)
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
            isInAppPurchase: true
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

  private func configureAndShowInsufficientPopup(wallet: Wallet,
                                                 caption: String? = nil,
                                                 buttonTitle: String,
                                                 amount: BigUInt?,
                                                 tokenSymbol: String?,
                                                 fractionDigits: Int,
                                                 balance: BigUInt,
                                                 isInAppPurchase: Bool) {
    var buyButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
    buyButtonConfiguration.content = TKButton.Configuration.Content(
      title: .plainString(buttonTitle)
    )
    buyButtonConfiguration.action = { [weak self] in
      self?.router.dismiss(animated: true) {
          self?.openBuy(wallet: wallet, isInAppPurchase: isInAppPurchase)
      }
    }

    let builder = InfoPopupBottomSheetConfigurationBuilder(
      amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
    )
    let configuration = builder.insufficientTokenConfiguration(
      walletLabel: wallet.metaData.label,
      caption: caption,
      tokenSymbol: tokenSymbol ?? Token.ton.symbol,
      tokenFractionalDigits: fractionDigits,
      required: amount ?? 0,
      available: balance,
      buttons: [buyButtonConfiguration]
    )

    openInsufficientFundsPopup(configuration: configuration)
  }

  func openSignRawSendDeeplink(recipient: String,
                               amount: BigUInt?,
                               bin: String?,
                               stateInit: String?,
                               expirationTimestamp: Int64?) {
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
        
        let recipient = try await self.recipientResolver.resolverRecipient(string: recipient, isTestnet: wallet.isTestnet)
        
        guard let amount = amount else { return }

        guard !Task.isCancelled else { return }
        await MainActor.run {
          self.deeplinkHandleTask = nil
          ToastPresenter.hideAll()
          self.openTransferSignRaw(
            wallet: wallet,
            recipient: recipient,
            amount: amount,
            payload: bin,
            stateInit: stateInit
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
              stakingPoolInfo: stakingPool)
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
    @Sendable func produceFailingFlow() {
      ToastPresenter.hideAll()
      ToastPresenter.showToast(configuration: .failed)
    }

    deeplinkHandleTask?.cancel()
    ToastPresenter.hideAll()
    ToastPresenter.showToast(configuration: .loading)

    let task = Task {
      let browserController = keeperCoreMainAssembly.browserExploreController()
      let lang = Locale.current.languageCode ?? "en"

      guard let popularAppsResponse = try? await browserController.loadPopularApps(lang: lang) else {
        await MainActor.run {
          self.deeplinkHandleTask = nil
          produceFailingFlow()
        }

        return
      }

      var isDappHandlingApproved = false
      if let _ = popularAppsResponse.apps.first(with: url.host, at: \.url.host) {
        isDappHandlingApproved = true
      } else if let _ = popularAppsResponse.categories.first(where: { $0.apps.contains(with: url.host, at: \.url.host) }) {
        isDappHandlingApproved = true
      }

      guard isDappHandlingApproved, !Task.isCancelled else {
        await MainActor.run {
          self.deeplinkHandleTask = nil
          produceFailingFlow()
        }
        return
      }

      await MainActor.run {
        ToastPresenter.hideAll()
        self.openDapp(title: "", url: url)
      }
    }

    deeplinkHandleTask = task
    return true
  }

  func openExchangeDeeplink(provider: String) {
    deeplinkHandleTask?.cancel()
    
    ToastPresenter.hideAll()
    ToastPresenter.showToast(configuration: .loading)
    
    let buySellService = keeperCoreMainAssembly.buySellAssembly.buySellMethodsService()
    let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore
    let configuration = keeperCoreMainAssembly.configurationAssembly.configuration
    let currencyStore = keeperCoreMainAssembly.storesAssembly.currencyStore
    
    let deeplinkHandleTask = Task {
      do {
        let wallet = try walletsStore.activeWallet
        let mercuryoSecret = await configuration.mercuryoSecret
        let currency = currencyStore.getState()
        
        let fiatMethods = try await buySellService.loadFiatMethods(countryCode: nil)
        guard let fiatMethod = fiatMethods.categories.flatMap({ $0.items }).first(where: { $0.id == provider }),
        let methodURL = fiatMethod.actionURL(walletAddress: try wallet.friendlyAddress,
                                             currency: currency,
                                             mercuryoSecret: mercuryoSecret) else {
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
    openSwap(wallet: wallet, fromToken: fromToken, toToken: toToken)
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
            isTestnet: false
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
  
  func handleBatteryDeeplink(_ payload: Deeplink.Battery) {
    let service = keeperCoreMainAssembly.batteryAssembly.batteryService()
    let promocodeStore = keeperCoreMainAssembly.batteryAssembly.batteryPromocodeStore()
    let walletStore = keeperCoreMainAssembly.storesAssembly.walletsStore
    
    guard let wallet = try? walletStore.activeWallet else { return }
    
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
    
    self.openBattery(wallet: wallet)
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
