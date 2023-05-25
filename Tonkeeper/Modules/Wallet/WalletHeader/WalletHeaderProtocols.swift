//
//  WalletHeaderProtocols.swift
//  Tonkeeper
//
//  Created by Grigory on 25.5.23..
//

import Foundation

protocol WalletHeaderModuleOutput: AnyObject {}

protocol WalletHeaderModuleInput: AnyObject {}

protocol WalletHeaderPresenterInput {
  func viewDidLoad()
  func didTapAddressButton()
}

protocol WalletHeaderViewInput: AnyObject {
  func update(with model: WalletHeaderView.Model)
}
