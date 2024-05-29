import Foundation
import TonAPI
import TonSwift

protocol SwapService {
  func getAssets() async throws -> AssetList
  func getPairs() async throws -> PairsList
  func swapSimulate(offerAddress: String, askAddress: String, units: String, slippageTolerance: Float) async throws -> SwapEstimate
  func reverseSwapSimulate(offerAddress: String, askAddress: String, units: String, slippageTolerance: Float) async throws -> SwapEstimate
}

final class SwapServiceImplementation: SwapService {
  private let stonFiAPI: StonFiAPI
  
  init(stonFiAPI: StonFiAPI) {
    self.stonFiAPI = stonFiAPI
  }
  
  func getAssets() async throws -> AssetList {
    try await stonFiAPI.getAssets()
  }
  func getPairs() async throws -> PairsList {
    try await stonFiAPI.getPairs()
  }
  func swapSimulate(offerAddress: String, askAddress: String, units: String, slippageTolerance: Float) async throws -> SwapEstimate {
    try await stonFiAPI.swapSimulate(offerAddress: offerAddress,
                                     askAddress: askAddress,
                                     units: units,
                                     slippageTolerance: slippageTolerance)
  }
  func reverseSwapSimulate(offerAddress: String,
                           askAddress: String,
                           units: String,
                           slippageTolerance: Float) async throws -> SwapEstimate {
    try await stonFiAPI.reverseSwapSimulate(offerAddress: offerAddress,
                                            askAddress: askAddress,
                                            units: units,
                                            slippageTolerance: slippageTolerance)
  }
}
