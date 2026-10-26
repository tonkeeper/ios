import PerpsModels
import SwiftUI
import TKUIKit

private let previewDestination = PerpsDepositSource(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum)
private let previewRelayDestination = PerpsDepositSource(assetId: "ton/mainnet/coin", symbol: "TON", decimals: 9, network: .ton)
private let previewBalance = PerpsFundingBalance(amount: "3906.12", usdPrice: 0.9998, iconURL: nil)

@MainActor
private func amountForm(amount: String, available: String?) -> some View {
    let viewModel = PerpsWithdrawAmountViewModel(
        config: PerpsFundingAmountConfig(
            title: "Withdraw Perps balance",
            asset: { previewDestination },
            displayAsset: { balance in
                PerpsFundingAssetRow(
                    assetId: previewRelayDestination.assetId,
                    symbol: previewRelayDestination.symbol,
                    network: previewRelayDestination.network,
                    iconURL: balance?.iconURL,
                    balanceText: nil
                )
            },
            initialUnit: .usd,
            fixedUsdPrice: 1,
            loadBalance: { previewBalance },
            loadLimit: { available },
            requiresLimit: true,
            review: { _ in throw CancellationError() },
            errorText: { _ in nil }
        ),
        format: .preview
    )
    viewModel.onAppear()
    viewModel.setAmount(amount)
    return PerpsFundingAmountView(viewModel: viewModel)
}

@MainActor
private func confirm(destination: PerpsDepositSource, receiveAmount: String, networkFee: String) -> some View {
    let terms = PerpsWithdrawTerms(
        withdrawAmount: "712",
        receiveAmount: receiveAmount,
        receivesAtLeast: destination != previewDestination,
        receiveSymbol: destination.symbol,
        networkFee: networkFee,
        networkFeeSymbol: "USDC",
        networkFeeUsd: Decimal(string: networkFee),
        withdrawalDelaySeconds: destination == previewDestination ? 1072 : nil
    )
    let viewModel = PerpsWithdrawConfirmViewModel(
        reviewed: PerpsReviewedWithdraw(terms: terms) { _ in "preview" },
        destination: destination,
        balance: previewBalance,
        format: .preview,
        message: { _ in .failed },
        passcodeProvider: { nil }
    )
    return PerpsTradeConfirmView(viewModel: viewModel)
}

#Preview("Amount") {
    amountForm(amount: "712", available: "712.56")
        .tkPreviewTheme(.deepBlue)
}

#Preview("Amount, available unknown") {
    amountForm(amount: "", available: nil)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Confirm, relay") {
    confirm(destination: previewRelayDestination, receiveAmount: "132.48", networkFee: "1")
        .tkPreviewTheme(.deepBlue)
}

#Preview("Confirm, direct") {
    confirm(destination: previewDestination, receiveAmount: "712", networkFee: "0")
        .tkPreviewTheme(.deepBlue)
}
