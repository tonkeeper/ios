import Foundation
import TonSwift
import CoreComponents
import TonTransport

public struct ActiveWalletModel {
  public let revision: WalletContractVersion
  public let address: Address
  public let isActive: Bool
  public let balance: Balance
  public let nfts: [NFT]
  public let ledgerIndex: Int
  public let isLedgerAdded: Bool
  
  public init(revision: WalletContractVersion, address: Address, isActive: Bool, balance: Balance, nfts: [NFT], ledgerIndex: Int = 0, isLedgerAdded: Bool = false) {
    self.revision = revision
    self.address = address
    self.isActive = isActive
    self.balance = balance
    self.nfts = nfts
    self.ledgerIndex = ledgerIndex
    self.isLedgerAdded = isLedgerAdded
  }
}

protocol ActiveWalletsService {
  func loadActiveWallets(publicKey: TonSwift.PublicKey, isTestnet: Bool) async throws -> [ActiveWalletModel]
  func loadActiveWallets(ledgerAccounts: [LedgerAccount], deviceId: String) async throws -> [ActiveWalletModel]
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
  
  func loadActiveWallets(publicKey: TonSwift.PublicKey, isTestnet: Bool) async throws -> [ActiveWalletModel] {
    let revisions = WalletContractVersion.allCases
    
    let models = try await withThrowingTaskGroup(of: ActiveWalletModel.self, returning: [ActiveWalletModel].self) { [currencyService] taskGroup in
      for revision in revisions {
        let address = try createAddress(
          publicKey: publicKey,
          revision: revision,
          networkId: isTestnet ? .testnet : .mainnet
        )
        taskGroup.addTask {
          async let accountTask = self.apiProvider.api(isTestnet).getAccountInfo(address: address.toRaw())
          async let jettonsBalanceTask = try await self.apiProvider.api(isTestnet).getAccountJettonsBalances(
            address: address,
            currencies: [(try? currencyService.getActiveCurrency()) ?? .USD]
          )
          async let nftsTask = self.apiProvider.api(isTestnet).getAccountNftItems(
            address: address,
            collectionAddress: nil,
            limit: nil,
            offset: nil,
            isIndirectOwnership: true
          )
          let isActive: Bool
          let balance: Balance
          let nfts: [NFT]
          do {
            let account = try await accountTask
            let jettonsBalance = (try? await jettonsBalanceTask) ?? []
            nfts = (try? await nftsTask) ?? []
            let tonBalance = TonBalance(amount: account.balance)
            balance = Balance(tonBalance: tonBalance, jettonsBalance: jettonsBalance)
            isActive = account.status == "active" || !balance.isEmpty
          } catch {
            isActive = revision == .currentVersion
            nfts = []
            balance = Balance(
              tonBalance: TonBalance(amount: 0),
              jettonsBalance: []
            )
          }
          
          return ActiveWalletModel(
            revision: revision,
            address: address,
            isActive: isActive,
            balance: balance,
            nfts: nfts)
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
  
  func loadActiveWallets(ledgerAccounts: [LedgerAccount], deviceId: String) async throws -> [ActiveWalletModel] {
    let addedDeviceAccountIndexes: [Int]
    
    do {
      addedDeviceAccountIndexes = try walletsService.getWallets().compactMap { wallet -> Int? in
        if case let .Ledger(_, _, ledgerDevice) = wallet.identity.kind, ledgerDevice.deviceId == deviceId {
          return Int(ledgerDevice.accountIndex)
        } else {
          return nil
        }
      }
    } catch {
      addedDeviceAccountIndexes = []
    }
    
    let models = try await withThrowingTaskGroup(of: ActiveWalletModel.self, returning: [ActiveWalletModel].self) { [currencyService] taskGroup in
      for account in ledgerAccounts {
        let address = account.address
        taskGroup.addTask {
          async let accountTask = self.apiProvider.api(false).getAccountInfo(address: address.toRaw())
          async let jettonsBalanceTask = try await self.apiProvider.api(false).getAccountJettonsBalances(
            address: address,
            currencies: [(try? currencyService.getActiveCurrency()) ?? .USD]
          )
          async let nftsTask = self.apiProvider.api(false).getAccountNftItems(
            address: address,
            collectionAddress: nil,
            limit: nil,
            offset: nil,
            isIndirectOwnership: true
          )
          let isAdded = addedDeviceAccountIndexes.contains(account.path.index)
          let isActive: Bool
          let balance: Balance
          let nfts: [NFT]
          do {
            let account = try await accountTask
            let jettonsBalance = (try? await jettonsBalanceTask) ?? []
            nfts = (try? await nftsTask) ?? []
            let tonBalance = TonBalance(amount: account.balance)
            balance = Balance(tonBalance: tonBalance, jettonsBalance: jettonsBalance)
            isActive = (account.status == "active" || !balance.isEmpty) && !isAdded
          } catch {
            isActive = false
            nfts = []
            balance = Balance(
              tonBalance: TonBalance(amount: 0),
              jettonsBalance: []
            )
          }
          
          
          return ActiveWalletModel(
            revision: .v4R2,
            address: address,
            isActive: isActive,
            balance: balance,
            nfts: nfts,
            ledgerIndex: account.path.index,
            isLedgerAdded: isAdded)
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
