extension MultichainSwapQuotePairContext: CustomStringConvertible {
    var description: String {
        "\(source.assetId) -[\(slippageDescription)]-> \(destination.assetId) \(apiVersion)"
    }

    private var slippageDescription: String {
        if let slippageBps {
            return "\(slippageBps)"
        } else {
            return "nil"
        }
    }
}
