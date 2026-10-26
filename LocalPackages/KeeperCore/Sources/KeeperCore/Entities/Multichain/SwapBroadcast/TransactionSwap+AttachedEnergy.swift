import ChainKit

extension TransactionSwap {
    /// A TON jetton swap message goes to the sender's jetton wallet, so its amount is the chain's
    /// coin the wallet pays on top of the fee, not the jettons being traded.
    var attachesEnergy: Bool {
        account.chain is ChainTvm && account.asset is AssetToken && !(data ?? "").isEmpty
    }

    var attachedEnergy: BignumBigInteger {
        attachesEnergy ? amount : BignumBigInteger.Companion.shared.ZERO
    }

    /// ChainKit adds its jetton reserve to the fee of a jetton message; the attached amount already
    /// pays for what that reserve stands for, so the message is priced as the coin message it is.
    var asEnergyMessage: TransactionSwap {
        guard attachesEnergy else {
            return self
        }
        return doCopy(
            account: account.doCopy(
                address: account.address,
                asset: account.chain.toAsset(),
                derivation: account.derivation,
                publicKey: account.publicKey
            ),
            amount: amount,
            isMax: false,
            destination: destination,
            to: to,
            data: data,
            initData: initData,
            memo: memo
        )
    }
}
