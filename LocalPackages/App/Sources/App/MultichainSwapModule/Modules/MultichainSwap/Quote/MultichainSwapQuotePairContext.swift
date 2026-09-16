import Foundation
import KeeperCore

struct MultichainSwapQuoteItem {
    let assetId: String
    let symbol: String
    let decimals: Int
    let chain: MultichainChain
    let address: String
}

struct MultichainSwapQuotePairContext {
    let source: MultichainSwapQuoteItem
    let destination: MultichainSwapQuoteItem
    let slippageBps: Int?
    let walletId: String?
}
