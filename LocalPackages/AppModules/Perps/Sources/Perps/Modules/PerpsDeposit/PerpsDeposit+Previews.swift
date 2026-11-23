import PerpsModels
import SwiftUI
import TKLocalize
import TKUIKit

private let previewSource = PerpsDepositSource(assetId: "eth/mainnet/erc20/usdc", symbol: "USDC", decimals: 6, network: .ethereum)
private let previewBalance = PerpsFundingBalance(amount: "3906.12", usdPrice: 0.9998, iconURL: nil)

private struct PreviewBlock: Error {}

private enum PreviewQuote: Equatable {
    case none
    case quoted(firstDeposit: Bool)
    case fetching
    case failed
}

@MainActor
private func amountForm(
    amount: String,
    balance: PerpsFundingBalance?,
    isLoading: Bool = false,
    quote: PreviewQuote = .none,
    isBlocked: Bool = false
) -> some View {
    let viewModel = PerpsDepositAmountViewModel(
        config: PerpsFundingAmountConfig(
            title: "Deposit to Perps",
            asset: { previewSource },
            initialUnit: .token,
            showsAvailable: false,
            fixedUsdPrice: nil,
            loadBalance: { balance },
            loadLimit: nil,
            loadMinimum: isBlocked ? { throw PreviewBlock() } : nil,
            loadPreferredAsset: isLoading ? { nil } : nil,
            review: { _ in
                switch quote {
                case let .quoted(firstDeposit):
                    return PerpsReviewedDeposit(terms: quotedTerms(firstDeposit: firstDeposit)) { _, _ in .registered(operationId: "") }
                case .fetching:
                    try await Task.sleep(nanoseconds: .max)
                    throw CancellationError()
                case .none, .failed:
                    throw CancellationError()
                }
            },
            errorText: { $0 is PreviewBlock ? TKLocales.Perps.DepositForm.addressBlocked : nil },
            blocksAsset: { $0 is PreviewBlock },
            quote: quote == .none ? nil : { PerpsFundingQuote(deposit: $0.terms) }
        ),
        format: .preview,
        quoteDebounce: 0
    )
    viewModel.onAddFunds = {}
    viewModel.onChooseAnotherWallet = {}
    if !isLoading {
        viewModel.onAppear()
        viewModel.setAmount(amount)
    }
    return PerpsFundingAmountView(viewModel: viewModel)
}

private func quotedTerms(firstDeposit: Bool) -> PerpsDepositTerms {
    PerpsDepositTerms(
        sourceAmount: "713",
        sourceSymbol: "USDC",
        creditedAmount: "709.19",
        creditedSymbol: "USDC",
        networkFee: "0.0001",
        networkFeeSymbol: "ETH",
        networkFeeUsd: 0.3,
        providerFees: PerpsDepositProviderFees(destinationGasUsd: 0.1, providerUsd: 0.1),
        accountUninitialized: firstDeposit
    )
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
        providerFees: resumesPayment ? nil : PerpsDepositProviderFees(destinationGasUsd: 0, providerUsd: 0),
        resumesPayment: resumesPayment
    )
}

@MainActor
private func confirm(
    _ terms: PerpsDepositTerms,
    source: PerpsDepositSource = previewSource,
    balance: PerpsFundingBalance = previewBalance,
    pickFee: PerpsDepositFeePicking? = nil
) -> some View {
    PerpsTradeConfirmView(viewModel: PerpsDepositConfirmViewModel(
        reviewed: PerpsReviewedDeposit(terms: terms, pickFee: pickFee) { _, _ in .registered(operationId: "") },
        walletName: "🙃 Main",
        source: source,
        balance: balance,
        format: .preview,
        message: { _ in .failed },
        passcodeProvider: { nil },
        consent: { .refuse }
    ))
}

#Preview("Amount loading") {
    amountForm(amount: "", balance: nil, isLoading: true)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Amount") {
    amountForm(amount: "713", balance: previewBalance)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Amount, quoted, first deposit") {
    amountForm(amount: "713", balance: previewBalance, quote: .quoted(firstDeposit: true))
        .tkPreviewTheme(.deepBlue)
}

#Preview("Amount, quoted") {
    amountForm(amount: "713", balance: previewBalance, quote: .quoted(firstDeposit: false))
        .tkPreviewTheme(.deepBlue)
}

#Preview("Amount, fetching quote") {
    amountForm(amount: "713", balance: previewBalance, quote: .fetching)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Amount, no quote") {
    amountForm(amount: "713", balance: previewBalance, quote: .failed)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Amount over balance") {
    amountForm(amount: "5000", balance: previewBalance)
        .tkPreviewTheme(.deepBlue)
}

#Preview("Amount, address blocked") {
    amountForm(amount: "350", balance: previewBalance, isBlocked: true)
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
        providerFees: PerpsDepositProviderFees(destinationGasUsd: 0.886899, providerUsd: 0.023486),
        estimatedDurationSeconds: 120
    )
    confirm(
        terms,
        source: PerpsDepositSource(assetId: "ton/mainnet/jetton/gram", symbol: "GRAM", decimals: 9, network: .ton),
        balance: PerpsFundingBalance(amount: "25000", usdPrice: 0.0025, iconURL: nil)
    )
    .tkPreviewTheme(.deepBlue)
}

private func tonUsdtTerms(networkFee: String, symbol: String, usd: Decimal?, method: String, shortage: String? = nil) -> PerpsDepositTerms {
    PerpsDepositTerms(
        sourceAmount: "350",
        sourceSymbol: "USD₮",
        creditedAmount: "349.12",
        creditedSymbol: "USDC",
        networkFee: networkFee,
        networkFeeSymbol: symbol,
        networkFeeUsd: usd,
        feeMethodTitle: method,
        feeShortageSymbol: shortage,
        providerFees: PerpsDepositProviderFees(destinationGasUsd: 0, providerUsd: 0.38),
        estimatedDurationSeconds: 120
    )
}

private let tonUsdtSource = PerpsDepositSource(assetId: "ton/mainnet/jetton/usdt", symbol: "USD₮", decimals: 6, network: .ton)

#Preview("Confirm, fee method choice") {
    confirm(
        tonUsdtTerms(networkFee: "0.05", symbol: "GRAM", usd: 0.12, method: "GRAM"),
        source: tonUsdtSource,
        balance: PerpsFundingBalance(amount: "1000", usdPrice: 1, iconURL: nil),
        pickFee: { _ in }
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Confirm, battery") {
    confirm(
        tonUsdtTerms(networkFee: "12", symbol: "charges", usd: nil, method: "Battery"),
        source: tonUsdtSource,
        balance: PerpsFundingBalance(amount: "1000", usdPrice: 1, iconURL: nil),
        pickFee: { _ in }
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Confirm, first deposit") {
    let terms = PerpsDepositTerms(
        sourceAmount: "350",
        sourceSymbol: "GRAM",
        creditedAmount: "707.19",
        creditedSymbol: "USDC",
        networkFee: "0.12",
        networkFeeSymbol: "GRAM",
        networkFeeUsd: 0.25,
        feeMethodTitle: "GRAM",
        providerFees: PerpsDepositProviderFees(destinationGasUsd: 0, providerUsd: 0.25),
        estimatedDurationSeconds: 120,
        createsAccount: true
    )
    confirm(
        terms,
        source: PerpsDepositSource(assetId: "ton/mainnet/coin", symbol: "GRAM", decimals: 9, network: .ton),
        balance: PerpsFundingBalance(amount: "2345", usdPrice: 2.0359, iconURL: nil),
        pickFee: { _ in }
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Confirm, first deposit, battery") {
    let terms = PerpsDepositTerms(
        sourceAmount: "713.01",
        sourceSymbol: "USD₮",
        creditedAmount: "707.19",
        creditedSymbol: "USDC",
        networkFee: "20",
        networkFeeSymbol: "charges",
        feeMethodTitle: "Battery",
        paysFeeInCharges: true,
        networkFeeReserve: "5 charges",
        providerFees: PerpsDepositProviderFees(destinationGasUsd: 4, providerUsd: 0),
        estimatedDurationSeconds: 120,
        createsAccount: true
    )
    confirm(
        terms,
        source: tonUsdtSource,
        balance: PerpsFundingBalance(amount: "1000", usdPrice: 0.9994, iconURL: nil),
        pickFee: { _ in }
    )
    .tkPreviewTheme(.deepBlue)
}

#Preview("Confirm, fee not covered") {
    confirm(
        tonUsdtTerms(networkFee: "0.05", symbol: "GRAM", usd: 0.12, method: "GRAM", shortage: "GRAM"),
        source: tonUsdtSource,
        balance: PerpsFundingBalance(amount: "1000", usdPrice: 1, iconURL: nil),
        pickFee: { _ in }
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
