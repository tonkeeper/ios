import KeeperCoreComponents
import KeeperCoreSensitive

struct ImportedWalletTronResolution {
    let tron: WalletTron?
    let multichain: MultichainWallet?

    static let multichainCandidate = ImportedWalletTronResolution(
        tron: nil,
        multichain: nil
    )

    static func legacy(tron: WalletTron) -> ImportedWalletTronResolution {
        ImportedWalletTronResolution(
            tron: tron,
            multichain: .unavailable
        )
    }
}

enum ImportWalletKindSelectionReason: Equatable {
    case ambiguousMnemonic(legacyTronBalance: TronBalance?)
    case legacyTronBalance(TronBalance)
}

struct ImportedWalletTronResolver {
    private let tronBalanceService: TronBalanceService

    init(tronBalanceService: TronBalanceService) {
        self.tronBalanceService = tronBalanceService
    }

    func resolve(
        mnemonic: CoreMnemonic,
        network: Network,
        walletKindPreference: ImportWalletKindPreference
    ) async -> ImportedWalletTronResolution {
        guard network == .mainnet,
              let tron = WalletTron(tonMnemonic: mnemonic.mnemonicWords)
        else {
            return .multichainCandidate
        }

        switch mnemonic.type {
        case .ton:
            return ImportedWalletTronResolution(
                tron: tron,
                multichain: nil
            )
        case .bip39:
            switch walletKindPreference {
            case .automatic:
                return await legacyBalance(tron: tron) == nil
                    ? .multichainCandidate
                    : .legacy(tron: tron)
            case .selected(.ton):
                return .legacy(tron: tron)
            case .selected(.multichain):
                return .multichainCandidate
            }
        case .bip39soft, .unknown:
            return .multichainCandidate
        }
    }

    func legacyBalance(
        mnemonic: CoreMnemonic,
        network: Network
    ) async -> TronBalance? {
        guard network == .mainnet,
              mnemonic.type == .bip39,
              let tron = WalletTron(tonMnemonic: mnemonic.mnemonicWords)
        else {
            return nil
        }
        return await legacyBalance(tron: tron)
    }

    func walletKindSelectionReason(
        words: [String],
        network: Network
    ) async -> ImportWalletKindSelectionReason? {
        guard network == .mainnet else {
            return nil
        }

        if DerivationType.shouldOfferWalletKindSelection(words) {
            let mnemonic = CoreMnemonic(mnemonicWords: words, type: .bip39)
            let balance = await legacyBalance(mnemonic: mnemonic, network: network)
            return .ambiguousMnemonic(legacyTronBalance: balance)
        }

        let mnemonic = CoreMnemonic(mnemonicWords: words, type: .guessByWords(words))
        guard let balance = await legacyBalance(mnemonic: mnemonic, network: network) else {
            return nil
        }
        return .legacyTronBalance(balance)
    }

    private func legacyBalance(tron: WalletTron) async -> TronBalance? {
        guard let balance = try? await tronBalanceService.loadBalance(address: tron.address),
              !balance.amount.isZero || !balance.trxAmount.isZero
        else {
            return nil
        }
        return balance
    }
}
