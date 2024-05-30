import Foundation

public struct SwapModel {
    public let wallet: Wallet
    public let recipient: Recipient?
    public let sendItem: SendItem
    
    public init(
        wallet: Wallet,
        recipient: Recipient?,
        swapType: SendItem.SwapType
    ) {
        self.wallet = wallet
        self.recipient = recipient
        self.sendItem = .swap(swapType)
    }
}
