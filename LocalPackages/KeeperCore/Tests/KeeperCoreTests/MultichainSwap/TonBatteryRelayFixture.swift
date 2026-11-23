import Foundation
@testable import KeeperCore
import KeeperCoreComponents
import TKBatteryAPI
import TKFeatureFlags
import TonAPI
import TonSwift

/// Enough of the TON stack for a transfer to be prepared, signed and relayed through the battery
/// without a network: the battery prices every message at 0.026 TON — 10 charges at the 0.0026 TON
/// a charge the configuration names — and relays what it is handed, the seqno moves on every read,
/// and the wallet holds no jettons. The battery's balance of charges cannot be read.
final class TonBatteryRelayFixture {
    /// The seqno reads and relays, and anything a test records between them, in order.
    final class Calls {
        private(set) var recorded = [String]()
        private(set) var relayed = [String]()
        /// The send proof each relayed message came with.
        private(set) var proofs = [String?]()
        /// What the battery names as the hash of its own message for each relay.
        var relayerMessageHash: String?
        var relayError: Error?
        var balanceError: Error?
        var allowsTonAPISend = false

        func record(_ call: String) {
            recorded.append(call)
        }

        func relay(_ boc: String, proof: String?) {
            recorded.append("relay")
            relayed.append(boc)
            proofs.append(proof)
        }
    }

    static let timeout: UInt64 = 1_790_000_600
    static let excessAccount = "0:0000000000000000000000000000000000000000000000000000000000000004"

    let calls: Calls
    let configuration: KeeperCore.Configuration
    let batteryService: BatteryService
    let balanceService: BalanceService = EmptyBalance()

    init(featureFlags: TKFeatureFlags = DummyFeatureFlags(), trxOnlyRegion: Bool = true) throws {
        let calls = Calls()
        let mainnet = try JSONDecoder().decode(BootConfiguration.self, from: Data(#"{"batteryMeanFees": "0.0026", "flags": {"trx_only_region": \#(trxOnlyRegion)}}"#.utf8))
        self.calls = calls
        configuration = KeeperCore.Configuration(
            bootConfigurationService: Boot(configurations: BootConfigurations(mainnet: mainnet, testnet: .empty)),
            featureFlags: featureFlags,
            tkAppSettings: AppSettings()
        )
        batteryService = try Battery(calls: calls)
    }

    /// A seqno read after another is the next one, so a transfer prepared twice is two transfers;
    /// reads past `seqnoReads` fail.
    func transferService(seqnoReads: Int = .max) -> TransferService {
        TransferService(
            batteryService: batteryService,
            balanceService: balanceService,
            sendService: Send(calls: calls, reads: seqnoReads),
            accountService: UnusedAccounts(),
            configuration: configuration,
            settingsRepository: SettingsRepository(settingsVault: SettingsVault(userDefaults: UserDefaults())),
            currencyStore: CurrencyStore(keeperInfoStore: KeeperInfoStore(keeperInfoRepository: EmptyKeeperInfoRepositoryStub()))
        )
    }
}

private extension TonBatteryRelayFixture {
    struct Unused: Error {}
    struct SeqnoUnavailable: Error {}

    final class Send: SendService {
        private let calls: Calls
        private var readsLeft: Int
        private var seqno: UInt64 = 6

        init(calls: Calls, reads: Int) {
            self.calls = calls
            readsLeft = reads
        }

        func loadSeqno(wallet _: Wallet) async throws -> UInt64 {
            calls.record("seqno")
            guard readsLeft > 0 else {
                throw SeqnoUnavailable()
            }
            readsLeft -= 1
            seqno += 1
            return seqno
        }

        func loadTransactionInfo(
            boc _: String,
            wallet _: Wallet,
            params _: [EmulateMessageToWalletRequestParamsInner]?,
            currency _: Currency?
        ) async throws -> TonAPI.Components.Schemas.MessageConsequences {
            throw Unused()
        }

        func sendTransaction(boc _: String, wallet _: Wallet, headers _: [String: String]) async throws {
            guard calls.allowsTonAPISend else { throw Unused() }
            calls.record("tonapi")
        }

        func sendTransactions(batch _: [String], wallet _: Wallet) async throws {
            guard calls.allowsTonAPISend else { throw Unused() }
            calls.record("tonapi")
        }

        func getTimeoutSafely(wallet _: Wallet, TTL _: UInt64) async -> UInt64 {
            TonBatteryRelayFixture.timeout
        }

        func getGaslessRelayAddress(wallet _: Wallet) async throws -> TonSwift.Address {
            throw Unused()
        }

        func getJettonCustomPayload(wallet _: Wallet, jetton _: TonSwift.Address) async throws -> JettonTransferPayload {
            throw Unused()
        }

        func getIndexingLatency(wallet _: Wallet) async throws -> Int {
            throw Unused()
        }
    }

    struct Battery: BatteryService {
        let calls: Calls
        let config: TKBatteryAPI.Components.Schemas.Config
        let consequences: TonAPI.Components.Schemas.MessageConsequences

        init(calls: Calls) throws {
            self.calls = calls
            config = try JSONDecoder().decode(TKBatteryAPI.Components.Schemas.Config.self, from: Data(#"""
            {
              "charge_cost": "0.0026",
              "fund_receiver": "0:0000000000000000000000000000000000000000000000000000000000000003",
              "excess_account": "\#(TonBatteryRelayFixture.excessAccount)",
              "message_ttl": 300,
              "gas_proxy": [],
              "mean_prices": {"battery_mean_price_swap": 1, "battery_mean_price_jetton": 1, "battery_mean_price_nft": 1},
              "battery_reserved_amount": "0",
              "packages": [],
              "transfer_cost": {"default": "50000000", "jettons": []}
            }
            """#.utf8))
            let account = #"{"address": "0:0000000000000000000000000000000000000000000000000000000000000005", "is_scam": false, "is_wallet": true}"#
            consequences = try JSONDecoder().decode(TonAPI.Components.Schemas.MessageConsequences.self, from: Data(#"""
            {
              "trace": {
                "transaction": {
                  "hash": "00", "lt": 1, "account": \#(account), "success": true, "utime": 1,
                  "orig_status": "active", "end_status": "active", "total_fees": 1, "end_balance": 1,
                  "transaction_type": "TransOrd", "state_update_old": "", "state_update_new": "",
                  "out_msgs": [], "block": "", "aborted": false, "destroyed": false, "raw": ""
                },
                "interfaces": []
              },
              "risk": {"transfer_all_remaining_balance": false, "gram": 0, "jettons": [], "nfts": []},
              "event": {
                "event_id": "event", "account": \#(account), "timestamp": 1, "actions": [], "is_scam": false,
                "lt": 1, "in_progress": false, "extra": -26000000, "progress": 1
              }
            }
            """#.utf8))
        }

        func loadBatteryConfig(wallet _: Wallet) async throws -> TKBatteryAPI.Components.Schemas.Config {
            config
        }

        func loadTransactionInfo(
            wallet _: Wallet,
            boc _: String
        ) async throws -> (info: TonAPI.Components.Schemas.MessageConsequences, isBatteryAvailable: Bool, excess: UInt?) {
            (consequences, true, nil)
        }

        func sendTransaction(wallet _: Wallet, boc: String, proof: String?, headers _: [String: String]) async throws -> String? {
            if let error = calls.relayError { throw error }
            calls.relay(boc, proof: proof)
            return calls.relayerMessageHash
        }

        func loadBatteryBalance(wallet _: Wallet) async throws -> BatteryBalance {
            if let error = calls.balanceError { throw error }
            throw Unused()
        }

        func loadRechargeMethods(wallet _: Wallet, includeRechargeOnly _: Bool) async throws -> [BatteryRechargeMethod] {
            throw Unused()
        }

        func getRechargeMethods(wallet _: Wallet, includeRechargeOnly _: Bool) -> [BatteryRechargeMethod] {
            []
        }

        func loadGasslessCommission(wallet _: Wallet, jettonMasterAddress _: String, boc _: String) async throws -> String {
            throw Unused()
        }

        func makePurchase(
            wallet _: Wallet,
            transactionId _: String,
            promocode _: String?
        ) async throws -> TKBatteryAPI.Components.Schemas.iOSBatteryPurchaseStatus {
            throw Unused()
        }

        func loadPurchases(wallet _: Wallet) async throws -> [BatteryPurchase] {
            throw Unused()
        }

        func migrateBattery(
            from _: Wallet,
            to _: Wallet,
            proof _: BatteryMigrationProof
        ) async throws -> TKBatteryAPI.Components.Schemas.BatteryMigration {
            throw Unused()
        }

        func loadTronTransactions(wallet _: Wallet, limit _: Int, maxTimestamp _: Int64?) async throws -> [TronTransaction] {
            throw Unused()
        }

        func estimateTronTransaction(
            wallet _: Wallet,
            tronAddress _: String,
            energy _: Int,
            bandwidth _: Int
        ) async throws -> TKBatteryAPI.Components.Schemas.EstimatedTronTx {
            throw Unused()
        }

        func sendTronTransaction(
            wallet _: Wallet,
            tronAddress _: String,
            transaction _: String,
            energy _: Int,
            bandwidth _: Int,
            instantFeeTransaction _: String?,
            userPublicKey _: String?
        ) async throws -> String {
            throw Unused()
        }

        func hasPendingTransactions(wallet _: Wallet) async throws -> Bool {
            throw Unused()
        }

        func verifyPromocode(wallet _: Wallet, promocode _: String) async throws {
            throw Unused()
        }
    }

    struct EmptyBalance: BalanceService {
        func loadWalletBalance(wallet: Wallet, currency _: Currency, includingTransferFees _: Bool) async throws -> WalletBalance {
            try getBalance(wallet: wallet)
        }

        func getBalance(wallet _: Wallet) throws -> WalletBalance {
            WalletBalance(
                date: Date(),
                balance: KeeperCore.Balance(tonBalance: TonBalance(amount: 1_000_000_000), jettonsBalance: []),
                stacking: [],
                batteryBalance: nil,
                tronBalance: nil
            )
        }
    }

    struct UnusedAccounts: AccountService {
        func loadAccount(network _: KeeperCore.Network, address _: TonSwift.Address) async throws -> KeeperCore.Account {
            throw Unused()
        }

        func loadAccount(network _: KeeperCore.Network, domain _: String) async throws -> KeeperCore.Account {
            throw Unused()
        }
    }

    struct Boot: BootConfigurationService {
        let configurations: BootConfigurations

        func getConfiguration() throws -> BootConfigurations {
            configurations
        }

        func loadConfiguration() async throws -> BootConfigurations {
            configurations
        }
    }

    final class AppSettings: TKAppSettings {
        var isConfirmButtonInsteadSlider = false
        var raffleIsNewUser: Bool?
    }
}
