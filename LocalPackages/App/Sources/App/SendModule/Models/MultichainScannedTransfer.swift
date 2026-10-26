import BigInt
import KeeperCore

struct MultichainScannedTransfer {
    let candidates: MultichainRecipientCandidates
    let amount: BigUInt?
    /// A Solana Pay amount counts whole units of the asset the link pins, so it has an atomic
    /// value only against that asset's decimals.
    let decimalAmount: Deeplink.DecimalAmount?
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
            decimalAmount = nil
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
            decimalAmount = nil
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
            decimalAmount = nil
            comment = nil
        case let .solanaSendTransfer(data):
            guard let detected = MultichainRecipientCandidates(string: data.recipient),
                  detected.chains.contains(.sol)
            else {
                return nil
            }
            candidates = MultichainRecipientCandidates(address: data.recipient, chains: [.sol])
            amount = nil
            decimalAmount = data.amount
            assetId = data.asset.assetId
            comment = nil
        case .signRawTransfer:
            return nil
        }
    }

    /// The amount in atomic units of `asset`. A Solana Pay amount finer than the asset's decimals
    /// has none, so it is left out rather than rounded.
    func atomicAmount(for asset: MultichainAsset?) -> BigUInt? {
        if let amount {
            return amount
        }
        guard let decimalAmount, let asset else {
            return nil
        }
        return decimalAmount.atomicUnits(decimals: asset.asset.decimals)
    }
}
