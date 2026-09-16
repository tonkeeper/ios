import TKLocalize

/// Keeps an aggregator's own wording out of the UI: the user gets a localized message picked by the
/// normalized error code, while the provider's raw text goes to the log. A quote that yielded no
/// route usually carries one error per aggregator — and per protocol within SwapKit — so the code
/// the user is told about is the most actionable one rather than whichever arrived first.
public enum MultichainSwapProviderErrorMessage {
    public static func userMessage(for errors: [MultichainSwapProviderError]) -> String? {
        guard !errors.isEmpty else {
            return nil
        }
        let codes = Set(errors.compactMap(\.errorCode))
        return message(for: codePriority.first { codes.contains($0) })
    }

    public static func logDescription(for errors: [MultichainSwapProviderError]) -> String {
        errors.map(\.logDescription).joined(separator: ",")
    }

    static let codePriority: [MultichainSwapProviderErrorCode] = [
        .countryBlocked,
        .minAmountNotMet,
        .noRoute,
        .assetNotSupported,
        .providerUnavailable,
        .providerError,
    ]

    private static func message(for code: MultichainSwapProviderErrorCode?) -> String {
        switch code {
        case .countryBlocked:
            return TKLocales.MultichainSwap.ProviderError.countryBlocked
        case .minAmountNotMet:
            return TKLocales.MultichainSwap.ProviderError.minAmountNotMet
        case .noRoute:
            return TKLocales.NativeSwap.Quote.Rate.pairUnavailable
        case .assetNotSupported:
            return TKLocales.MultichainSwap.Screen.Swap.Error.assetUnavailable
        case .providerUnavailable:
            return TKLocales.MultichainSwap.ProviderError.providerUnavailable
        case .providerError, nil:
            return TKLocales.MultichainSwap.ProviderError.unknown
        }
    }
}
