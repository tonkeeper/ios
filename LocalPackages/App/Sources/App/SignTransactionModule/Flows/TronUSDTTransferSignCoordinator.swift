import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKUIKit
import TronSwift
import UIKit

final class TronUSDTTransferSignCoordinator: RouterCoordinator<ViewControllerRouter> {
    typealias Result = Swift.Result<TronSwift.SignedTxID, TronTransferSignError>

    var didFail: ((Swift.Error) -> Void)?
    var didSign: ((TronSwift.SignedTxID) -> Void)?
    var didCancel: (() -> Void)?

    private let wallet: Wallet
    private let txID: TronSwift.TxID
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    init(
        router: ViewControllerRouter,
        wallet: Wallet,
        txID: TronSwift.TxID,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) {
        self.wallet = wallet
        self.txID = txID
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }

    override func start() {
        handleSign()
    }

    func handleSign(parentCoordinator: Coordinator) async -> Result {
        return await Task<Result, Never> { @MainActor in
            return await withCheckedContinuation { [weak parentCoordinator] (continuation: CheckedContinuation<Result, Never>) in
                didSign = { [weak parentCoordinator, weak self] in
                    continuation.resume(returning: .success($0))
                    guard let self else { return }
                    parentCoordinator?.removeChild(self)
                }

                didFail = { [weak parentCoordinator, weak self] in
                    continuation.resume(returning: .failure(
                        .failedToSign(message: $0.localizedDescription)
                    ))
                    guard let self else { return }
                    parentCoordinator?.removeChild(self)
                }

                didCancel = { [weak parentCoordinator, weak self] in
                    continuation.resume(returning: .failure(.cancelled))
                    guard let self else { return }
                    parentCoordinator?.removeChild(self)
                }

                parentCoordinator?.addChild(self)
                start()
            }
        }.value
    }
}

private extension TronUSDTTransferSignCoordinator {
    func handleSign() {
        PasscodeInputCoordinator.present(
            parentCoordinator: self,
            parentRouter: router,
            mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
            onCancel: { [weak self] in
                self?.didCancel?()
            },
            onInput: { [weak self, wallet, keeperCoreMainAssembly, txID] passcode in
                guard let self else { return }
                Task {
                    do {
                        let mnemonic = try await keeperCoreMainAssembly.secureAssembly.mnemonicsRepository().getMnemonic(
                            wallet: wallet,
                            password: passcode
                        )
                        let privateKey = try TonTron.derivedKeyPair(tonMnemonic: mnemonic.mnemonicWords, index: 0).privateKey
                        let signer = Signer()

                        let signed = try signer.sign(hash: txID, privateKey: privateKey)
                        self.didSign?(signed)
                    } catch {
                        self.didFail?(error)
                    }
                }
            }
        )
    }
}
