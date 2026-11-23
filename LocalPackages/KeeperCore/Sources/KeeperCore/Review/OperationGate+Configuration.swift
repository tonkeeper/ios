import ChainKit
import Foundation

extension OperationGate {
    /// A flow family's gate. Its checks are read at every review, so a switch takes effect on the
    /// next one: chain-kit's validation by `client`, when given, unless the mainnet boot
    /// configuration's `tx_validation_enabled` turns it off. The mainnet value holds for every wallet,
    /// as Android's `BootFlags` does: a gate is built for a flow family, not a wallet, so the testnet
    /// `flags` go unread.
    init(configuration: Configuration, validatingWith client: CryptoKitClient? = nil, validationTimeLimit: TimeInterval? = nil) {
        let validation = client.map { client -> any OperationCheck in
            let check = ChainKitValidationCheck(client: client)
            if let validationTimeLimit {
                return DappValidationCheck(check: check, timeLimit: validationTimeLimit)
            }
            return check
        }
        self.init {
            guard let validation, configuration.flag(\.txValidationEnabled, network: .mainnet) else {
                return []
            }
            return [validation]
        }
    }
}
