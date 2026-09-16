import KeeperCore

extension MultichainSwapQuote {
    var hasNoRouteProviderError: Bool {
        (providerErrors ?? []).contains { $0.isNoRoute }
    }

    var providerErrorMessage: String? {
        MultichainSwapProviderErrorMessage.userMessage(for: providerErrors ?? [])
    }

    var providerErrorsLogDescription: String {
        MultichainSwapProviderErrorMessage.logDescription(for: providerErrors ?? [])
    }
}
