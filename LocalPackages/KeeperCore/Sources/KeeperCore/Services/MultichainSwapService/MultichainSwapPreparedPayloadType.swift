enum MultichainSwapPreparedPayloadType: Hashable {
    case evmTransaction
    case evmApprovalTransaction
    case tonBOC
    case tronTransaction
    case utxoPSBT
    case altVmDeposit
    case unsupported(String)

    init(rawValue: String) {
        switch rawValue {
        case "evm_tx":
            self = .evmTransaction
        case "evm_approval_tx":
            self = .evmApprovalTransaction
        case "ton_boc":
            self = .tonBOC
        case "tron_tx":
            self = .tronTransaction
        case "utxo_psbt":
            self = .utxoPSBT
        case "alt_vm_deposit":
            self = .altVmDeposit
        default:
            self = .unsupported(rawValue)
        }
    }
}

extension MultichainSwapPreparedPayload {
    var preparedPayloadType: MultichainSwapPreparedPayloadType {
        MultichainSwapPreparedPayloadType(rawValue: payloadType)
    }
}
