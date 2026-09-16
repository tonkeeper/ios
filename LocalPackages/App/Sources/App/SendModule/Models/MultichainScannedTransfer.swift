import BigInt
import KeeperCore

struct MultichainScannedTransfer {
    let candidates: MultichainRecipientCandidates
    let amount: BigUInt?
    let comment: String?
    /// Set only when the scanned link pins one specific asset. The send screen switches to it
    /// before applying the amount, so an amount can never land on an unrelated token.
    let assetId: String?

    init?(deeplink: KeeperCore.Deeplink) {
        guard case let .transfer(transfer) = deeplink else {
            return nil
        }
        switch transfer {
        case let .multichainSendTransfer(candidates):
            self.candidates = candidates
            amount = nil
            comment = nil
            assetId = nil
        case let .sendTransfer(data):
            guard let detected = MultichainRecipientCandidates(string: data.recipient) else {
                return nil
            }
            // The recipient has to be resolved on the chain the pinned asset lives on: the send
            // screen switches to that asset and then takes this recipient as it is, so a recipient
            // seeded on another chain the address happens to be valid on would only produce a
            // chain mismatch.
            let pinnedChain = data.assetId.flatMap(MultichainChain.init(assetId:))
            if let pinnedChain, detected.chains.contains(pinnedChain) {
                candidates = MultichainRecipientCandidates(address: detected.address, chains: [pinnedChain])
                amount = data.amount
                assetId = data.assetId
            } else {
                candidates = detected
                amount = data.assetId == nil ? data.amount : nil
                assetId = nil
            }
            comment = data.comment
        case let .evmSendTransfer(data):
            guard let detected = MultichainRecipientCandidates(string: data.recipient) else {
                return nil
            }
            if let chain = data.chain, detected.chains.contains(chain) {
                candidates = MultichainRecipientCandidates(address: data.recipient, chains: [chain])
                amount = data.amount
                assetId = data.asset.assetId(chain: chain)
            } else {
                candidates = detected
                amount = nil
                assetId = nil
            }
            comment = nil
        case .signRawTransfer:
            return nil
        }
    }
}
