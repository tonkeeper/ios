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
  lazy var walletCoreContainer = WalletCoreContainer(cacheURL: coreAssembly.cacheURL)
  
  init(coreAssembly: CoreAssembly) {
    self.coreAssembly = coreAssembly
  }
  
  lazy var keeperController: KeeperController = walletCoreContainer.keeperController()
  
  lazy var passcodeController: PasscodeController = walletCoreContainer.passcodeController()
  
  lazy var balanceController: WalletBalanceController = walletCoreContainer.walletBalanceController()
  
  var sendInputController: SendInputController {
    walletCoreContainer.sendInputController()
  }
  
  func sendController(transferModel: TransferModel,
                      recipient: Recipient,
                      comment: String?) -> SendController {
    walletCoreContainer.sendController(transferModel: transferModel,
                                       recipient: recipient,
                                       comment: comment)
  }
  
  func sendRecipientController() -> SendRecipientController {
    walletCoreContainer.sendRecipientController()
  }
  
  func receiveController() -> ReceiveController {
    walletCoreContainer.receiveController()
  }
  
  func tokenDetailsTonController() -> TokenDetailsController {
    walletCoreContainer.tokenDetailsTonController()
  }
  
  func tokenDetailsTokenController(tokenInfo: TokenInfo) -> TokenDetailsController {
    walletCoreContainer.tokenDetailsTokenController(tokenInfo: tokenInfo)
  }
  
  func activityListController() -> ActivityListController {
    walletCoreContainer.activityListController()
  }
  
  func activityController() -> ActivityController {
    walletCoreContainer.activityController()
  }
  
  func activityListTonEventsController() -> ActivityListController {
    walletCoreContainer.activityListTonEventsController()
  }
  
  func activityListTokenEventsController(tokenInfo: TokenInfo) -> ActivityListController {
    walletCoreContainer.activityListTokenEventsController(tokenInfo: tokenInfo)
  }
  
  func chartController() -> ChartController {
    walletCoreContainer.chartController()
  }
  
  public func collectibleDetailsController(
    collectibleAddress: Address
  ) -> CollectibleDetailsController {
    walletCoreContainer.collectibleDetailsController(collectibleAddress: collectibleAddress)
  }
  
  var deeplinkParser: DeeplinkParser {
    walletCoreContainer.deeplinkParser()
  }
  
  var deeplinkGenerator: DeeplinkGenerator {
    walletCoreContainer.deeplinkGenerator()
  }
  
  var addressValidator: AddressValidator {
    walletCoreContainer.addressValidator()
  }
}
