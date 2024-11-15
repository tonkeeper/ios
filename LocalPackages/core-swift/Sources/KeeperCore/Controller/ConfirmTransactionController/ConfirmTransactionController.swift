import Foundation
import TonSwift
import BigInt
import TonAPI

public protocol ConfirmTransactionControllerBocProvider {
  func createBoc(wallet: Wallet, seqno: UInt64, timeout: UInt64) async throws -> String
}

public final class ConfirmTransactionController {

  public typealias TransactionTokenInfo = (token: Token, availableBalance: BigUInt)
  public struct ConfirmModel {
    public let fee: Int64
    public let tonBalance: UInt64
    public let requiredAmount: Int64
    public let token: TransactionTokenInfo
  }

  private let wallet: Wallet
  private let bocProvider: ConfirmTransactionControllerBocProvider
  private let sendService: SendService
  private let nftService: NFTService
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let totalBalanceStore: TotalBalanceStore
  private let balanceStore: ConvertedBalanceStore
  private let jettonBalanceResolver: JettonBalanceResolver
  private let confirmTransactionMapper: ConfirmTransactionMapper
  
  init(wallet: Wallet,
       bocProvider: ConfirmTransactionControllerBocProvider,
       sendService: SendService,
       nftService: NFTService,
       tonRatesStore: TonRatesStore,
       currencyStore: CurrencyStore,
       totalBalanceStore: TotalBalanceStore,
       balanceStore: ConvertedBalanceStore,
       jettonBalanceResolver: JettonBalanceResolver,
       confirmTransactionMapper: ConfirmTransactionMapper) {
    self.wallet = wallet
    self.bocProvider = bocProvider
    self.sendService = sendService
    self.nftService = nftService
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.totalBalanceStore = totalBalanceStore
    self.balanceStore = balanceStore
    self.jettonBalanceResolver = jettonBalanceResolver
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
    let currency = currencyStore.state
    let rates = tonRatesStore.state.first(where: { $0.currency == currency })
    let transactionInfo = try await sendService.loadTransactionInfo(boc: boc, wallet: wallet)
    let event = try AccountEvent(accountEvent: transactionInfo.event)
    let nfts = try await loadEventNFTs(event: event)
    let confirmModel = await createConfirmModel(transactionInfo: transactionInfo, event: event)

    return try confirmTransactionMapper.mapTransactionInfo(
      transactionInfo,
      tonRates: rates,
      currency: currency,
      totalBalanceStore: totalBalanceStore,
      nftsCollection: nfts,
      wallet: wallet,
      confirmModel: confirmModel
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

  private func createConfirmModel(
    transactionInfo: MessageConsequences,
    event: AccountEvent
  ) async -> ConfirmModel? {

    let fee = Int64(abs(event.fee))
    let tonRisk = transactionInfo.risk.ton

    guard let balance = balanceStore.getState()[wallet]?.balance else {
      return nil
    }
    let tonBalance = UInt64(balance.tonBalance.tonBalance.amount)

    var requiredAmount: Int64?
    var token: Token?
    var availableBalance: BigUInt?

    await event.actions.asyncForEach { action in
      token = .ton

      switch action.type {
      case .tonTransfer(let tonTransfer):
        requiredAmount = tonTransfer.amount + Int64(fee)
        availableBalance = BigUInt(integerLiteral: tonBalance)
      case .jettonTransfer(let jettonTransfer):
        guard event.account.address == jettonTransfer.sender?.address else {
          return
        }
        requiredAmount = Int64(fee) + tonRisk
        availableBalance = BigUInt(tonBalance)
      case .nftItemTransfer:
        requiredAmount = Int64(fee)
        availableBalance = BigUInt(tonBalance)
      case .nftPurchase(let purchase):
        requiredAmount = Int64(purchase.price)
        availableBalance = BigUInt(tonBalance)
      case .jettonSwap(let jettonSwap):
        if let address = jettonSwap.jettonInfoIn?.address,
           let jettonBalance = try? await self.jettonBalanceResolver.resolveJetton(
            jettonAddress: address,
            wallet: self.wallet) {

          requiredAmount = Int64(jettonSwap.amountIn)
          token = .jetton(jettonBalance.item)
          availableBalance = jettonBalance.quantity
        } else if let tonIn = jettonSwap.tonIn {
          requiredAmount = Int64(fee) + tonIn
          availableBalance = BigUInt(tonBalance)
          token = .ton
        } else {
          requiredAmount = Int64(fee) + tonRisk
          availableBalance = BigUInt(tonBalance)
        }
      case .unknown:
        requiredAmount = Int64(fee) + tonRisk
        availableBalance = BigUInt(tonBalance)
      default:
        return
      }
    }

    guard let requiredAmount, let token, let availableBalance else {
      return nil
    }

    return ConfirmModel(
      fee: fee,
      tonBalance: tonBalance,
      requiredAmount: requiredAmount,
      token: TransactionTokenInfo(
        token: token,
        availableBalance: availableBalance
      )
    )
  }
}
