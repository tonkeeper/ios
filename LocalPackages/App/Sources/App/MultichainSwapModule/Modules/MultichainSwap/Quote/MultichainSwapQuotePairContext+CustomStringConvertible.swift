extension MultichainSwapQuotePairContext: CustomStringConvertible {
    var description: String {
        "\(source.assetId) -[\(slippageDescription)]-> \(destination.assetId)"
    }

    private var slippageDescription: String {
        if let slippageBps {
            return "\(slippageBps)"
        } else {
            return "nil"
        }
    }
}
