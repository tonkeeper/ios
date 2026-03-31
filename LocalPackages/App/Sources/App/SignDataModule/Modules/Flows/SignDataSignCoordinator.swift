import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKUIKit
import TonSwift
import TonTransport
import UIKit
import URKit

enum SignDataSignError: Swift.Error {
    case incorrectWalletKind
    case cancelled
    case failedToSign(
        message: String?
    )
}

final class SignDataSignCoordinator: RouterCoordinator<ViewControllerRouter> {
    enum ExtenalSignError: Swift.Error {
        case cancelled
    }

    enum Result {
        case signed(SignedDataResult)
        case failed(SignDataSignError)
        case cancel
    }

    var didFail: ((SignDataSignError) -> Void)?
    var didSign: ((SignedDataResult) -> Void)?
    var didCancel: (() -> Void)?

    var externalSignHandler: ((Data?) -> Void)?

    private let wallet: Wallet
    private let dappUrl: String
    private let request: TonConnect.SignDataRequest
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    init(
        router: ViewControllerRouter,
        wallet: Wallet,
        dappUrl: String,
        request: TonConnect.SignDataRequest,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) {
        self.wallet = wallet
        self.request = request
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.dappUrl = dappUrl
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }

    override func start() {
        handleSign()
    }

    func handleSign(parentCoordinator: Coordinator) async -> Result {
        return await Task<SignDataSignCoordinator.Result, Never> { @MainActor in
            return await withCheckedContinuation { [weak parentCoordinator] (continuation: CheckedContinuation<SignDataSignCoordinator.Result, Never>) in
                didSign = { [weak parentCoordinator, weak self] in
                    continuation.resume(returning: .signed($0))
                    guard let self else { return }
                    parentCoordinator?.removeChild(self)
                }

                didFail = { [weak parentCoordinator, weak self] in
                    continuation.resume(returning: .failed($0))
                    guard let self else { return }
                    parentCoordinator?.removeChild(self)
                }

                didCancel = { [weak parentCoordinator, weak self] in
                    continuation.resume(returning: .cancel)
                    guard let self else { return }
                    parentCoordinator?.removeChild(self)
                }

                parentCoordinator?.addChild(self)
                start()
            }
        }.value
    }
}

private extension SignDataSignCoordinator {
    func handleSign() {
        switch wallet.identity.kind {
        case .Regular:
            handleRegularSign()
        case .SignerDevice(_, _), .Signer(_, _), .Watchonly, .Ledger(_, _, _), .Keystone(_, _, _, _), .Lockup:
            didFail?(.incorrectWalletKind)
        }
    }

    func handleRegularSign() {
        PasscodeInputCoordinator.present(
            parentCoordinator: self,
            parentRouter: router,
            mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
            onCancel: { [weak self] in
                self?.didCancel?()
            },
            onInput: { [weak self, wallet, keeperCoreMainAssembly, dappUrl, request] passcode in
                guard let self else { return }
                let signer = SignDataSignerProvider.getSigner(signDataPayload: request)
                let mnemonicsRepository = keeperCoreMainAssembly.secureAssembly.mnemonicsRepository()
                Task {
                    do {
                        let signed = try await signer.sign(
                            wallet: wallet,
                            mnemonicsRepository: mnemonicsRepository,
                            dappUrl: dappUrl,
                            passcode: passcode
                        )

                        self.didSign?(signed)
                    } catch {
                        self.didFail?(
                            .failedToSign(message: error.localizedDescription)
                        )
                    }
                }
            }
        )
    }
}
