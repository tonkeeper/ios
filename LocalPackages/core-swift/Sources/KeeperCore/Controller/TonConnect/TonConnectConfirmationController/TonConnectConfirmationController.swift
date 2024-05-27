import Foundation
import TonSwift
import BigInt

public final class TonConnectConfirmationController {
  private let wallet: Wallet
  private let signTransactionParams: [SendTransactionParam]
  private let tonConnectService: TonConnectService
  private let sendService: SendService
  private let nftService: NFTService
  private let ratesStore: RatesStore
  private let currencyStore: CurrencyStore
  private let confirmTransactionMapper: ConfirmTransactionMapper
  
  init(wallet: Wallet,
       signTransactionParams: [SendTransactionParam],
       tonConnectService: TonConnectService,
       sendService: SendService,
       nftService: NFTService,
       ratesStore: RatesStore,
       currencyStore: CurrencyStore,
       confirmTransactionMapper: ConfirmTransactionMapper) {
    self.wallet = wallet
    self.signTransactionParams = signTransactionParams
    self.tonConnectService = tonConnectService
    self.sendService = sendService
    self.nftService = nftService
    self.ratesStore = ratesStore
    self.currencyStore = currencyStore
    self.confirmTransactionMapper = confirmTransactionMapper
  }
  
  public func createRequestModel() async throws -> ConfirmTransactionModel {
    guard let parameters = signTransactionParams.first else { throw NSError(domain: "", code: 3232) }
    let model = try await emulateAppRequest(appRequestParam: parameters)
    return model
  }
}

private extension TonConnectConfirmationController {
  func emulateAppRequest(appRequestParam: SendTransactionParam) async throws -> ConfirmTransactionModel {
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let boc = try await tonConnectService.createEmulateRequestBoc(
      wallet: wallet,
      seqno: seqno,
      timeout: timeout,
      parameters: appRequestParam
    )
    
    let currency = await currencyStore.getActiveCurrency()
    let rates = ratesStore.getRates(jettons: []).ton.first(where: { $0.currency == currency })
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
  
  func createRequestTransactionBoc(parameters: SendTransactionParam,
                                   signClosure: (WalletTransfer) async throws -> Data) async throws  -> String{
    let seqno = try await sendService.loadSeqno(wallet: wallet)
    let timeout = await sendService.getTimeoutSafely(wallet: wallet)
    let payloads = parameters.messages.map { message in
        TonConnectTransferMessageBuilder.Payload(
            value: BigInt(integerLiteral: message.amount),
            recipientAddress: message.address,
            stateInit: message.stateInit,
            payload: message.payload)
    }
    return try await TonConnectTransferMessageBuilder.sendTonConnectTransfer(
      wallet: wallet,
      seqno: seqno,
      payloads: payloads,
      sender: parameters.from,
      timeout: timeout,
      signClosure: signClosure)
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
