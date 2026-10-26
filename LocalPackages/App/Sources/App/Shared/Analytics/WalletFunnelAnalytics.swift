import KeeperCoreComponents
import KeeperCoreSensitive
import TKCore

extension AnalyticsProvider {
    func logWalletImportStarted(
        walletMode: WalletMode,
        walletSource: WalletSource,
        from: AddWalletSource
    ) {
        log(WalletImportStarted(walletMode: walletMode, walletSource: walletSource, from: from))
    }

    func logWalletImportSuccess(
        walletMode: WalletMode,
        walletSource: WalletSource,
        from: AddWalletSource,
        ledgerModel: LedgerModel? = nil
    ) {
        log(WalletImportSuccess(walletMode: walletMode, walletSource: walletSource, from: from, ledgerModel: ledgerModel))
    }

    func logWalletImportSuccess(
        mnemonic: CoreMnemonic,
        from: AddWalletSource
    ) {
        guard let walletMode = WalletMode(knownMnemonic: mnemonic) else { return }
        logWalletImportSuccess(walletMode: walletMode, walletSource: .mnemonic, from: from)
    }

    func logWalletImportError(
        walletMode: WalletMode,
        walletSource: WalletSource,
        from: AddWalletSource,
        errorMessage: String?,
        ledgerModel: LedgerModel? = nil
    ) {
        log(WalletImportError(
            walletMode: walletMode,
            walletSource: walletSource,
            from: from,
            errorType: nil,
            errorCode: nil,
            errorMessage: errorMessage,
            ledgerModel: ledgerModel
        ))
    }

    func logWalletImportError(
        walletMode: WalletMode,
        walletSource: WalletSource,
        from: AddWalletSource,
        error: Error,
        ledgerModel: LedgerModel? = nil
    ) {
        logWalletImportError(
            walletMode: walletMode,
            walletSource: walletSource,
            from: from,
            errorMessage: error.localizedDescription,
            ledgerModel: ledgerModel
        )
    }

    func logWalletImportError(
        mnemonic: CoreMnemonic,
        from: AddWalletSource,
        errorMessage: String?
    ) {
        guard let walletMode = WalletMode(knownMnemonic: mnemonic) else { return }
        logWalletImportError(
            walletMode: walletMode,
            walletSource: .mnemonic,
            from: from,
            errorMessage: errorMessage
        )
    }

    func logWalletImportError(
        mnemonic: CoreMnemonic,
        from: AddWalletSource,
        error: Error
    ) {
        logWalletImportError(
            mnemonic: mnemonic,
            from: from,
            errorMessage: error.localizedDescription
        )
    }

    func logWalletBackupMismatch(walletMode: WalletMode, source: BackupSource) {
        log(WalletBackupError(
            walletMode: walletMode,
            source: source,
            errorType: "recovery_phrase_confirmation_mismatch",
            errorCode: nil,
            errorMessage: "Recovery phrase confirmation mismatch"
        ))
    }
}

struct WalletFlowAnalyticsContext {
    let from: AddWalletSource

    func logOnboarding(_ event: Encodable, using analyticsProvider: AnalyticsProvider) {
        guard from == .onboarding else { return }
        analyticsProvider.log(event)
    }

    func walletMode(for derivationType: DerivationType) -> WalletMode {
        switch derivationType {
        case .ton:
            return .single
        case .bip39, .bip39soft, .unknown:
            return .multi
        }
    }
}

extension WalletMode {
    init?(knownMnemonic mnemonic: CoreMnemonic) {
        switch mnemonic.type {
        case .ton:
            self = .single
        case .bip39, .bip39soft:
            self = .multi
        case .unknown:
            return nil
        }
    }
}
