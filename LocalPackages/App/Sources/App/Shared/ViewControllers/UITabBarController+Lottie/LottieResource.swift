import TKUIKit

protocol LottieResourceConvertible {
    var asLottieResource: LottieResource? { get }
}

extension LottieResource: LottieResourceConvertible {
    var asLottieResource: LottieResource? {
        self
    }
}

extension MainCoordinatorStateManager.State.Tab: LottieResourceConvertible {
    var asLottieResource: LottieResource? {
        switch self {
        case .wallet:
            .walletTabItem
        case .trade:
            .tradeTabItem
        case .browser:
            .browserTabItem
        }
    }
}
