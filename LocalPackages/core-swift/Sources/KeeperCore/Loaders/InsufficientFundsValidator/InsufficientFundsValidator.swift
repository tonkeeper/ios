import BigInt
import Foundation
import TonSwift

public enum InsufficientFundsError: Error {
    case unknownJetton
    case blockchainFee(
        wallet: Wallet,
        balance: BigUInt,
        amount: BigUInt
    )
    case insufficientFunds(
        jettonInfo: JettonInfo?,
        balance: BigUInt,
        requiredAmount: BigUInt,
        wallet: Wallet,
        isInternalPurchasing: Bool
    )
}

public protocol InsufficientFundsValidator: AnyObject {
    func resolveJettonBalance(
        jettonAddress: Address,
        requiredAmount: BigUInt,
        wallet: Wallet
    ) async throws(InsufficientFundsError) -> JettonBalance
    func validateFundsIfNeeded(
        wallet: Wallet,
        confirmationController: TransactionConfirmationController
    ) async throws(InsufficientFundsError)
    func validateFundsIfNeeded(
        wallet: Wallet,
        emulationModel: TransactionConfirmationModel
    ) async throws(InsufficientFundsError)
    func validateEmulationResultIfNeeded(
        _ emulation: SignRawEmulation,
        wallet: Wallet,
        numOfInternals: Int?
    ) throws(InsufficientFundsError)
}

final class InsufficientFundsValidatorImplementation: InsufficientFundsValidator {
    private let balanceStore: BalanceStore
    private let apiProvider: APIProvider

    private let trustCoins: [Address] = [
        JettonMasterAddress.tonUSDT,
        JettonMasterAddress.NOT,
        JettonMasterAddress.HMSTR,
    ]

    init(
        balanceStore: BalanceStore,
        apiProvider: APIProvider
    ) {
        self.balanceStore = balanceStore
        self.apiProvider = apiProvider
    }

    func resolveJettonBalance(
        jettonAddress: Address,
        requiredAmount: BigUInt,
        wallet: Wallet
    ) async throws(InsufficientFundsError) -> JettonBalance {
        let jettonInfo: JettonInfo
        do {
            jettonInfo = try await apiProvider.api(wallet.network).resolveJetton(address: jettonAddress)
        } catch {
            throw .unknownJetton
        }

        let isInternalPurchasing = trustCoins.contains(jettonInfo.address)
        guard let balance = balanceStore.getState()[wallet]?.walletBalance.balance.jettonsBalance else {
            throw .insufficientFunds(
                jettonInfo: jettonInfo,
                balance: 0,
                requiredAmount: requiredAmount,
                wallet: wallet,
                isInternalPurchasing: isInternalPurchasing
            )
        }

        guard let jettonBalance = balance.first(where: { $0.item.jettonInfo.address == jettonInfo.address }) else {
            throw .insufficientFunds(
                jettonInfo: jettonInfo,
                balance: 0,
                requiredAmount: requiredAmount,
                wallet: wallet,
                isInternalPurchasing: isInternalPurchasing
            )
        }

        return jettonBalance
    }

    func validateFundsIfNeeded(
        wallet: Wallet,
        confirmationController: TransactionConfirmationController
    ) async throws(InsufficientFundsError) {
        let emulationModel = confirmationController.getModel()

        try await validateFundsIfNeeded(wallet: wallet, emulationModel: emulationModel)
    }

    func validateFundsIfNeeded(wallet: Wallet, emulationModel: TransactionConfirmationModel) async throws(InsufficientFundsError) {
        let tonBalanceAmount = balanceStore.getState()[wallet]?.walletBalance.balance.tonBalance.amount ?? 0
        let formattedTonBalance = BigUInt(tonBalanceAmount)

        switch emulationModel.transaction {
        case .staking:
            return
        case let .transfer(transfer):
            switch transfer {
            case let .ton(isMaxAmount):
                // should ignore validation if trying to transfer all tokens
                guard !isMaxAmount else {
                    return
                }

                guard let amount = emulationModel.amount?.value else {
                    return
                }

                guard tonBalanceAmount > 0 else {
                    throw .insufficientFunds(
                        jettonInfo: nil, balance: 0, requiredAmount: amount, wallet: wallet, isInternalPurchasing: true
                    )
                }

                guard case .extra = emulationModel.extraState else {
                    return
                }

                let transferAmount: BigUInt = BigUInt(emulationModel.totalFee)

                let requiredAmount = transferAmount + amount
                guard formattedTonBalance >= requiredAmount else {
                    throw .insufficientFunds(
                        jettonInfo: nil, balance: formattedTonBalance, requiredAmount: requiredAmount, wallet: wallet, isInternalPurchasing: true
                    )
                }
            case let .jetton(jettonInfo):
                guard let amount = emulationModel.amount?.value else {
                    return
                }

                let jettonBalance = try await resolveJettonBalance(
                    jettonAddress: jettonInfo.address, requiredAmount: amount, wallet: wallet
                )

                let balance = jettonBalance.scaledBalance ?? jettonBalance.quantity
                guard balance >= amount else {
                    throw .insufficientFunds(
                        jettonInfo: jettonBalance.item.jettonInfo,
                        balance: balance,
                        requiredAmount: amount,
                        wallet: wallet,
                        isInternalPurchasing: trustCoins.contains(jettonBalance.item.jettonInfo.address)
                    )
                }

                if case let .extra(extra) = emulationModel.extraState {
                    let isRefund = extra.kind == .refund

                    switch extra.value {
                    case let .default(extraAmount):
                        if !isRefund, formattedTonBalance < extraAmount {
                            throw .blockchainFee(wallet: wallet, balance: formattedTonBalance, amount: extraAmount)
                        }
                    case .battery:
                        break
                    case let .gasless(_, extraAmount):
                        let requiredAmount = amount + extraAmount
                        let balance = jettonBalance.scaledBalance ?? jettonBalance.quantity
                        if requiredAmount > balance {
                            throw .blockchainFee(wallet: wallet, balance: balance, amount: requiredAmount)
                        }
                    }
                }
            case .nft:
                if case let .extra(extra) = emulationModel.extraState {
                    let isRefund = extra.kind == .refund
                    switch extra.value {
                    case let .default(extraAmount):
                        if !isRefund, formattedTonBalance < extraAmount {
                            throw .blockchainFee(wallet: wallet, balance: formattedTonBalance, amount: extraAmount)
                        }
                    case .battery, .gasless:
                        break
                    }
                }
            case .tronUSDT:
                break
            }
        }
    }

    func validateEmulationResultIfNeeded(
        _ emulation: SignRawEmulation,
        wallet: Wallet,
        numOfInternals: Int? = nil
    ) throws(InsufficientFundsError) {
        guard let walletBalance = balanceStore.getState()[wallet]?.walletBalance else {
            return
        }

        let tonBalance = UInt64(walletBalance.balance.tonBalance.amount)

        var requiredAmount: BigUInt?
        var token: TonToken?
        var availableBalance: BigUInt?

        guard !emulation.transferType.isBattery, !emulation.transferType.isGasless else {
            return
        }

        let fee = emulation.totalFees

        guard let numOfInternals, emulation.traceChildrenCount == numOfInternals else {
            throw .insufficientFunds(
                jettonInfo: nil,
                balance: BigUInt(tonBalance),
                requiredAmount: BigUInt(emulation.risk.ton) + BigUInt(fee),
                wallet: wallet,
                isInternalPurchasing: true
            )
        }

        if !emulation.risk.jettons.isEmpty {
            for jetton in emulation.risk.jettons {
                guard let balance = walletBalance.balance.jettonsBalance.first(where: { jetton.walletAddress == $0.item.walletAddress }) else {
                    continue
                }

                requiredAmount = jetton.quantity
                availableBalance = balance.quantity
                token = .jetton(balance.item)
            }
        } else {
            requiredAmount = BigUInt(emulation.risk.ton) + BigUInt(fee)
            availableBalance = BigUInt(tonBalance)
            token = .ton
        }

        guard let requiredAmount, let token, let availableBalance else {
            return
        }

        let formattedRequiredAmount = BigUInt(requiredAmount)
        switch token {
        case .ton:
            guard formattedRequiredAmount <= availableBalance else {
                throw .insufficientFunds(
                    jettonInfo: nil,
                    balance: availableBalance,
                    requiredAmount: formattedRequiredAmount,
                    wallet: wallet,
                    isInternalPurchasing: true
                )
            }
        case let .jetton(jettonItem):
            guard formattedRequiredAmount <= availableBalance else {
                throw .insufficientFunds(
                    jettonInfo: jettonItem.jettonInfo,
                    balance: availableBalance,
                    requiredAmount: formattedRequiredAmount,
                    wallet: wallet,
                    isInternalPurchasing: trustCoins.contains(jettonItem.jettonInfo.address)
                )
            }

            guard fee <= tonBalance else {
                throw .blockchainFee(wallet: wallet, balance: BigUInt(tonBalance), amount: BigUInt(fee))
            }
        }
    }
}
