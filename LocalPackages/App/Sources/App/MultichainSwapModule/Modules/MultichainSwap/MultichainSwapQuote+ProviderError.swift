import KeeperCore

extension MultichainSwapQuote {
    var hasNoRouteProviderError: Bool {
        (providerErrors ?? []).contains { $0.isNoRoute }
    }

    var hasWalletScreenedProviderError: Bool {
        (providerErrors ?? []).contains { $0.isWalletScreened }
    }

    var providerErrorMessage: String? {
        MultichainSwapProviderErrorMessage.userMessage(for: providerErrors ?? [])
    }

    var providerErrorsLogDescription: String {
        MultichainSwapProviderErrorMessage.logDescription(for: providerErrors ?? [])
    }
}
