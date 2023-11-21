//
//  FiatMethodPopUpProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 16.10.23..
//

import Foundation
import WalletCoreKeeper

protocol FiatMethodPopUpModuleOutput: AnyObject {
  func fiatMethodPopUpModule(_ module: FiatMethodPopUpModuleInput,
                             openURL url: URL)
}

protocol FiatMethodPopUpModuleInput: AnyObject {}

protocol FiatMethodPopUpPresenterInput {
  func viewDidLoad()
}

protocol FiatMethodPopUpViewInput: AnyObject {
  func updateContent(configuration: ModalContentViewController.Configuration)
}

