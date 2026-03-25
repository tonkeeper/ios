import KeeperCore
import TKCoordinator
import TKCore
import TKUIKit

public enum SignDataRequestFailure: Error {
    case confirmationFailed(
        message: String?
    )
}

public protocol SignDataResultHandler {
    func didSign(signedData: SignedDataResult)
    func didFail(error: SignDataRequestFailure)
    func didCancel()
}

@MainActor
struct SignDataModule {
    private let dependencies: Dependencies
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func signDataModule(
        wallet: Wallet,
        dappUrl: String,
        signRequest: TonConnect.SignDataRequest,
        resultHandler: SignDataResultHandler
    ) -> MVVMModule<SignDataViewController, SignDataModuleOutput, SignDataModuleInput> {
        return SignDataAssembly.module(
            wallet: wallet,
            dappUrl: dappUrl,
            signRequest: signRequest,
            resultHandler: resultHandler,
            keeperCoreMainAssembly: dependencies.keeperCoreMainAssembly
        )
    }
}

extension SignDataModule {
    struct Dependencies {
        let coreAssembly: TKCore.CoreAssembly
        let keeperCoreMainAssembly: KeeperCore.MainAssembly

        init(
            coreAssembly: TKCore.CoreAssembly,
            keeperCoreMainAssembly: KeeperCore.MainAssembly
        ) {
            self.coreAssembly = coreAssembly
            self.keeperCoreMainAssembly = keeperCoreMainAssembly
        }
    }
}
