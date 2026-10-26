import KeeperCore
import TonSwift

extension TransactionLiveActivityCounterparties {
    init(_ wallets: [Wallet]) {
        self.init(entries: wallets.map { wallet in
            var addresses: [String] = []
            if let address = try? wallet.address {
                addresses += Self.spellings(of: address)
            }
            for address in wallet.multichainWalletState?.addresses ?? [] {
                if address.chain == .ton, let ton = try? Address.parse(address.address) {
                    addresses += Self.spellings(of: ton)
                } else {
                    addresses.append(address.address)
                }
            }
            if let tron = wallet.tron?.address.base58 {
                addresses.append(tron)
            }
            return Entry(
                id: wallet.id,
                isTestnet: wallet.network == .testnet,
                name: wallet.metaData.label,
                addresses: Set(addresses.map(Self.key))
            )
        })
    }

    /// The widget compares strings, so a TON address goes in every way history may spell it.
    private static func spellings(of address: Address) -> [String] {
        var spellings = [address.toRaw()]
        for bounceable in [true, false] {
            for testOnly in [true, false] {
                for urlSafe in [true, false] {
                    spellings.append(address.toString(urlSafe: urlSafe, testOnly: testOnly, bounceable: bounceable))
                }
            }
        }
        return spellings
    }
}
