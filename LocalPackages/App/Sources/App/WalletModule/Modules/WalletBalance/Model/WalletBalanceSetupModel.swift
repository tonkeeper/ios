import Foundation
import KeeperCore

final class WalletBalanceSetupModel {
  enum State {
    case none
    case setup(Setup)
  }
  
  struct Setup {
    let isFinishEnable: Bool
    let isBiometryVisible: Bool
    let isBackupVisible: Bool
  }
  
  private let actor = SerialActor()
  
  var didUpdateState: ((State) -> Void)? {
    didSet {
      Task {
        await actor.addTask(block: {
          let state = self.calculateState()
          self.update(state: state)
        })
      }
    }
  }
}

private extension WalletBalanceSetupModel {
  func update(state: State) {
    didUpdateState?(state)
  }
  
  func calculateState() -> State {
    let setup = Setup(
      isFinishEnable: true,
      isBiometryVisible: true,
      isBackupVisible: true
    )
    return .setup(setup)
  }
}
