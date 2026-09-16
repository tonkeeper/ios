import ChainKit
import Foundation

extension WalletConnectEVMTransaction {
    var pendingActivityType: MultichainPendingTransaction.ActivityType {
        let data = data.trimmingCharacters(in: .whitespacesAndNewlines)
        if data.isEmpty || data == "0x" || EvmCall.shared.decodeTransfer(callData_: data) != nil {
            return .send
        }
        return .contractCall
    }
}
