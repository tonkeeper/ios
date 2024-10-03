import Foundation
import TonSwift

public protocol EncryptedCommentService {
  func decryptComment(payload: EncryptedCommentPayload, wallet: Wallet, passcode: String) async throws -> String?
}

final class EncryptedCommentServiceImplementation: EncryptedCommentService {
  private let mnemonicsRepository: MnemonicsRepository
  
  init(mnemonicsRepository: MnemonicsRepository) {
    self.mnemonicsRepository = mnemonicsRepository
  }
  
  func decryptComment(payload: EncryptedCommentPayload, wallet: Wallet, passcode: String) async throws -> String? {
    let mnemonic = try await mnemonicsRepository.getMnemonic(
      wallet: wallet,
      password: passcode
    )
    let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
    
    return try CommentDecryptor(
      privateKey: keyPair.privateKey,
      publicKey: keyPair.publicKey,
      cipherText: payload.encryptedComment.cipherText,
      senderAddress: payload.senderAddress
    ).decrypt()
  }
}
