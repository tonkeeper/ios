import Foundation
import KeeperCoreComponents
import TonSwift
import TonTransport

public enum ActiveWalletTransactionHistory {
    case empty
    case nonEmpty
    case unknown
}

public struct ActiveWalletModel: Identifiable {
    public let id: String
    public let revision: WalletContractVersion
    public let address: Address
    public let isActive: Bool
    public let balance: Balance
    public let nfts: [NFT]
    public let isAdded: Bool
    public let history: ActiveWalletTransactionHistory

    public init(
        id: String,
        revision: WalletContractVersion,
        address: Address,
        isActive: Bool,
        balance: Balance,
        nfts: [NFT],
        isAdded: Bool = false,
        history: ActiveWalletTransactionHistory
    ) {
        self.id = id
        self.revision = revision
        self.address = address
        self.isActive = isActive
        self.balance = balance
        self.nfts = nfts
        self.isAdded = isAdded
        self.history = history
    }
}

protocol ActiveWalletsService {
    func loadActiveWallets(
        publicKey: TonSwift.PublicKey,
        network: Network,
        currency: Currency,
        checkHistory: Bool
    ) async throws -> [ActiveWalletModel]
    func loadActiveWallets(
        accounts: [(id: String, address: Address, revision: WalletContractVersion)],
        network: Network,
        currency: Currency,
        checkHistory: Bool
    ) async throws -> [ActiveWalletModel]
}

final class ActiveWalletsServiceImplementation: ActiveWalletsService {
    private let apiProvider: APIProvider
    private let jettonsBalanceService: JettonBalanceService
    private let accountNFTService: AccountNFTService
    private let walletsService: WalletsService

    init(
        apiProvider: APIProvider,
        jettonsBalanceService: JettonBalanceService,
        accountNFTService: AccountNFTService,
        walletsService: WalletsService
    ) {
        self.apiProvider = apiProvider
        self.jettonsBalanceService = jettonsBalanceService
        self.accountNFTService = accountNFTService
        self.walletsService = walletsService
    }

    func loadActiveWalletModel(
        id: String,
        address: Address,
        revision: WalletContractVersion,
        network: Network,
        currency: Currency,
        checkHistory: Bool
    ) async throws -> ActiveWalletModel {
        async let accountTask = self.apiProvider.api(network).getAccountInfo(accountId: address.toRaw())
        async let jettonsBalanceTask = try await self.apiProvider.api(network).getAccountJettonsBalances(
            address: address,
            currencies: [currency]
        )
        async let nftsTask = self.apiProvider.api(network).getAccountNftItems(
            address: address,
            collectionAddress: nil,
            limit: nil,
            offset: nil,
            isIndirectOwnership: true
        )

        let hasNonEmptyTransactionsHistoryJob: () async -> ActiveWalletTransactionHistory = { [weak self] in
            guard let self else {
                return .unknown
            }
            if checkHistory {
                let accountEvents = try? await self.apiProvider.api(network).getAccountEvents(
                    address: address,
                    beforeLt: nil,
                    limit: 1
                ).events
                guard let accountEvents else {
                    return .unknown
                }
                return accountEvents.isEmpty ? .empty : .nonEmpty
            } else {
                return .unknown
            }
        }

        async let hasNonEmptyTransactionsHistoryTask = hasNonEmptyTransactionsHistoryJob()

        let account = try await accountTask
        let jettonsBalance = (try? await jettonsBalanceTask) ?? []
        let nfts = (try? await nftsTask) ?? []
        let tonBalance = TonBalance(amount: account.balance)
        let balance = Balance(tonBalance: tonBalance, jettonsBalance: jettonsBalance)
        let isActive = account.status == "active" || !balance.isEmpty

        return ActiveWalletModel(
            id: id,
            revision: revision,
            address: address,
            isActive: isActive,
            balance: balance,
            nfts: nfts,
            history: await hasNonEmptyTransactionsHistoryTask
        )
    }

    func loadActiveWallets(
        publicKey: TonSwift.PublicKey,
        network: Network,
        currency: Currency,
        checkHistory: Bool
    ) async throws -> [ActiveWalletModel] {
        let revisions = WalletContractVersion.allCases

        return try await withThrowingTaskGroup(of: ActiveWalletModel.self, returning: [ActiveWalletModel].self) { taskGroup in
            for revision in revisions {
                let address = try createAddress(
                    publicKey: publicKey,
                    revision: revision,
                    networkId: network
                )
                taskGroup.addTask {
                    do {
                        return try await self.loadActiveWalletModel(
                            id: address.toRaw(),
                            address: address,
                            revision: revision,
                            network: network,
                            currency: currency,
                            checkHistory: checkHistory
                        )
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
                            nfts: [],
                            history: .unknown
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
    }

    func loadActiveWallets(
        accounts: [(id: String, address: Address, revision: WalletContractVersion)],
        network: Network,
        currency: Currency,
        checkHistory: Bool
    ) async throws -> [ActiveWalletModel] {
        return try await withThrowingTaskGroup(of: ActiveWalletModel.self, returning: [ActiveWalletModel].self) { taskGroup in
            for account in accounts {
                taskGroup.addTask {
                    do {
                        return try await self.loadActiveWalletModel(
                            id: account.id,
                            address: account.address,
                            revision: account.revision,
                            network: network,
                            currency: currency,
                            checkHistory: checkHistory
                        )
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
                            nfts: [],
                            history: .unknown
                        )
                    }
                }
            }

            var resultModels = [ActiveWalletModel]()
            for try await result in taskGroup {
                // TODO: refactor
                //        guard result.isActive else {
                //          continue
                //        }
                resultModels.append(result)
            }
            return resultModels
        }
    }
}

private extension ActiveWalletsServiceImplementation {
    func createAddress(publicKey: TonSwift.PublicKey, revision: WalletContractVersion, networkId: Network) throws -> Address {
        let networkRawValue = networkId.rawValue

        let contract: WalletContract
        switch revision {
        case .v5R1:
            contract = WalletV5R1(
                publicKey: publicKey.data,
                walletId: WalletId(networkGlobalId: Int32(networkRawValue), workchain: 0)
            )
        case .v5Beta:
            contract = WalletV5Beta(
                publicKey: publicKey.data,
                walletId: WalletIdBeta(networkGlobalId: Int32(networkRawValue), workchain: 0)
            )
        case .v4R2:
            contract = WalletV4R2(publicKey: publicKey.data)
        case .v4R1:
            contract = WalletV4R1(publicKey: publicKey.data)
        case .v3R2:
            contract = try WalletV3(
                workchain: 0,
                publicKey: publicKey.data,
                revision: .r2
            )
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
