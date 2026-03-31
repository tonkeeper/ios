import Foundation
import KeeperCore
import TonSwift

actor BatteryCryptoRechargeMethodsProvider {
    private var loadRechargeMethodsTask: Task<[BatteryRechargeMethod], Never>?
    private var balanceLoadTask: Task<KeeperCore.WalletBalance, Swift.Error>?

    private let wallet: Wallet
    private let balanceService: BalanceService
    private let batteryService: BatteryService
    private let jettonService: JettonService

    init(
        wallet: Wallet,
        balanceService: BalanceService,
        batteryService: BatteryService,
        jettonService: JettonService
    ) {
        self.wallet = wallet
        self.balanceService = balanceService
        self.batteryService = batteryService
        self.jettonService = jettonService
    }

    func getAllRechargeMethods() async -> [BatteryRefillRechargeMethodsModel.RechargeMethodItem] {
        let rechargeMethods = await loadRechargeMethods()
            .filter { $0.supportRecharge }

        guard let balance = try? await loadBalance().balance else { return [] }

        var tonRechargeMethods = [BatteryRechargeMethod]()
        var jettonRechargeMethods = [BatteryRechargeMethod]()
        var jettonMasterAddresses = [Address]()
        for rechargeMethod in rechargeMethods {
            switch rechargeMethod.token {
            case .ton: tonRechargeMethods.append(rechargeMethod)
            case let .jetton(jetton):
                jettonRechargeMethods.append(rechargeMethod)
                jettonMasterAddresses.append(jetton.jettonMasterAddress)
            }
        }

        let balanceJettonItems = balance.jettonsBalance
            .filter { balanceJetton in
                balanceJetton.quantity > 0 &&
                    jettonMasterAddresses.contains(balanceJetton.item.jettonInfo.address)
            }

        var items = jettonRechargeMethods.compactMap { rechargeMethod -> BatteryRefillRechargeMethodsModel.RechargeMethodItem? in
            guard let jettonBalance = balanceJettonItems.first(where: { $0.item.jettonInfo.address == rechargeMethod.jettonMasterAddress }) else {
                return nil
            }
            return BatteryRefillRechargeMethodsModel.RechargeMethodItem.token(
                token: .jetton(jettonBalance.item)
            )
        }

        if !items.contains(where: { item in
            if case let .jetton(jettonItem) = item.token {
                return jettonItem.jettonInfo.isTonUSDT
            } else {
                return false
            }
        }), rechargeMethods.contains(where: { $0.jettonMasterAddress == JettonMasterAddress.tonUSDT }) {
            if let info = try? await jettonService.jettonInfo(address: JettonMasterAddress.tonUSDT, network: wallet.network) {
                items.insert(.token(token: .jetton(.init(jettonInfo: info, walletAddress: try? wallet.address))), at: 0)
            }
        }

        var result = items
        if !tonRechargeMethods.isEmpty {
            result.append(.token(token: .ton))
        }
        if !result.isEmpty {
            let giftItem = result[0]
            result.append(.gift(token: giftItem.token))
        }

        return result
    }

    func getRechargeMethod(jettonMasterAddress: Address) async -> BatteryRefillRechargeMethodsModel.RechargeMethodItem? {
        let rechargeMethods = await loadRechargeMethods()
            .filter { $0.supportRecharge }

        guard let balance = try? await loadBalance().balance else { return nil }

        guard let rechargeMethod = rechargeMethods.first(where: { $0.jettonMasterAddress == jettonMasterAddress }),
              case let .jetton(jetton) = rechargeMethod.token,
              let jettonBalance = balance.jettonsBalance.first(where: { $0.item.jettonInfo.address == jetton.jettonMasterAddress })
        else {
            return nil
        }

        return .token(token: .jetton(jettonBalance.item))
    }

    private func loadRechargeMethods() async -> [BatteryRechargeMethod] {
        if let task = loadRechargeMethodsTask {
            return await task.value
        }

        let task = Task { [wallet, batteryService] in
            defer {
                self.loadRechargeMethodsTask = nil
            }
            do {
                let methods = try await batteryService.loadRechargeMethods(wallet: wallet, includeRechargeOnly: false)
                try Task.checkCancellation()
                return methods
            } catch {
                return []
            }
        }

        loadRechargeMethodsTask = task

        return await task.value
    }

    private func loadBalance() async throws -> KeeperCore.WalletBalance {
        if let task = balanceLoadTask {
            return try await task.value
        }

        let task = Task { [wallet, balanceService] in
            defer {
                balanceLoadTask = nil
            }
            return try await balanceService.loadWalletBalance(
                wallet: wallet,
                currency: .USD,
                includingTransferFees: true
            )
        }

        balanceLoadTask = task

        return try await task.value
    }
}
