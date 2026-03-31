import TKLocalize

enum RampFlow {
    case deposit
    case withdraw

    var title: String {
        switch self {
        case .deposit: return TKLocales.Ramp.Deposit.title
        case .withdraw: return TKLocales.Ramp.Withdraw.title
        }
    }

    var api: String {
        switch self {
        case .deposit: return "deposit"
        case .withdraw: return "withdraw"
        }
    }
}
