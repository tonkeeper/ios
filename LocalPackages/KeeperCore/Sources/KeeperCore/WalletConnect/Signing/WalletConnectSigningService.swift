import ChainKit
import Foundation

public final class WalletConnectSigningService {
    private let mnemonicAccess: MnemonicAccess
    private let client: CryptoKitClient
    private let pendingTransactionsService: PendingTransactionsService
    private let requestSigner: WalletConnectRequestSigner

    init(
        mnemonicAccess: MnemonicAccess,
        client: CryptoKitClient,
        pendingTransactionsService: PendingTransactionsService
    ) {
        self.mnemonicAccess = mnemonicAccess
        self.client = client
        self.pendingTransactionsService = pendingTransactionsService
        self.requestSigner = WalletConnectRequestSigner()
    }

    public func sign(
        passcodeProvider: @escaping () async -> String?,
        wallet: Wallet,
        request: WalletConnectSessionRequest
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        guard case .regular = wallet.kind else {
            throw .unsupportedWalletKind
        }

        let context = WalletConnectSigningContext(
            passcodeProvider: passcodeProvider,
            wallet: wallet,
            mnemonicAccess: mnemonicAccess,
            client: client,
            pendingTransactionsService: pendingTransactionsService
        )
        return try await requestSigner.sign(request: request, context: context)
    }
}
