//
//  TokenDetailsTokenDetailsProtocols.swift
//  Tonkeeper

//  Tonkeeper
//  Created by Grigory Serebryanyy on 13/07/2023.
//

import UIKit
import WalletCore

protocol TokenDetailsModuleOutput: AnyObject {
  func didTapTonSend()
  func didTapTonReceive()
  func didTapTonBuy()
  func didTapTopSwap()
  
  func didTapTokenSend(tokenInfo: TokenInfo)
  func didTapTokenReceive(tokenInfo: TokenInfo)
  func didTapTokenSwap(tokenInfo: TokenInfo)
  
  func tonChartModule() -> Module<TonChartViewController, TonChartModuleInput>
}

protocol TokenDetailsModuleInput: AnyObject, TokenDetailsControllerOutput {}

protocol TokenDetailsPresenterInput {
  var hasAbout: Bool { get }
  func viewDidLoad()
  func didPullToRefresh()
  func didTapTonButton()
  func didTapTwitterButton()
  func didTapChatButton()
  func didTapCommunityButton()
  func didTapWhitepaperButton()
  func didTapTonViewerButton()
  func didTapSourceCodeButton()
}

protocol TokenDetailsViewInput: AnyObject {
  func updateTitle(title: String)
  func updateHeader(model: TokenDetailsHeaderView.Model)
  func showChart(_ chartViewController: UIViewController)
  func stopRefresh()
}
