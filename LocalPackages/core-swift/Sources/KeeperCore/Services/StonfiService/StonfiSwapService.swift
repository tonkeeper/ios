import Foundation
import TonSwift
import BigInt

struct StonfiSwapSimulationRequestModel {
  let fromAddress: Address
  let toAddress: Address
  let amount: BigUInt
  let slippageTolerance: String
  let referralAddress: Address?
  
  init(fromAddress: Address, toAddress: Address, amount: BigUInt, slippageTolerance: String, referralAddress: Address? = nil) {
    self.fromAddress = fromAddress
    self.toAddress = toAddress
    self.amount = amount
    self.slippageTolerance = slippageTolerance
    self.referralAddress = referralAddress
  }
}

protocol StonfiSwapService {
  func simulateDirectSwap(_ simulationRequest: StonfiSwapSimulationRequestModel) async throws -> StonfiSwapSimulation
  func simulateReverseSwap(_ simulationRequest: StonfiSwapSimulationRequestModel) async throws -> StonfiSwapSimulation
}

final class StonfiSwapServiceImplementation: StonfiSwapService {
  private let stonfiApi: StonfiAPI
  
  init(stonfiApi: StonfiAPI) {
    self.stonfiApi = stonfiApi
  }
  
  func simulateDirectSwap(_ simulationRequestModel: StonfiSwapSimulationRequestModel) async throws -> StonfiSwapSimulation {
    let simulationResult = try await stonfiApi.simulateDirectSwap(
      from: simulationRequestModel.fromAddress,
      to: simulationRequestModel.toAddress,
      offerAmount: simulationRequestModel.amount,
      slippageTolerance: simulationRequestModel.slippageTolerance,
      referral: simulationRequestModel.referralAddress
    )
    return try mapSwapSimulationResult(simulationResult)
  }
  
  func simulateReverseSwap(_ simulationRequestModel: StonfiSwapSimulationRequestModel) async throws -> StonfiSwapSimulation {
    let simulationResult = try await stonfiApi.simulateReverseSwap(
      from: simulationRequestModel.fromAddress,
      to: simulationRequestModel.toAddress,
      askAmount: simulationRequestModel.amount,
      slippageTolerance: simulationRequestModel.slippageTolerance,
      referral: simulationRequestModel.referralAddress
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
