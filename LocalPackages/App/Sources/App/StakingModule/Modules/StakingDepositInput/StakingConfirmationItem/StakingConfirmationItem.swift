import BigInt
import Foundation
import KeeperCore

struct StakingConfirmationItem {
    enum Operation {
        case deposit(StackingPoolInfo)
        case withdraw(StackingPoolInfo, isCollect: Bool)
    }

    let operation: Operation
    let amount: BigUInt
}
