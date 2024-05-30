import Foundation
import TonSwift
import BigInt

public enum TransferSignServiceError: Error {
  case failedToSign
  case failedToGetMnemonic
}

public protocol TransferSignService: AnyObject {
  var didGetExternalSign: ((URL) async throws -> Data?)? { get set }
  
  func getSign(_ transfer: WalletTransfer, wallet: Wallet) async throws -> Data
}

final class TransferSignServiceImplementation: TransferSignService {
  public var didGetExternalSign: ((URL) async throws -> Data?)?
  
  private let mnemonicRepository: WalletMnemonicRepository
  
  init(mnemonicRepository: WalletMnemonicRepository) {
    self.mnemonicRepository = mnemonicRepository
  }
  
  public func getSign(_ transfer: WalletTransfer, wallet: Wallet) async throws -> Data {
    switch wallet.identity.kind {
    case .Regular:
      do {
        let mnemonic = try mnemonicRepository.getMnemonic(forWallet: wallet)
        let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)
        let privateKey = keyPair.privateKey
        return try transfer.signMessage(signer: WalletTransferSecretKeySigner(secretKey: privateKey.data))
      } catch {
        throw TransferSignServiceError.failedToGetMnemonic
      }
    case .Lockup:
      throw TransferSignServiceError.failedToSign
    case .Watchonly:
      throw TransferSignServiceError.failedToSign
    case .External(let publicKey, let walletContractVersion):
      return try await signExternal(
        transfer: transfer.signingMessage.endCell().toBoc(),
        publicKey: publicKey,
        revision: walletContractVersion
      )
    }
  }
}

//  MARK: - Private methods

private extension TransferSignServiceImplementation {
  func signExternal(transfer: Data, publicKey: TonSwift.PublicKey, revision: WalletContractVersion) async throws -> Data {
    guard let url = createTonSignURL(transfer: transfer, publicKey: publicKey, revision: revision),
          let didGetExternalSign,
          let signedData = try await didGetExternalSign(url) else {
      throw TransferSignServiceError.failedToSign
    }
    return signedData
  }
  
  func createTonSignURL(transfer: Data, publicKey: TonSwift.PublicKey, revision: WalletContractVersion) -> URL? {
    guard let publicKey = publicKey.data.base64EncodedString().percentEncoded,
          let body = transfer.base64EncodedString().percentEncoded else { return nil }
    let v = revision.rawValue.lowercased()
    
    let string = "tonsign://?pk=\(publicKey)&body=\(body)&v=\(v)&return=\("tonkeeperx://publish".percentEncoded ?? "")"
    return URL(string: string)
  }
}
