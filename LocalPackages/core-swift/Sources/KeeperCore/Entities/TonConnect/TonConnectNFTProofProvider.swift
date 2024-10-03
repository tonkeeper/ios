import Foundation
import TonSwift

public struct TonConnectNFTProofProvider {

  let nft: NFT
  let wallet: Wallet
  let mnemonicRepository: MnemonicsRepository

  public init(
    wallet: Wallet,
    nft: NFT,
    mnemonicRepository: MnemonicsRepository
  ) {
    self.nft = nft
    self.wallet = wallet
    self.mnemonicRepository = mnemonicRepository
  }

  public func composeTonNFTProofURL(baseURL: URL, passcode: String) async throws -> URL? {
    try await withCheckedThrowingContinuation { continuation in
      Task {
        do {
          guard let host = baseURL.host else {
            continuation.resume(returning: nil)
            return
          }
          let mnemonic = try await mnemonicRepository.getMnemonic(wallet: wallet, password: passcode)
          let keyPair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonic.mnemonicWords)


          let privateKey = keyPair.privateKey
          let walletAddress = try wallet.address
          let walletRawAddress = walletAddress.toRaw()
          let nftRawAddress = self.nft.address.toRaw()
          let item = TonConnect.TonProofItemReplySuccess(
            address: walletAddress,
            domain: host,
            payload: nftRawAddress,
            privateKey: privateKey
          )

          let proof = item.proof
          let signature = proof.signature
          let timestamp = signature.timestamp

          let builder = Builder()
          try wallet.stateInit.storeTo(builder: builder)
          let stateInit = try builder.endCell().toBoc().base64EncodedString()

          var urlComponents = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
          var queryItems = [URLQueryItem]()
          queryItems.append(URLQueryItem(name: "v", value: nftRawAddress))
          queryItems.append(URLQueryItem(name: "wallet", value: walletRawAddress))
          queryItems.append(URLQueryItem(name: "publicKey", value: keyPair.publicKey.hexString))
          queryItems.append(URLQueryItem(name: "nftAddress", value: nftRawAddress))
          queryItems.append(URLQueryItem(name: "timestamp", value: "\(timestamp)"))
          queryItems.append(URLQueryItem(name: "domain", value: "\(item.proof.domain.value)"))
          queryItems.append(URLQueryItem(name: "stateInit", value: stateInit))
          queryItems.append(URLQueryItem(name: "signature", value: "\(signature.data().hexString())"))
          urlComponents?.queryItems = queryItems
          continuation.resume(returning: urlComponents?.url)
        } catch {
          continuation.resume(throwing: error)
        }
      }
    }
  }
}
