import Foundation
import KeeperCore
import TonSwift
import TonTransport

struct LedgerKnownJettonResolver {
    let balanceStore: BalanceStore
    let wallet: Wallet

    func knownJetton(for transaction: Transaction) -> KnownJetton? {
        guard let ownerWorkchain = try? wallet.address.workchain else { return nil }
        let jettonBalances = balanceStore.getState()[wallet]?.walletBalance.balance.jettonsBalance ?? []
        return Self.knownJetton(for: transaction, jettonBalances: jettonBalances, ownerWorkchain: ownerWorkchain)
    }

    static func knownJetton(
        for transaction: Transaction,
        jettonBalances: [JettonBalance],
        ownerWorkchain: Int8
    ) -> KnownJetton? {
        guard case .jettonTransfer = transaction.payload else { return nil }
        guard let jettonItem = jettonBalances.first(where: { $0.item.walletAddress == transaction.destination })?.item,
              let jettonId = LedgerKnownJettons.jettonId(master: jettonItem.jettonInfo.address)
        else { return nil }
        return KnownJetton(jettonId: jettonId, workchain: ownerWorkchain)
    }
}
