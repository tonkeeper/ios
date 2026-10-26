import PerpsModels
import SwiftUI
import TKUIKit

private let previewSource = PerpsDepositSource(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum)
private let previewBalance = PerpsFundingBalance(amount: "3906.12", usdPrice: 0.9998, iconURL: nil)

@MainActor
private func amountForm(amount: String, balance: PerpsFundingBalance?) -> some View {
    let viewModel = PerpsDepositAmountViewModel(
        config: PerpsFundingAmountConfig(
            title: "Deposit Perps balance",
            asset: { previewSource },
            initialUnit: .token,
            fixedUsdPrice: nil,
            loadBalance: { balance },
            loadLimit: nil,
            review: { _ in throw CancellationError() },
            errorText: { _ in nil }
        ),
        format: .preview
    )
    viewModel.onAddFunds = {}
    viewModel.onAppear()
    viewModel.setAmount(amount)
    return PerpsFundingAmountView(viewModel: viewModel)
}

private func usdcTerms(networkFee: String?, resumesPayment: Bool = false) -> PerpsDepositTerms {
    PerpsDepositTerms(
        sourceAmount: "713.01",
        sourceSymbol: "USDC",
        creditedAmount: "713.01",
        creditedSymbol: "USDC",
        networkFee: networkFee,
        networkFeeSymbol: "ETH",
        networkFeeUsd: networkFee == nil ? nil : 0.5,
        resumesPayment: resumesPayment
    )
}

@MainActor
private func confirm(
    _ terms: PerpsDepositTerms,
    source: PerpsDepositSource = previewSource,
    balance: PerpsFundingBalance = previewBalance
) -> some View {
    PerpsTradeConfirmView(viewModel: PerpsDepositConfirmViewModel(
        reviewed: PerpsReviewedDeposit(terms: terms) { _ in .registered(operationId: "") },
        walletName: "🙃 Main",
        source: source,
        balance: balance,
        format: .preview,
        message: { _ in .failed },
        passcodeProvider: { nil }
    ))
}

#Preview("Amount") {
    amountForm(amount: "713", balance: previewBalance)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Amount over balance") {
    amountForm(amount: "5000", balance: previewBalance)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Amount, balance unknown") {
    amountForm(amount: "", balance: nil)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Confirm") {
    confirm(usdcTerms(networkFee: "0.00021"))
        .tkPreviewTheme(.deepBlue)
}

#Preview("Confirm, small GRAM") {
    let terms = PerpsDepositTerms(
        sourceAmount: "1000",
        sourceSymbol: "GRAM",
        creditedAmount: "1.26",
        creditedSymbol: "USDC",
        networkFee: "0.12",
        networkFeeSymbol: "TON",
        networkFeeUsd: 0.38,
        estimatedDurationSeconds: 120
    )
    confirm(
        terms,
        source: PerpsDepositSource(assetId: "ton/mainnet/jetton/gram", symbol: "GRAM", decimals: 9, network: .ton),
        balance: PerpsFundingBalance(amount: "25000", usdPrice: 0.0025, iconURL: nil)
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Confirm, fee unknown") {
    confirm(usdcTerms(networkFee: nil))
        .tkPreviewTheme(.deepBlue)
}

#Preview("Confirm resuming") {
    confirm(usdcTerms(networkFee: nil, resumesPayment: true))
        .tkPreviewTheme(.deepBlue)
}

@available(iOS 17.0, *)
#Preview("Choose asset", traits: .sizeThatFitsLayout) {
    let asset = PerpsFundingAssetRow(
        symbol: "USDC",
        network: .ethereum,
        iconURL: nil,
        balanceText: "3 906.12 USDC · $3 905.34"
    )
    PerpsFundingAssetSheetView(assets: [asset], selected: asset) { _ in }
        .padding(.top, 16)
        .background(.backgroundPage)
        .tkPreviewTheme(.deepBlue)
}
