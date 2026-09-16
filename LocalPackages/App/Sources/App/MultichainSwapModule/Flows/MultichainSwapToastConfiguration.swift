import TKUIKit

extension ToastPresenter.Configuration {
    func withMultichainSwapErrorDuration() -> ToastPresenter.Configuration {
        var configuration = self
        configuration.dismissRule = .duration(4)
        return configuration
    }

    static func multichainSwapProviderError(_ message: String) -> ToastPresenter.Configuration {
        var configuration = warning(text: message)
        configuration.numberOfLines = 0
        return configuration.withMultichainSwapErrorDuration()
    }
}
