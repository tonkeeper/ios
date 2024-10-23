import Foundation
import TonSwift
import BigInt

public protocol ConfirmTransactionControllerBocProvider {
  func createBoc(wallet: Wallet, seqno: UInt64, timeout: UInt64) async throws -> String
}

public final class ConfirmTransactionController {

  public struct ConfirmTransactionAvailabilityModel {
    public let requiredAmount: UInt64
    public let availableAmount: UInt64
    public let token: Token
  }

  private let wallet: Wallet
  private let bocProvider: ConfirmTransactionControllerBocProvider
  private let sendService: SendService
  private let nftService: NFTService
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let balanceStore: ConvertedBalanceStore
  private let confirmTransactionMapper: ConfirmTransactionMapper
  
  init(wallet: Wallet,
       bocProvider: ConfirmTransactionControllerBocProvider,
       sendService: SendService,
       nftService: NFTService,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       balanceStore: ConvertedBalanceStore,
       confirmTransactionMapper: ConfirmTransactionMapper) {
    self.wallet = wallet
    self.bocProvider = bocProvider
    self.sendService = sendService
    self.nftService = nftService
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.balanceStore = balanceStore
    self.confirmTransactionMapper = confirmTransactionMapper
  }
  
  public func createRequestModel() async throws -> ConfirmTransactionModel {
    let model = try await emulate()
    return model
  }

  public func confirmTransactionAvailability(param: SendTransactionParam?) async throws -> ConfirmTransactionAvailabilityModel? {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let boc = try await bocProvider.createBoc(
      wallet: wallet,
      seqno: seqno,
      timeout: timeout
    )

    let currency = await currencyStore.getState()
    let transactionInfo = try await sendService.loadTransactionInfo(boc: boc, wallet: wallet)
    let event = try AccountEvent(accountEvent: transactionInfo.event)
    let nfts = try await loadEventNFTs(event: event)

    let fee = UInt64(abs(event.fee))
    let tonRisk = transactionInfo.risk.ton
    let jettonsRisk = transactionInfo.risk.jettons

    guard let param,
          let balance = await balanceStore.getState()[wallet]?.balance,
          !jettonsRisk.isEmpty || tonRisk > 0 else {
      return nil
    }

    if !jettonsRisk.isEmpty, !nfts.nfts.isEmpty {
      let availableTonBalance = balance.tonBalance.tonBalance.amount

      return ConfirmTransactionAvailabilityModel(
        requiredAmount: fee,
        availableAmount: UInt64(availableTonBalance),
        token: .ton
      )
    } else {
      let requiredAmount = fee + UInt64(tonRisk)
      let availableTonBalance = balance.tonBalance.tonBalance.amount
      return ConfirmTransactionAvailabilityModel(
        requiredAmount: requiredAmount,
        availableAmount: UInt64(availableTonBalance),
        token: .ton
      )
    }
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
    let currency = await currencyStore.getState()
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
