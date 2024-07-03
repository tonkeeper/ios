import Foundation
import TonSwift
import CoreComponents
import TonTransport

public struct ActiveWalletModel: Identifiable {
  public let id: String
  public let revision: WalletContractVersion
  public let address: Address
  public let isActive: Bool
  public let balance: Balance
  public let nfts: [NFT]
  public let isAdded: Bool
  
  public init(id: String, 
              revision: WalletContractVersion,
              address: Address,
              isActive: Bool,
              balance: Balance,
              nfts: [NFT],
              isAdded: Bool = false) {
    self.id = id
    self.revision = revision
    self.address = address
    self.isActive = isActive
    self.balance = balance
    self.nfts = nfts
    self.isAdded = isAdded
  }
}

protocol ActiveWalletsService {
  func loadActiveWallets(publicKey: TonSwift.PublicKey,
                         isTestnet: Bool,
                         currency: Currency) async throws -> [ActiveWalletModel]
  func loadActiveWalletModel(address: Address,
                             revision: WalletContractVersion,
                             isTestnet: Bool,
                             currency: Currency) async throws -> ActiveWalletModel
  func loadActiveWallets(accounts: [(id: String, address: Address, revision: WalletContractVersion)],
                         isTestnet: Bool,
                         currency: Currency) async throws -> [ActiveWalletModel]
}

final class ActiveWalletsServiceImplementation: ActiveWalletsService {
  private let apiProvider: APIProvider
  private let jettonsBalanceService: JettonBalanceService
  private let accountNFTService: AccountNFTService
  private let currencyService: CurrencyService
  private let walletsService: WalletsService
  
  
  init(apiProvider: APIProvider,
       jettonsBalanceService: JettonBalanceService,
       accountNFTService: AccountNFTService,
       currencyService: CurrencyService,
       walletsService: WalletsService) {
    self.apiProvider = apiProvider
    self.jettonsBalanceService = jettonsBalanceService
    self.accountNFTService = accountNFTService
    self.currencyService = currencyService
    self.walletsService = walletsService
  }
  
  func loadActiveWalletModel(address: Address,
                             revision: WalletContractVersion,
                             isTestnet: Bool,
                             currency: Currency) async throws -> ActiveWalletModel {
    async let accountTask = self.apiProvider.api(isTestnet).getAccountInfo(address: address.toRaw())
    async let jettonsBalanceTask = try await self.apiProvider.api(isTestnet).getAccountJettonsBalances(
      address: address,
      currencies: [currency]
    )
    async let nftsTask = self.apiProvider.api(isTestnet).getAccountNftItems(
      address: address,
      collectionAddress: nil,
      limit: nil,
      offset: nil,
      isIndirectOwnership: true
    )

    let account = try await accountTask
    let jettonsBalance = (try? await jettonsBalanceTask) ?? []
    let nfts = (try? await nftsTask) ?? []
    let tonBalance = TonBalance(amount: account.balance)
    let balance = Balance(tonBalance: tonBalance, jettonsBalance: jettonsBalance)
    let isActive = account.status == "active" || !balance.isEmpty
    
    return ActiveWalletModel(
      id: address.toRaw(),
      revision: revision,
      address: address,
      isActive: isActive,
      balance: balance,
      nfts: nfts)
  }
  
  func loadActiveWallets(publicKey: TonSwift.PublicKey, 
                         isTestnet: Bool,
                         currency: Currency) async throws -> [ActiveWalletModel] {
    let revisions = WalletContractVersion.allCases
    
    let models = try await withThrowingTaskGroup(of: ActiveWalletModel.self, returning: [ActiveWalletModel].self) { taskGroup in
      for revision in revisions {
        let address = try createAddress(
          publicKey: publicKey,
          revision: revision,
          networkId: isTestnet ? .testnet : .mainnet
        )
        taskGroup.addTask {
          do {
            return try await self.loadActiveWalletModel(
              address: address,
              revision: revision,
              isTestnet: isTestnet,
              currency: currency)
          } catch {
            return ActiveWalletModel(
              id: address.toRaw(),
              revision: revision,
              address: address,
              isActive: revision == .currentVersion,
              balance: Balance(
                tonBalance: TonBalance(amount: 0),
                jettonsBalance: []
              ),
              nfts: []
            )
          }
        }
      }
      
      var resultModels = [ActiveWalletModel]()
      for try await result in taskGroup {
        guard result.revision != WalletContractVersion.currentVersion else {
          resultModels.append(result)
          continue
        }
        guard result.isActive else {
          continue
        }
        resultModels.append(result)
      }
      return resultModels
    }
    return models
  }
  
  func loadActiveWallets(accounts: [(id: String, address: Address, revision: WalletContractVersion)],
                         isTestnet: Bool,
                         currency: Currency) async throws -> [ActiveWalletModel] {
    let models = try await withThrowingTaskGroup(of: ActiveWalletModel.self, returning: [ActiveWalletModel].self) { taskGroup in
      for account in accounts {
        taskGroup.addTask {
          do {
            return try await self.loadActiveWalletModel(
              address: account.address,
              revision: account.revision,
              isTestnet: isTestnet,
              currency: currency)
          } catch {
            return ActiveWalletModel(
              id: account.id,
              revision: account.revision,
              address: account.address,
              isActive: false,
              balance: Balance(
                tonBalance: TonBalance(amount: 0),
                jettonsBalance: []
              ),
              nfts: []
            )
          }
        }
      }
      
      var resultModels = [ActiveWalletModel]()
      for try await result in taskGroup {
        guard result.isActive else {
          continue
        }
        resultModels.append(result)
      }
      return resultModels
    }
    return models
  }
}

private extension ActiveWalletsServiceImplementation {
  func createAddress(publicKey: TonSwift.PublicKey, revision: WalletContractVersion, networkId: Network) throws -> Address {
    let contract: WalletContract
    switch revision {
    case .v5R1:
      contract = WalletV5R1(
        publicKey: publicKey.data,
        walletId: WalletId(networkGlobalId: Int32(networkId.rawValue), workchain: 0)
      )
    case .v4R2:
      contract = WalletV4R2(publicKey: publicKey.data)
    case .v4R1:
      contract = WalletV4R1(publicKey: publicKey.data)
    case .v3R2:
      contract = try WalletV3(
        workchain: 0,
        publicKey: publicKey.data,
        revision: .r2)
    case .v3R1:
      contract = try WalletV3(
        workchain: 0,
        publicKey: publicKey.data,
        revision: .r1
      )
    }
    return try contract.address()
  }
}
