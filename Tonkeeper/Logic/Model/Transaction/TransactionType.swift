//
//  TransactionType.swift
//  Tonkeeper
//
//  Created by Grigory on 7.6.23..
//

import Foundation

enum TransactionType {
  case sent
  case receieved
  case spam
  case bounced
  case subscribed
  case unsubscribed
  case walletInitialized
  case nftCollectionCreation
  case nftCreation
  case removalFromSale
  case nftPurchase
  case bid
  case putUpForAuction
  case endOfAuction
  case putUpForSale
}
