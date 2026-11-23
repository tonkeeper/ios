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
    private let passcodeHandoff: TronTransferPasscodeHandoff?

    init(
        router: ViewControllerRouter,
        wallet: Wallet,
        txID: TronSwift.TxID,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        passcodeHandoff: TronTransferPasscodeHandoff? = nil
    ) {
        self.passcodeHandoff = passcodeHandoff
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
                didSign = { [weak parentCoordinator, weak self = self] in
                    continuation.resume(returning: .success($0))
                    guard let self else { return }
                    parentCoordinator?.removeChild(self)
                }

                didFail = { [weak parentCoordinator, weak self = self] in
                    continuation.resume(returning: .failure(
                        .failedToSign(message: $0.localizedDescription)
                    ))
                    guard let self else { return }
                    parentCoordinator?.removeChild(self)
                }

                didCancel = { [weak parentCoordinator, weak self = self] in
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
        if let passcode = passcodeHandoff?.currentOperationPasscode {
            sign(passcode: passcode, reusesCurrentOperation: true)
            return
        }
        passcodeHandoff?.discard()
        requestPasscode()
    }

    func requestPasscode() {
        PasscodeInputCoordinator.present(
            parentCoordinator: self,
            parentRouter: router,
            mnemonicAccess: keeperCoreMainAssembly.mnemonicAccess,
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
            analyticsProvider: coreAssembly.analyticsProvider,
            reason: .confirmTransfer,
            onCancel: { [weak self] in
                self?.didCancel?()
            },
            onInput: { [weak self] passcode in
                self?.sign(passcode: passcode)
            }
        )
    }

    func sign(passcode: String, reusesCurrentOperation: Bool = false) {
        let wallet = wallet
        let keeperCoreMainAssembly = keeperCoreMainAssembly
        let txID = txID
        Task {
            do {
                let mnemonic = try await keeperCoreMainAssembly.mnemonicAccess.getMnemonic(
                    wallet: wallet,
                    passcode: passcode
                )
                let privateKey: TronSwift.PrivateKey
                if wallet.isMultichain, mnemonic.type == .bip39 {
                    let privateKeyData = try keeperCoreMainAssembly.multichainAssembly.chainKitService
                        .tronPrivateKey(mnemonic: mnemonic.mnemonicWords.joined(separator: " "))
                    privateKey = TronSwift.PrivateKey(data: privateKeyData, chainCode: Data())
                } else {
                    privateKey = try TonTron.derivedKeyPair(
                        tonMnemonic: mnemonic.mnemonicWords,
                        index: 0
                    ).privateKey
                }
                if !reusesCurrentOperation {
                    passcodeHandoff?.store(passcode)
                }
                let signed = try Signer().sign(hash: txID, privateKey: privateKey)
                didSign?(signed)
            } catch {
                didFail?(error)
            }
        }
    }
}
