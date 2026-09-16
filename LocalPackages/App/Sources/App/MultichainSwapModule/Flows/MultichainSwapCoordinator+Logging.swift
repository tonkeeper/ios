extension MultichainSwapCoordinator.MultichainSwapTokenPickSide: CustomStringConvertible {
    var description: String {
        switch self {
        case .send:
            return "send"
        case .receive:
            return "receive"
        }
    }
}
