import BigInt
import Foundation
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
    private let tonProofTokenService: TonProofTokenService
    private let walletBalanceRepository: WalletBalanceRepository

    init(
        tonBalanceService: TonBalanceService,
        jettonsBalanceService: JettonBalanceService,
        tronBalanceService: TronBalanceService,
        batteryService: BatteryService,
        stackingService: StakingService,
        tonProofTokenService: TonProofTokenService,
        walletBalanceRepository: WalletBalanceRepository
    ) {
        self.tonBalanceService = tonBalanceService
        self.jettonsBalanceService = jettonsBalanceService
        self.tronBalanceService = tronBalanceService
        self.batteryService = batteryService
        self.stackingService = stackingService
        self.tonProofTokenService = tonProofTokenService
        self.walletBalanceRepository = walletBalanceRepository
    }

    func loadWalletBalance(
        wallet: Wallet,
        currency: Currency,
        includingTransferFees: Bool
    ) async throws -> WalletBalance {
        async let tonBalanceTask = tonBalanceService.loadBalance(wallet: wallet)
        async let jettonsBalanceTask = jettonsBalanceService.loadJettonsBalance(wallet: wallet, currency: currency)
        async let stackingBalanceTask = stackingService.loadStakingBalance(wallet: wallet)
        async let batteryBalanceTask = batteryService.loadBatteryBalance(
            wallet: wallet,
            tonProofToken: tonProofTokenService.getWalletToken(wallet)
        )

        async let tronBalanceTask: () async -> TronBalance? = { [tronBalanceService, walletBalanceRepository] in
            guard
                wallet.isTronTurnOn,
                let address = wallet.tron?.address else { return nil }
            do {
                let rawBalance = try await tronBalanceService.loadBalance(
                    address: address,
                    includingTransferFees: includingTransferFees
                )
                if includingTransferFees {
                    return rawBalance
                } else {
                    let cachedBalance = try? walletBalanceRepository
                        .getWalletBalance(wallet: wallet)
                        .tronBalance
                    return TronBalance(
                        amount: rawBalance.amount,
                        trxAmount: cachedBalance?.trxAmount ?? rawBalance.trxAmount
                    )
                }
            } catch {
                return TronBalance(amount: 0, trxAmount: 0)
            }
        }

        let tonBalance = try await tonBalanceTask
        let jettonsBalance = try await jettonsBalanceTask
        let batteryBalance: BatteryBalance?
        do {
            batteryBalance = try await batteryBalanceTask
        } catch {
            batteryBalance = nil
        }

        let stackingBalance: [AccountStackingInfo]
        do {
            stackingBalance = try await stackingBalanceTask
        } catch {
            stackingBalance = []
        }

        let tronBalance: TronBalance? = await tronBalanceTask()

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
    }

    func getBalance(wallet: Wallet) throws -> WalletBalance {
        try walletBalanceRepository.getWalletBalance(wallet: wallet)
    }
}
