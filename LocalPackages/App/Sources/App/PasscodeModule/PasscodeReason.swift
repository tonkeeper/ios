import TKLocalize

enum PasscodeReason {
    case confirmTransfer
    case confirmSwap
    case signData
    case dappRequest
    case connectDapp
    case perps
    case decryptComment
    case showRecoveryPhrase
    case backup
    case deleteWallet
    case enableBiometry
    case migrateWallet
    case collectibleAction
    case addWallet

    var text: String {
        switch self {
        case .confirmTransfer: TKLocales.Passcode.Reason.confirmTransfer
        case .confirmSwap: TKLocales.Passcode.Reason.confirmSwap
        case .signData: TKLocales.Passcode.Reason.signData
        case .dappRequest: TKLocales.Passcode.Reason.dappRequest
        case .connectDapp: TKLocales.Passcode.Reason.connectDapp
        case .perps: TKLocales.Passcode.Reason.perps
        case .decryptComment: TKLocales.Passcode.Reason.decryptComment
        case .showRecoveryPhrase: TKLocales.Passcode.Reason.showRecoveryPhrase
        case .backup: TKLocales.Passcode.Reason.backup
        case .deleteWallet: TKLocales.Passcode.Reason.deleteWallet
        case .enableBiometry: TKLocales.Passcode.Reason.enableBiometry
        case .migrateWallet: TKLocales.Passcode.Reason.migrateWallet
        case .collectibleAction: TKLocales.Passcode.Reason.collectibleAction
        case .addWallet: TKLocales.Passcode.Reason.addWallet
        }
    }
}
