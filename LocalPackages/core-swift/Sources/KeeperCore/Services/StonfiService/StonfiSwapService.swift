import Foundation
import TonSwift
import BigInt

protocol StonfiSwapService {
  func simulateDirectSwap(from: Address, to: Address, offerAmount: BigUInt, slippageTolerance: String, referral: Address?) async throws -> StonfiSwapSimulation
  func simulateReverseSwap(from: Address, to: Address, askAmount: BigUInt, slippageTolerance: String, referral: Address?) async throws -> StonfiSwapSimulation
}

final class StonfiSwapServiceImplementation: StonfiSwapService {
  private let stonfiApi: StonfiAPI
  
  init(stonfiApi: StonfiAPI) {
    self.stonfiApi = stonfiApi
  }
  
  func simulateDirectSwap(from: Address, to: Address, offerAmount: BigUInt, slippageTolerance: String, referral: Address?) async throws -> StonfiSwapSimulation {
    let simulationResult = try await stonfiApi.simulateDirectSwap(
      from: from,
      to: to,
      offerAmount: offerAmount,
      slippageTolerance: slippageTolerance,
      referral: referral
    )
    return try mapSwapSimulationResult(simulationResult)
  }
  
  func simulateReverseSwap(from: Address, to: Address, askAmount: BigUInt, slippageTolerance: String, referral: Address?) async throws -> StonfiSwapSimulation {
    let simulationResult = try await stonfiApi.simulateReverseSwap(
      from: from,
      to: to,
      askAmount: askAmount,
      slippageTolerance: slippageTolerance,
      referral: referral
    )
    return try mapSwapSimulationResult(simulationResult)
  }
  
  func mapSwapSimulationResult(_ simulationResult: StonfiSwapSimulationResult) throws -> StonfiSwapSimulation {
    let offerAddress = try Address.parse(simulationResult.offerAddress)
    let askAddress = try Address.parse(simulationResult.askAddress)
    let routerAddress = try Address.parse(simulationResult.routerAddress)
    let poolAddress = try Address.parse(simulationResult.poolAddress)
    let feeAddress = try Address.parse(simulationResult.feeAddress)
    let offerUnits = BigUInt(simulationResult.offerUnits) ?? .zero
    let askUnits = BigUInt(simulationResult.askUnits) ?? .zero
    let minAskUnits = BigUInt(simulationResult.minAskUnits) ?? .zero
    let feeUnits = BigUInt(simulationResult.feeUnits) ?? .zero
    let swapRate = Decimal(string: simulationResult.swapRate) ?? .zero
    let priceImpact = Decimal(string: simulationResult.priceImpact) ?? .zero
    
    return StonfiSwapSimulation(
      offerAddress: offerAddress,
      askAddress: askAddress,
      routerAddress: routerAddress,
      poolAddress: poolAddress,
      offerUnits: offerUnits,
      askUnits: askUnits,
      slippageTolerance: simulationResult.slippageTolerance,
      minAskUnits: minAskUnits,
      swapRate: swapRate,
      priceImpact: priceImpact,
      feeAddress: feeAddress,
      feeUnits: feeUnits,
      feePercent: simulationResult.priceImpact
    )
  }
}
