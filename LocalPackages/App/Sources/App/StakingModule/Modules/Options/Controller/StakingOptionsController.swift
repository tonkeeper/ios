import Foundation
import TKUIKit
import TKCore
import BigInt
import TonSwift
import KeeperCore

final class StakingOptionsController {
  var didUpdateItems: (([OptionItem]) -> Void)?
  
  
  static let testUrl = URL(string: "https://cache.tonapi.io/imgproxy/GjhSro_E6Qxod2SDQeDhJA_F3yARNomyZFKeKw8TVOU/rs:fill:200:200:1/g:no/aHR0cHM6Ly90b25zdGFrZXJzLmNvbS9qZXR0b24vbG9nby5zdmc.webp")
  
  var items: [OptionItem] = [
    .init(
      id: "Tonstakers",
      title: "Tonstakers",
      image: .url(testUrl),
      apyPercents: "5.01%",
      apyTokenAmount: nil,
      minDepositAmount: "1 TON",
      isMaxAPY: true,
      isPrefferable: true,
      isSelected: true
    ),
    .init(
      id: "Bemo",
      title: "Bemo",
      image: .url(testUrl),
      apyPercents: "4.01%",
      apyTokenAmount: nil,
      minDepositAmount: "1 TON",
      isMaxAPY: false,
      isPrefferable: true,
      isSelected: false
    ),
    .init(
      id: "Whales Liquid Pool",
      title: "Whales Liquid Pool",
      image: .url(testUrl),
      apyPercents: "4.01%",
      apyTokenAmount: nil,
      minDepositAmount: "1 TON",
      isMaxAPY: false,
      isPrefferable: true,
      isSelected: false
    ),
    .init(
      id: "TON Whales",
      title: "TON Whales",
      image: .url(testUrl),
      apyPercents: "4.01%",
      apyTokenAmount: nil,
      minDepositAmount: "50 TON",
      isMaxAPY: false,
      isPrefferable: false,
      isSelected: false
    ),
    .init(
      id: "TON Nominators",
      title: "TON Nominators",
      image: .ton,
      apyPercents: "4.01%",
      apyTokenAmount: nil,
      minDepositAmount: "10K TON",
      isMaxAPY: false,
      isPrefferable: false,
      isSelected: false
    )
  ]
  
  func start() {
    didUpdateItems?(items)
  }
  
  func didSelectPreferableItem(id: String) {
    for index in items.indices where items[index].isPrefferable {
      let itemId =  items[index].id
      items[index].isSelected = id == itemId
    }
    
    didUpdateItems?(items)
  }
  
  func getItem(id: String) -> OptionItem? {
    items.first(where: { $0.title == id })
  }
}
