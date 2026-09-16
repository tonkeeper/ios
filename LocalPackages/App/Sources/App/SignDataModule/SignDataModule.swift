import KeeperCore
import TKCoordinator
import TKUIKit

public enum SignDataRequestFailure: Error {
    case confirmationFailed(
        message: String?
    )
}

protocol SignDataResultHandler {
    func didSign(signedData: SignedDataResult)
    func didFail(error: SignDataRequestFailure)
    func didCancel()
}
