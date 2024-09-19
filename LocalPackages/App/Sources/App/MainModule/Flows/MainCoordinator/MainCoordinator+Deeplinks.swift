import UIKit
import TKUIKit
import KeeperCore
import TonSwift
import BigInt

extension MainCoordinator {
  func openSendDeeplink(recipient: String, amount: BigUInt?, comment: String?, jettonAddress: Address?) {
    deeplinkHandleTask?.cancel()
    
    ToastPresenter.hideAll()
    ToastPresenter.showToast(configuration: .loading)
    
    let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore
    
    let deeplinkHandleTask = Task {
      do {
        let wallet = try await walletsStore.getActiveWallet()
        
        let token: Token
        if let jettonAddress {
          let jettonItem = try await self.jettonBalanceResolver.resolveJetton(jettonAddress: jettonAddress, wallet: wallet)
          token = .jetton(jettonItem)
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
      } catch JettonBalanceResolverError.insufficientFunds {
        print("SHow POPUP")
        await MainActor.run {
          self.deeplinkHandleTask = nil
          ToastPresenter.hideAll()
          ToastPresenter.showToast(configuration: .failed)
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
    guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.getActiveWallet() else { return }
    openBuy(wallet: wallet)
  }
  
  func openStakingDeeplink() {
    deeplinkHandleTask?.cancel()
    deeplinkHandleTask = nil
    guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.getActiveWallet() else { return }
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
        let wallet = try await walletsStore.getActiveWallet()
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
  
  func openExchangeDeeplink(provider: String) {
    deeplinkHandleTask?.cancel()
    
    ToastPresenter.hideAll()
    ToastPresenter.showToast(configuration: .loading)
    
    let buySellService = keeperCoreMainAssembly.servicesAssembly.buySellMethodsService()
    let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore
    let configurationStore = keeperCoreMainAssembly.configurationAssembly.remoteConfigurationStore
    let currencyStore = keeperCoreMainAssembly.storesAssembly.currencyStore
    
    let deeplinkHandleTask = Task {
      do {
        let wallet = try await walletsStore.getActiveWallet()
        let mercuryoSecret = try? await configurationStore.getConfiguration().mercuryoSecret
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
    guard let wallet = try? keeperCoreMainAssembly.storesAssembly.walletsStore.getActiveWallet() else { return }
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
        let wallet = try await walletsStore.getActiveWallet()
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
