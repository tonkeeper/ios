//
//  WalletCoreAssembly.swift
//  Tonkeeper
//
//  Created by Grigory on 28.6.23..
//

import Foundation
import WalletCore
import TonSwift
import TKCore

final class WalletCoreAssembly {
  
  let coreAssembly: CoreAssembly
  let walletCoreAssembly: WalletCore.Assembly
  
  init(coreAssembly: CoreAssembly) {
    self.coreAssembly = coreAssembly
    self.walletCoreAssembly = WalletCore.Assembly(
      dependencies: Dependencies(
        cacheURL: coreAssembly.cacheURL,
        sharedCacheURL: coreAssembly.sharedCacheURL,
        sharedKeychainGroup: coreAssembly.keychainAccessGroupIdentifier)
    )
  }
  
  var configurationController: ConfigurationController {
    walletCoreAssembly.configurationController
  }
  
  var keeperController: KeeperController {
    walletCoreAssembly.keeperController
  }
  
  var passcodeController: PasscodeController {
    walletCoreAssembly.passcodeController
  }
  
  var balanceController: WalletBalanceController {
    walletCoreAssembly.walletBalanceController
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
  
  func fiatMethodsController() -> FiatMethodsController {
    walletCoreAssembly.fiatMethodsController()
  }
  
  var deeplinkParser: DeeplinkParser {
    walletCoreAssembly.deeplinkParser()
  }
  
  var deeplinkGenerator: DeeplinkGenerator {
    walletCoreAssembly.deeplinkGenerator()
  }
  
  var addressValidator: AddressValidator {
    walletCoreAssembly.addressValidator()
  }
}
