import Foundation

public final class SwapConfirmationController {

  private let walletsStore: WalletsStore
  private let sendService: SendService
  private let blockchainService: BlockchainService
  private let mnemonicRepository: WalletMnemonicRepository

  init(walletsStore: WalletsStore, 
       sendService: SendService,
       blockchainService: BlockchainService,
       mnemonicRepository: WalletMnemonicRepository) {
    self.walletsStore = walletsStore
    self.sendService = sendService
    self.blockchainService = blockchainService
    self.mnemonicRepository = mnemonicRepository
  }
}
