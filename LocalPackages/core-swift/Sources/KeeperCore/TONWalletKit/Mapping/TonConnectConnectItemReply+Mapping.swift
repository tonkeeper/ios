import Foundation
import TONWalletKit

public extension TonConnect.ConnectItemReply {
    func connectionResponse() -> TONConnectionApprovalResponse? {
        switch self {
        case .tonAddress, .tonProof: return nil
        case let .tonProofSigned(reply):
            switch reply {
            case .error: return nil
            case let .success(success):
                let proof = TONConnectionApprovalProof(
                    signature: TONBase64(data: success.proof.signature),
                    timestamp: Double(success.proof.timestamp),
                    domain: TONConnectionApprovalProofDomain(
                        lengthBytes: Int(
                            success.proof.domain.lengthBytes
                        ),
                        value: success.proof.domain.value
                    ),
                    payload: success.proof.payload
                )
                return TONConnectionApprovalResponse(proof: proof)
            }
        }
    }
}
