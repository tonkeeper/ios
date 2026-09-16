import BigInt
import Foundation
import TKLogging
import TonSwift

public protocol BalanceService {
    func loadWalletBalance(
        wallet: Wallet,
        currency: Currency,
        includingTransferFees: Bool
    ) async throws -> WalletBalance
    func getBalance(wallet: Wallet) throws -> WalletBalance
}

final class BalanceServiceImplementation: BalanceService {
    private let tonBalanceService: TonBalanceService
    private let jettonsBalanceService: JettonBalanceService
    private let tronBalanceService: TronBalanceService
    private let batteryService: BatteryService
    private let stackingService: StakingService
    private let walletBalanceRepository: WalletBalanceRepository

    init(
        tonBalanceService: TonBalanceService,
        jettonsBalanceService: JettonBalanceService,
        tronBalanceService: TronBalanceService,
        batteryService: BatteryService,
        stackingService: StakingService,
        walletBalanceRepository: WalletBalanceRepository
    ) {
        self.tonBalanceService = tonBalanceService
        self.jettonsBalanceService = jettonsBalanceService
        self.tronBalanceService = tronBalanceService
        self.batteryService = batteryService
        self.stackingService = stackingService
        self.walletBalanceRepository = walletBalanceRepository
    }

    func loadWalletBalance(
        wallet: Wallet,
        currency: Currency,
        includingTransferFees: Bool
    ) async throws -> WalletBalance {
        let tonBalanceTask = Task {
            try await tonBalanceService.loadBalance(wallet: wallet)
        }
        let jettonsBalanceTask = Task {
            try await jettonsBalanceService.loadJettonsBalance(wallet: wallet, currency: currency)
        }
        let stackingBalanceTask = Task {
            try await stackingService.loadStakingBalance(wallet: wallet)
        }
        let batteryBalanceTask: Task<BatteryBalance, Error>?
        if includingTransferFees {
            batteryBalanceTask = Task {
                try await batteryService.loadBatteryBalance(wallet: wallet)
            }
        } else {
            // List / all-wallets refresh uses includingTransferFees: false. Battery is
            // per-wallet auth but the same /balance?units=ton URL; fetching it for every
            // wallet in the list duplicated work without affecting list totals.
            batteryBalanceTask = nil
        }
        let tronBalanceTask = Task<TronBalance?, Never> { [tronBalanceService, walletBalanceRepository] in
            guard let address = wallet.tron?.address else { return nil }
            do {
                return try await tronBalanceService.loadBalance(address: address)
            } catch {
                if !error.isCancelledError {
                    Log.tron.w("Tron balance load failed", error: error, extraInfo: [
                        "address": address.base58,
                    ])
                }
                let cachedBalance = try? walletBalanceRepository
                    .getWalletBalance(wallet: wallet)
                    .tronBalance
                return cachedBalance ?? TronBalance(amount: 0, trxAmount: 0)
            }
        }

        return try await withTaskCancellationHandler(operation: {
            let tonBalance = try await tonBalanceTask.value
            let jettonsBalance = try await jettonsBalanceTask.value
            let batteryBalance: BatteryBalance?
            if let batteryBalanceTask {
                do {
                    batteryBalance = try await batteryBalanceTask.value
                } catch {
                    batteryBalance = nil
                }
            } else {
                batteryBalance = try? walletBalanceRepository
                    .getWalletBalance(wallet: wallet)
                    .batteryBalance
            }

            let stackingBalance: [AccountStackingInfo]
            do {
                stackingBalance = try await stackingBalanceTask.value
            } catch {
                stackingBalance = []
            }

            let tronBalance = await tronBalanceTask.value

            let balance = Balance(
                tonBalance: tonBalance,
                jettonsBalance: jettonsBalance
            )

            let walletBalance = WalletBalance(
                date: Date(),
                balance: balance,
                stacking: stackingBalance,
                batteryBalance: batteryBalance,
                tronBalance: tronBalance
            )

            try? walletBalanceRepository.saveWalletBalance(
                walletBalance,
                for: wallet
            )

            return walletBalance
        }, onCancel: {
            tonBalanceTask.cancel()
            jettonsBalanceTask.cancel()
            stackingBalanceTask.cancel()
            batteryBalanceTask?.cancel()
            tronBalanceTask.cancel()
        })
    }

    func getBalance(wallet: Wallet) throws -> WalletBalance {
        try walletBalanceRepository.getWalletBalance(wallet: wallet)
    }
}
