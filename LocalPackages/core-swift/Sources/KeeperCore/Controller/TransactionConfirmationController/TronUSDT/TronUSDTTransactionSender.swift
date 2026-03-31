import Foundation
import TronSwift

struct TronUSDTTransactionSender {
    struct InstantFeePayment {
        let instantFeeTx: String
        let userPublicKey: String
    }

    private let tronUsdtApi: TronUSDTAPI
    private let tonProofService: TonProofTokenService
    private let feeOptionsResolver: TronUSDTFeeOptionsResolver

    init(
        tronUsdtApi: TronUSDTAPI,
        tonProofService: TonProofTokenService,
        feeOptionsResolver: TronUSDTFeeOptionsResolver
    ) {
        self.tronUsdtApi = tronUsdtApi
        self.tonProofService = tonProofService
        self.feeOptionsResolver = feeOptionsResolver
    }

    func send(
        signedTransaction: Transaction,
        selectedExtraType: TransactionConfirmationModel.ExtraType,
        wallet: Wallet,
        address: Address,
        resources: TronUSDTTransactionConfirmationState.Resources,
        instantFeePayment: InstantFeePayment?
    ) async throws {
        if feeOptionsResolver.isTRXType(selectedExtraType) {
            try await tronUsdtApi.broadcastSignedTransaction(transaction: signedTransaction)
            return
        }

        let tonProof = try tonProofService.getWalletToken(wallet)
        _ = try await tronUsdtApi.sendTransaction(
            tonProofToken: tonProof,
            address: address,
            signedTransaction: signedTransaction,
            energy: resources.energy,
            bandwidth: resources.bandwidth,
            instantFeeTx: instantFeePayment?.instantFeeTx,
            userPublicKey: instantFeePayment?.userPublicKey
        )
    }
}
