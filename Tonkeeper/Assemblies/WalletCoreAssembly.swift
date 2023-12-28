//
//  WalletCoreAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import Foundation
import WalletCoreKeeper
import WalletCoreCore
import TonSwift
import TKCore

final class WalletCoreAssembly {
  
  let coreAssembly: CoreAssembly
  let walletCoreAssembly: WalletCoreKeeper.Assembly
  
  init(coreAssembly: CoreAssembly) {
    self.coreAssembly = coreAssembly
    self.walletCoreAssembly = WalletCoreKeeper.Assembly(
      dependencies: Dependencies( 
        cacheURL: coreAssembly.cacheURL,
        sharedCacheURL: coreAssembly.sharedCacheURL,
        sharedKeychainGroup: coreAssembly.keychainAccessGroupIdentifier)
    )
  }
  
  var configurationController: ConfigurationController {
    walletCoreAssembly.configurationController
  }
  
  var knownAccounts: KnownAccounts {
    walletCoreAssembly.knownAccounts
  }
  
  var walletsController: WalletsController {
    walletCoreAssembly.walletsController
  }
  
  var walletProvider: WalletProvider {
    walletCoreAssembly.walletsProvider
  }
  
  var passcodeController: PasscodeController {
    walletCoreAssembly.passcodeController
  }
  
  var balanceController: BalanceController {
    walletCoreAssembly.balanceController
  }
  
  var sendInputController: SendInputController {
    walletCoreAssembly.sendInputController
  }
  
  func sendController(transferModel: TransferModel,
                      recipient: Recipient,
                      comment: String?) -> SendController {
    walletCoreAssembly.sendController(transferModel: transferModel,
                                       recipient: recipient,
                                       comment: comment)
  }
  
  func sendRecipientController() -> SendRecipientController {
    walletCoreAssembly.sendRecipientController()
  }
  
  func receiveController() -> ReceiveController {
    walletCoreAssembly.receiveController()
  }
  
  func tokenDetailsTonController() -> TokenDetailsController {
    walletCoreAssembly.tokenDetailsTonController()
  }
  
  func tokenDetailsTokenController(tokenInfo: TokenInfo) -> TokenDetailsController {
    walletCoreAssembly.tokenDetailsTokenController(tokenInfo: tokenInfo)
  }
  
  func activityListController() -> ActivityListController {
    walletCoreAssembly.activityListController()
  }
  
  func activityController() -> ActivityController {
    walletCoreAssembly.activityController()
  }
  
  func activityListTonEventsController() -> ActivityListController {
    walletCoreAssembly.activityListTonEventsController()
  }
  
  func activityListTokenEventsController(tokenInfo: TokenInfo) -> ActivityListController {
    walletCoreAssembly.activityListTokenEventsController(tokenInfo: tokenInfo)
  }
  
  func activityEventDetailsController(action: ActivityEventAction) -> ActivityEventDetailsController {
    walletCoreAssembly.activityEventDetailsController(action: action)
  }
  
  func chartController() -> ChartController {
    walletCoreAssembly.chartController()
  }
  
  public func collectibleDetailsController(
    collectibleAddress: Address
  ) -> CollectibleDetailsController {
    walletCoreAssembly.collectibleDetailsController(collectibleAddress: collectibleAddress)
  }
  
  func settingsController() -> SettingsController {
    walletCoreAssembly.settingsController()
  }
  
  func logoutController() -> LogoutController {
    walletCoreAssembly.logoutController()
  }
  
  func tonConnectDeeplinkProcessor() -> TonConnectDeeplinkProcessor {
    walletCoreAssembly.tonConnectDeeplinkProcessor()
}
  
  func tonConnectController(parameters: TonConnectParameters,
                            manifest: TonConnectManifest) -> TonConnectController {
    walletCoreAssembly.tonConnectController(parameters: parameters,
                                            manifest: manifest)
  }
  
  func tonConnectConfirmationController() -> TonConnectConfirmationController {
    walletCoreAssembly.tonConnectConfirmationController()
  }
  
  func tonConnectEventsDaemon() -> TonConnectEventsDaemon {
    walletCoreAssembly.tonConnectEventsDaemon()
  }
  
  func transactionsEventsDaemon() -> TransactionsEventDaemon {
    walletCoreAssembly.transactionsEventsDaemon
  }
  
  func fiatMethodsController() -> FiatMethodsController {
    walletCoreAssembly.fiatMethodsController()
  }
  
  func deeplinkParser(handlers: [DeeplinkHandler]) -> DeeplinkParser {
    walletCoreAssembly.deeplinkParser(handlers: handlers)
  }
  
  var tonDeeplinkHandler: DeeplinkHandler {
    walletCoreAssembly.tonDeeplinkHandler
  }
  
  var tonConnectDeeplinkHandler: DeeplinkHandler {
    walletCoreAssembly.tonConnectDeeplinkHandler
  }
  
  var deeplinkGenerator: DeeplinkGenerator {
    walletCoreAssembly.deeplinkGenerator()
  }
  
  var addressValidator: AddressValidator {
    walletCoreAssembly.addressValidator()
  }
}
