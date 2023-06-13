//
//  BuyListServiceBuilder.swift
//  Tonkeeper
//
//  Created by Grigory on 12.6.23..
//

import UIKit

struct BuyListServiceBuilder {
  func buildServiceModel(logo: UIImage?,
                         title: String,
                         description: String?,
                         token: String?) -> BuyListServiceCell.Model {
    .init(logo: logo,
          title: title,
          description: description,
          token: token)
  }
}
