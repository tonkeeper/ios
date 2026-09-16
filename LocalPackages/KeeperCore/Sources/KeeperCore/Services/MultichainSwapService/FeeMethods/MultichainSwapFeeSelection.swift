/// Pure so the confirmation screen and the execution service always land on the same method.
public enum MultichainSwapFeeSelection {
    public static func resolve(
        options: [MultichainSwapFeeOption],
        picked: MultichainSwapFeeMethod?
    ) -> MultichainSwapFeeOption? {
        guard let first = options.first else {
            return nil
        }
        let candidate = picked.flatMap { method in options.first { $0.method == method } } ?? first
        guard candidate.isInsufficient else {
            return candidate
        }
        // The chain's own coin is the method that always exists, so it is the sanest fallback.
        return options.first { $0.method == .native && !$0.isInsufficient }
            ?? options.first { !$0.isInsufficient }
            ?? candidate
    }
}
