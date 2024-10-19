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
        let wallet = try await walletsStore.activeWallet
        
        let token: Token
        if let jettonAddress {
          let jettonBalance = try await self.jettonBalanceResolver.resolveJetton(jettonAddress: jettonAddress, wallet: wallet)
          if let amount, jettonBalance.quantity < amount {
            await MainActor.run {
              ToastPresenter.hideAll()
              self.openInsufficientFundsPopup(
                jettonInfo: jettonBalance.item.jettonInfo,
                requiredAmount: amount,
                availableAmount: jettonBalance.quantity
              )
            }
            return
          }
          token = .jetton(jettonBalance.item)
        } else {
          token = .ton
        }
        
        let recipient = try await self.recipientResolver.resolverRecipient(string: recipient, isTestnet: wallet.isTestnet)
        
        guard !Task.isCancelled else { return }
        await MainActor.run {
          self.deeplinkHandleTask = nil
          ToastPresenter.hideAll()
          self.openSend(
            wallet: wallet,
            token: token,
            recipient: recipient,
            amount: amount,
            comment: comment
          )
        }
      } catch JettonBalanceResolverError.unknownJetton {
        await MainActor.run {
          self.deeplinkHandleTask = nil
          ToastPresenter.hideAll()
          ToastPresenter.showToast(
            configuration: ToastPresenter.Configuration(
              title: "Unknown token",
              dismissRule: .default
            )
          )
        }
      } catch JettonBalanceResolverError.insufficientFunds(let jettonInfo, let balance, _) {
        await MainActor.run { [weak self, jettonInfo] in
          self?.deeplinkHandleTask = nil
          ToastPresenter.hideAll()
          self?.openInsufficientFundsPopup(
            jettonInfo: jettonInfo,
            requiredAmount: amount ?? 0,
            availableAmount: balance
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
        let wallet = try await walletsStore.activeWallet
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
    
    let buySellService = keeperCoreMainAssembly.servicesAssembly.buySellMethodsService()
    let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore
    let configurationStore = keeperCoreMainAssembly.configurationAssembly.configurationStore
    let currencyStore = keeperCoreMainAssembly.storesAssembly.currencyStore
    
    let deeplinkHandleTask = Task {
      do {
        let wallet = try await walletsStore.activeWallet
        let mercuryoSecret = await configurationStore.getConfiguration().mercuryoSecret
        let currency = await currencyStore.getState()
        
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
        let wallet = try await walletsStore.activeWallet
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
}
