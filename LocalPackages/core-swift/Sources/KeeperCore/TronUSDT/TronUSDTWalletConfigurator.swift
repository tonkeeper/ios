import Foundation
import TronSwift

public struct TronWalletConfigurator {
    public enum Error: Swift.Error {
        case cancelled
    }

    private let walletsStore: WalletsStore
    private let mnemonicRepository: MnemonicsRepository

    init(
        walletsStore: WalletsStore,
        mnemonicRepository: MnemonicsRepository
    ) {
        self.walletsStore = walletsStore
        self.mnemonicRepository = mnemonicRepository
    }

    public func turnOn(wallet: Wallet, passcodeProvider: () async -> String?) async throws {
        if let tron = wallet.tron {
            let updatedTron = WalletTron(
                publicKey: tron.publicKey,
                address: tron.address,
                isOn: true
            )
            await walletsStore.setWalletTron(wallet: wallet, tron: updatedTron)
        } else if let passcode = await passcodeProvider() {
            let mnemonic = try await mnemonicRepository.getMnemonic(wallet: wallet, password: passcode)
            let tronKeyPair = try TonTron.derivedKeyPair(tonMnemonic: mnemonic.mnemonicWords, index: 0)
            let tron = try WalletTron(
                publicKey: tronKeyPair.publicKey,
                address: TronSwift.Address(publicKey: tronKeyPair.publicKey),
                isOn: true
            )
            await walletsStore.setWalletTron(wallet: wallet, tron: tron)
        } else {
            throw Error.cancelled
        }
    }

    public func turnOff(wallet: Wallet) async {
        guard let tron = wallet.tron else { return }
        let updatedTron = WalletTron(
            publicKey: tron.publicKey,
            address: tron.address,
            isOn: false
        )
        await walletsStore.setWalletTron(wallet: wallet, tron: updatedTron)
    }
}
