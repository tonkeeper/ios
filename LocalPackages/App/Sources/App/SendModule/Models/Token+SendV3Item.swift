import KeeperCore

extension Token {
    var sendV3Item: SendV3Item {
        switch self {
        case let .ton(tonToken):
            return .ton(.token(tonToken, amount: 0))
        case .tron(.usdt):
            return .tron(.usdt(amount: 0))
        case .tron(.trx):
            return .tron(.trx(amount: 0))
        }
    }
}
