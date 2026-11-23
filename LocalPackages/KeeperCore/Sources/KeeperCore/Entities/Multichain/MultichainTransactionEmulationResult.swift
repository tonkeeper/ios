@preconcurrency import BigInt
@preconcurrency import ChainKit
import OperationReviewModels

public struct MultichainTransactionEmulationResult: Sendable, Hashable {
    public let fee: BigUInt
    public let asset: MultichainAssetDetails
    public let adjustedAmount: BigUInt?
    public let isMaxAmount: Bool
    public let isInsufficientBalance: Bool
    /// What the checks found in the transfer as it was priced.
    public let review: OperationReview?
    /// The operation the fee was priced for, when that operation itself is what is signed.
    let operation: PricedOperation?

    public init(
        fee: BigUInt,
        asset: MultichainAssetDetails,
        adjustedAmount: BigUInt? = nil,
        isMaxAmount: Bool = false,
        isInsufficientBalance: Bool = false,
        review: OperationReview? = nil
    ) {
        self.init(
            fee: fee,
            asset: asset,
            adjustedAmount: adjustedAmount,
            isMaxAmount: isMaxAmount,
            isInsufficientBalance: isInsufficientBalance,
            review: review,
            operation: nil
        )
    }

    init(
        fee: BigUInt,
        asset: MultichainAssetDetails,
        adjustedAmount: BigUInt?,
        isMaxAmount: Bool,
        isInsufficientBalance: Bool,
        review: OperationReview?,
        operation: PricedOperation?
    ) {
        self.fee = fee
        self.asset = asset
        self.adjustedAmount = adjustedAmount
        self.isMaxAmount = isMaxAmount
        self.isInsufficientBalance = isInsufficientBalance
        self.review = review
        self.operation = operation
    }
}

/// An operation as it was priced and reviewed, signed at that fee. Every pricing is its own, so two
/// are equal only when they are one.
final class PricedOperation: Sendable, Hashable {
    let signable: SignableOperation
    let fee: any Fee
    /// The comment encrypted into the place of the stand-in `signable` carries once the wallet is unlocked.
    let encryptedComment: MultichainEncryptedComment?

    init(signable: SignableOperation, fee: any Fee, encryptedComment: MultichainEncryptedComment? = nil) {
        self.signable = signable
        self.fee = fee
        self.encryptedComment = encryptedComment
    }

    /// The TON the operation attaches to the sender's jetton wallet, which the wallet has to hold beside
    /// the fee: chain-kit's reserve holds a token's send to its fee alone. `nil` for an operation that is
    /// no TON send.
    var attachedTON: BigUInt? {
        guard !signable.operation.payloads.isEmpty else {
            return nil
        }
        var attached = BigUInt(0)
        for payload in signable.operation.payloads {
            guard let main = payload.meta as? PayloadMetaTonMain, let value = BigUInt(main.value.description) else {
                return nil
            }
            attached += value
        }
        return attached
    }

    static func == (lhs: PricedOperation, rhs: PricedOperation) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
