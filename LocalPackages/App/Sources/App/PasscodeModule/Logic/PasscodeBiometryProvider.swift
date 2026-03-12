import Foundation
import KeeperCore
import TKUIKit

struct PasscodeBiometryProvider: PasscodeInputBiometryProvider {
    private let biometryProvider: BiometryProvider
    private let securityStore: SecurityStore

    init(
        biometryProvider: BiometryProvider,
        securityStore: SecurityStore
    ) {
        self.biometryProvider = biometryProvider
        self.securityStore = securityStore
    }

    func getBiometryState() async -> TKUIKit.TKKeyboardView.Biometry {
        guard securityStore.state.isBiometryEnable else {
            return .none
        }
        switch biometryProvider.getBiometryState(policy: .deviceOwnerAuthenticationWithBiometrics) {
        case .failure:
            return .none
        case let .success(state):
            switch state {
            case .faceID: return .faceId
            case .touchID: return .touchId
            case .none: return .none
            }
        }
    }
}
