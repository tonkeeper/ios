import KeeperCore

protocol MultichainSwapSlippageService {
    var optionsBps: [Int] { get }
    func initialSelectedBps(route: MultichainSwapRoute) -> Int
}

struct DefaultMultichainSwapSlippageService: MultichainSwapSlippageService {
    private let sourceAssetId: String
    private let sourceChain: MultichainChain?
    private let slippage: MultichainSwapSlippage?
    private let fallbackBps: Int

    init(
        sourceAssetId: String,
        sourceChain: MultichainChain?,
        slippage: MultichainSwapSlippage?,
        fallbackBps: Int = 100
    ) {
        self.sourceAssetId = sourceAssetId
        self.sourceChain = sourceChain
        self.slippage = slippage
        self.fallbackBps = fallbackBps
    }

    var optionsBps: [Int] {
        sourceSlippageOptions?.optionsBps ?? []
    }

    var defaultBps: Int {
        sourceSlippageOptions?.defaultBps ?? fallbackBps
    }

    func initialSelectedBps(route: MultichainSwapRoute) -> Int {
        if let routeSlippage = route.totalSlippageBps,
           optionsBps.contains(routeSlippage)
        {
            return routeSlippage
        }
        if let defaultBps = sourceSlippageOptions?.defaultBps {
            return defaultBps
        }
        return route.totalSlippageBps ?? optionsBps.first ?? fallbackBps
    }
}

private extension DefaultMultichainSwapSlippageService {
    var sourceSlippageOptions: MultichainSwapSlippageOptions? {
        guard let sourceChainKey else {
            return nil
        }
        return slippage?.chains[sourceChainKey]
    }

    var sourceChainKey: String? {
        Self.crossSwapChainKey(assetId: sourceAssetId)
            ?? sourceChain?.rawValue
    }

    static func crossSwapChainKey(assetId: String) -> String? {
        let components = assetId.split(separator: "/", omittingEmptySubsequences: true)
        guard components.count >= 2 else {
            return nil
        }
        return components.first.map(String.init)
    }
}
