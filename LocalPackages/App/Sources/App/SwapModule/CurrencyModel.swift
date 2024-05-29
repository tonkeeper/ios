//
//  CurrencyModel.swift
//  TonUI
//
//  Created by Marina on 20.05.2024.
//

import Foundation
import KeeperCore

struct CurrencyModel: Equatable, Identifiable {
    let id: String = UUID().uuidString
    let symbol: String
    let fullName: String
    let balance: String 
    let dollarBalance: String
    let logo: URL?

    let jetton: JettonItem?
}
