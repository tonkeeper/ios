//
//  TonConnectConfirmationProtocols.swift
//  Tonkeeper
//
//  Created by Grigory Serebryanyy on 27.10.2023.
//

import Foundation
import UIKit

protocol TonConnectConfirmationModuleOutput: AnyObject {
  func tonConnectConfirmationModuleDidConfirm(_ module: TonConnectConfirmationModuleInput) async throws
  func tonConnectConfirmationModuleDidFinish(_ module: TonConnectConfirmationModuleInput)
  func tonConnectConfirmationModuleDidCancel(_ module: TonConnectConfirmationModuleInput)
}

protocol TonConnectConfirmationModuleInput: AnyObject {}

protocol TonConnectConfirmationPresenterInput {
  func viewDidLoad()
}

protocol TonConnectConfirmationViewInput: AnyObject {
  func update(with configuration: ModalCardViewController.Configuration)
  func getConfirmationContentView(model: TonConnectConfirmationContentView.Model) -> TonConnectConfirmationContentView
}
