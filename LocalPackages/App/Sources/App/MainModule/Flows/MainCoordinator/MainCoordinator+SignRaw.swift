import UIKit
import TKCoordinator
import KeeperCore
import BigInt
import SignRaw

extension MainCoordinator {
  func openSignRaw(wallet: Wallet, transferProvider: @escaping () async throws -> Transfer) {
    guard let windowScene = router.rootViewController.view.window?.windowScene else { return }
  
    SignRawPresenter.presentSignRaw(
      windowScene: windowScene,
      windowLevel: .signRaw,
      wallet: wallet,
      transferProvider:transferProvider,
      coreAssembly: coreAssembly,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      didRequireSign: { [weak self] transferData, wallet, coordinator, router in
        try await self?.didRequireSign(transferData: transferData,
                                       wallet: wallet,
                                       coordinator: coordinator,
                                       router: router)
      }
    )
  }
  
  func openTransferSignRaw(wallet: Wallet,
                           recipient: Recipient,
                           amount: BigUInt,
                           payload: String?,
                           stateInit: String?) {
    let signRaw: () async throws -> SignRawRequest = {
      try await self.createTransferSignRaw(
        wallet: wallet,
        recipient: recipient,
        amount: amount,
        payload: payload,
        stateInit: stateInit
      )
    }
    
    openSignRaw(wallet: wallet) {
      .signRaw(
        try await signRaw(), forceRelayer: true
      )
    }
  }
  
  private func createTransferSignRaw(wallet: Wallet,
                                     recipient: Recipient,
                                     amount: BigUInt,
                                     payload: String?,
                                     stateInit: String?) async throws -> SignRawRequest {
    let sendService = keeperCoreMainAssembly.servicesAssembly.sendService()
    
    let validUntil = await sendService.getTimeoutSafely(wallet: wallet)
    
    let messages: [SignRawRequestMessage] = [
      SignRawRequestMessage(
        address: .address(recipient.recipientAddress.address),
        amount: UInt64(amount),
        stateInit: stateInit,
        payload: payload
      )
    ]
    
    return SignRawRequest(
      messages: messages,
      validUntil: TimeInterval(validUntil),
      from: try wallet.address
    )
  }
  
  @MainActor
  func didRequireSign(transferData: TransferData,
                      wallet: Wallet,
                      coordinator: Coordinator,
                      router: ViewControllerRouter) async throws -> String? {
    let coordinator = WalletTransferSignCoordinator(
      router: router,
      wallet: wallet,
      transferData: transferData,
      keeperCoreMainAssembly: keeperCoreMainAssembly,
      coreAssembly: coreAssembly)
    
    self.walletTransferSignCoordinator = coordinator
    
    let result = await coordinator.handleSign(parentCoordinator: coordinator)
  
    switch result {
    case .signed(let data):
      return data
    case .cancel:
      return nil
    case .failed(let error):
      throw error
    }
  }
}
