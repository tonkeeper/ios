import Foundation
import TronSwift

struct TronUSDTTransactionSender {
    struct InstantFeePayment {
        let instantFeeTx: String
        let userPublicKey: String

        init(instantFeeTx: String, userPublicKey: String) {
            self.instantFeeTx = instantFeeTx
            self.userPublicKey = userPublicKey
        }
    }

    private let tronUsdtApi: TronUSDTAPI
    private let feeOptionsResolver: TronUSDTFeeOptionsResolver

    init(
        tronUsdtApi: TronUSDTAPI,
        feeOptionsResolver: TronUSDTFeeOptionsResolver
    ) {
        self.tronUsdtApi = tronUsdtApi
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

        _ = try await tronUsdtApi.sendTransaction(
            wallet: wallet,
            address: address,
            signedTransaction: signedTransaction,
            energy: resources.energy,
            bandwidth: resources.bandwidth,
            instantFeeTx: instantFeePayment?.instantFeeTx,
            userPublicKey: instantFeePayment?.userPublicKey
        )
    }
}
