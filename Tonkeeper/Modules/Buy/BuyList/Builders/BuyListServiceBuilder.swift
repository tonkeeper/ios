//
//  BuyListServiceBuilder.swift
//  Tonkeeper
//
//  Created by Grigory on 12.6.23..
//

import UIKit
import WalletCoreKeeper

struct BuyListServiceBuilder {
  func buildServiceModel(viewModel: WalletCoreKeeper.FiatMethodViewModel) -> BuyListServiceCell.Model {
    BuyListServiceCell.Model(
      logo: .url(viewModel.iconURL),
      title: viewModel.title,
      description: viewModel.description,
      token: viewModel.token
    )
  }
}
