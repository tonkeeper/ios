//
//  TonConnectPopupProtocols.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 25.10.2023.
//

import Foundation
import UIKit

protocol TonConnectPopupModuleOutput: AnyObject {
  func tonConnectPopupModuleDidConnect(_ module: TonConnectPopupModuleInput)
  func tonConnectPopupModuleConfirmation(_ module: TonConnectPopupModuleInput) async -> Bool
}

protocol TonConnectPopupModuleInput: AnyObject {}

protocol TonConnectPopupPresenterInput {
  func viewDidLoad()
}

protocol TonConnectPopupViewInput: AnyObject {
  func update(with configuration: ModalCardViewController.Configuration)
  func getHeaderView(appIconURL: URL?) -> UIView
}
