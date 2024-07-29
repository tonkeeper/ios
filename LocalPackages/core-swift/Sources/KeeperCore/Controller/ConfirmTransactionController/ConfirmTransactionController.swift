import Foundation
import TonSwift
import BigInt

public protocol ConfirmTransactionControllerBocProvider {
  func createBoc(wallet: Wallet, seqno: UInt64, timeout: UInt64) async throws -> String
}

public final class ConfirmTransactionController {
  private let wallet: Wallet
  private let bocProvider: ConfirmTransactionControllerBocProvider
  private let sendService: SendService
  private let nftService: NFTService
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let confirmTransactionMapper: ConfirmTransactionMapper
  
  init(wallet: Wallet,
       bocProvider: ConfirmTransactionControllerBocProvider,
       sendService: SendService,
       nftService: NFTService,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       confirmTransactionMapper: ConfirmTransactionMapper) {
    self.wallet = wallet
    self.bocProvider = bocProvider
    self.sendService = sendService
    self.nftService = nftService
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.confirmTransactionMapper = confirmTransactionMapper
  }
  
  public func createRequestModel() async throws -> ConfirmTransactionModel {
    let model = try await emulate()
    return model
  }
}

private extension ConfirmTransactionController {
  func emulate() async throws -> ConfirmTransactionModel {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let boc = try await bocProvider.createBoc(
      wallet: wallet,
      seqno: seqno,
      timeout: timeout
    )
    let currency = await currencyStore.getCurrency()
    let rates = await tonRatesStore.getState().first(where: { $0.currency == currency })
    let transactionInfo = try await sendService.loadTransactionInfo(boc: boc, wallet: wallet)
    let event = try AccountEvent(accountEvent: transactionInfo.event)
    let nfts = try await loadEventNFTs(event: event)
    
    return try confirmTransactionMapper.mapTransactionInfo(
      transactionInfo,
      tonRates: rates,
      currency: currency,
      nftsCollection: nfts,
      wallet: wallet
    )
  }
  
  func loadEventNFTs(event: AccountEvent) async throws -> NFTsCollection {
    var nftAddressesToLoad = Set<Address>()
    var nfts = [Address: NFT]()
    for action in event.actions {
      switch action.type {
      case .nftItemTransfer(let nftItemTransfer):
        nftAddressesToLoad.insert(nftItemTransfer.nftAddress)
      case .nftPurchase(let nftPurchase):
        nfts[nftPurchase.nft.address] = nftPurchase.nft
        try? nftService.saveNFT(nft: nftPurchase.nft, isTestnet: wallet.isTestnet)
      default: continue
      }
    }
    
    if let loadedNFTs = try? await nftService.loadNFTs(addresses: Array(nftAddressesToLoad), isTestnet: wallet.isTestnet) {
      nfts.merge(loadedNFTs, uniquingKeysWith: { $1 })
    }
    
    return NFTsCollection(nfts: nfts)
  }
}
