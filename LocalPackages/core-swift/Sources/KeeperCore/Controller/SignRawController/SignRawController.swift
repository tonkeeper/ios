import Foundation
import TonSwift
import BigInt
import TonAPI

public enum SignRawEmulationResult {
  case success(SignRawEmulation)
  case failed
  
  public var transactionType: TransferType {
    switch self {
    case .success(let signRawEmulation):
      return signRawEmulation.transferType
    case .failed:
      return .default
    }
  }
}

public struct SignRawEmulation {
  public struct Risk {
    public struct Jetton {
      public let walletAddress: Address
      public let quantity: BigUInt
    }
    
    public let ton: UInt64
    public let jettons: [Jetton]
    public let nftsCount: Int
    public let totalAmountTreshold: Decimal = 0.2
  }
  
  public struct FeeConverted {
    public let converted: Decimal
    public let currency: Currency
  }
  
  public let event: AccountEvent
  public let fee: UInt64
  public let feeConverted: FeeConverted?
  public let risk: Risk
  public let nfts: NFTsCollection
  public let transferType: TransferType
}

public protocol SignRawControllerResultHandler {
  func didConfirm(boc: String)
  func didFail(error: Swift.Error)
  func didCancel()
}

public final class SignRawController {
  
  public var signHandler: ((TransferData, Wallet) async throws -> WalletSignedData?)?
  
  private let wallet: Wallet
  private let transferProvider: () async throws -> Transfer
  private let transferService: TransferService
  private let nftService: NFTService
  private let tonRatesStore: TonRatesStore
  private let currencyStore: CurrencyStore
  private let resultHandler: SignRawControllerResultHandler?
  
  public init(wallet: Wallet,
              transferProvider: @escaping () async throws -> Transfer,
              transferService: TransferService,
              nftService: NFTService,
              tonRatesStore: TonRatesStore,
              currencyStore: CurrencyStore,
              resultHandler: SignRawControllerResultHandler?) {
    self.wallet = wallet
    self.transferProvider = transferProvider
    self.transferService = transferService
    self.nftService = nftService
    self.tonRatesStore = tonRatesStore
    self.currencyStore = currencyStore
    self.resultHandler = resultHandler
  }
  
  public func sendTransaction(transactionType: TransferType) async throws {
    let boc = try await transferService.sendTransaction(
      wallet: wallet,
      transfer: try await transferProvider(),
      transferType: transactionType,
      signClosure: { [weak self, wallet] transferData in
        guard let signed = try? await self?.signHandler?(transferData, wallet) else {
          throw TransactionConfirmationError.failedToSign
        }
        return signed
      }
    )
    resultHandler?.didConfirm(boc: boc)
  }
  
  public func cancel() {
    resultHandler?.didCancel()
  }
  
  public func emulate() async throws -> SignRawEmulation {
    let result = try await transferService.emulate(
      wallet: wallet,
      transfer: try await transferProvider()
    )
    let event = try AccountEvent(accountEvent: result.transactionInfo.event)
    let fee = UInt64(abs(result.transactionInfo.event.extra))
    let nfts = try await loadEventNFTs(event: event)
    let risk = handleRisk(risk: result.transactionInfo.risk)
    let currency = currencyStore.state
    var feeConverted: SignRawEmulation.FeeConverted?
    if let rates = tonRatesStore.state.first(where: { $0.currency == currency }) {
      feeConverted = SignRawEmulation.FeeConverted(
        converted: RateConverter().convertToDecimal(
          amount: BigUInt(fee),
          amountFractionLength: TonInfo.fractionDigits,
          rate: rates
        ),
        currency: currency
      )
    }
    
    return SignRawEmulation(
      event: event,
      fee: fee,
      feeConverted: feeConverted,
      risk: risk,
      nfts: nfts,
      transferType: result.transferType
    )
  }
  
  private func handleRisk(risk: TonAPI.Risk) -> SignRawEmulation.Risk {
    SignRawEmulation.Risk(
      ton: UInt64(risk.ton),
      jettons: risk.jettons.compactMap { try? SignRawEmulation.Risk.Jetton(walletAddress: Address.parse($0.walletAddress.address), quantity: BigUInt(stringLiteral: $0.quantity)) },
      nftsCount: risk.nfts.count
    )
  }
  
  private func loadEventNFTs(event: AccountEvent) async throws -> NFTsCollection {
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
