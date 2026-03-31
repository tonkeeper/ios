import Foundation
import KeeperCore
import TKCore
import TKLocalize
import TKUIKit
import UIKit

protocol SendAssetViewModelProtocol: AnyObject {
    var didTapBack: (() -> Void)? { get set }
    var didTapClose: (() -> Void)? { get set }
    var didTapGoToMain: (() -> Void)? { get set }
    var didUpdateState: ((SendAssetState) -> Void)? { get set }
    var didUpdateTitle: ((String) -> Void)? { get set }
    var didTapQRCode: ((PaymentQRCodeData) -> Void)? { get set }
    var didTapCopy: ((String) -> Void)? { get set }
    var didShowError: ((String) -> Void)? { get set }

    func viewDidLoad()
    func didTapCopyAddress()
    func didTapTermsOfService()
    func didTapQrButton()
}

enum SendAssetState: Equatable {
    case loading(SendAssetExchangePreview)
    case content(SendAssetContentState)
}

typealias SendAssetExchangePreview = SendAssetExchangeView.Model

struct SendAssetContentState: Equatable {
    let fromCode: String
    let toCode: String
    let fromNetworkName: String
    let toNetworkName: String
    let payinAddress: String
    let rateText: String
    let minDeposit: String
    let maxDeposit: String
    let networkName: String
    let estimatedArrivalTime: String
    let fromImageUrl: URL?
    let toImageUrl: URL?
    let fromNetworkImageUrl: URL?
}

final class SendAssetViewModel: SendAssetViewModelProtocol {
    var didTapBack: (() -> Void)?
    var didTapClose: (() -> Void)?
    var didTapGoToMain: (() -> Void)?
    var didUpdateState: ((SendAssetState) -> Void)?
    var didUpdateTitle: ((String) -> Void)?
    var didTapQRCode: ((PaymentQRCodeData) -> Void)?
    var didTapCopy: ((String) -> Void)?
    var didShowError: ((String) -> Void)?

    private let fromAsset: OnRampLayoutCryptoMethod
    private let toAsset: OnRampLayoutToken
    private let wallet: Wallet
    private let onRampService: OnRampService
    private let amountFormatter: AmountFormatter
    private let analyticsProvider: AnalyticsProvider
    private var currentState: SendAssetState

    init(
        fromAsset: OnRampLayoutCryptoMethod,
        toAsset: OnRampLayoutToken,
        wallet: Wallet,
        onRampService: OnRampService,
        amountFormatter: AmountFormatter,
        analyticsProvider: AnalyticsProvider
    ) {
        self.fromAsset = fromAsset
        self.toAsset = toAsset
        self.wallet = wallet
        self.onRampService = onRampService
        self.amountFormatter = amountFormatter
        self.analyticsProvider = analyticsProvider

        currentState = .loading(SendAssetExchangePreview(
            fromImageUrl: URL(string: fromAsset.image),
            fromCode: fromAsset.symbol,
            fromNetwork: fromAsset.networkName,
            toCode: toAsset.symbol,
            toNetwork: toAsset.networkName,
            toImageUrl: URL(string: toAsset.image),
            rateText: nil
        ))
    }

    func viewDidLoad() {
        didUpdateTitle?(TKLocales.Ramp.Deposit.sendAsset(fromAsset.symbol))
        didUpdateState?(currentState)
        logDepositViewC2C()

        Task { @MainActor in
            await loadExchange()
        }
    }

    func didTapCopyAddress() {
        guard case let .content(state) = currentState else { return }
        didTapCopy?(state.payinAddress)
    }

    func didTapTermsOfService() {}

    func didTapQrButton() {
        guard case let .content(state) = currentState else { return }

        didTapQRCode?(
            PaymentQRCodeData(
                address: state.payinAddress,
                iconURL: state.fromImageUrl,
                networkIconURL: state.fromNetworkImageUrl
            )
        )
    }

    @MainActor
    private func loadExchange() async {
        do {
            let walletAddress: String
            if toAsset.isTronNetwork, let address = wallet.tron?.address.base58 {
                walletAddress = address
            } else if let address = try? self.wallet.friendlyAddress.toString() {
                walletAddress = address
            } else {
                return
            }

            let result = try await onRampService.createExchange(
                from: fromAsset.symbol,
                to: toAsset.symbol,
                fromNetwork: fromAsset.network,
                toNetwork: toAsset.network,
                walletAddress: walletAddress
            )
            let content = SendAssetContentState(
                fromCode: fromAsset.symbol,
                toCode: toAsset.symbol,
                fromNetworkName: fromAsset.networkName,
                toNetworkName: toAsset.networkName,
                payinAddress: result.payinAddress,
                rateText: format(rate: result.rate),
                minDeposit: formatAmount(result.minDeposit, code: fromAsset.symbol),
                maxDeposit: formatAmount(result.maxDeposit, code: fromAsset.symbol),
                networkName: fromAsset.networkName,
                estimatedArrivalTime: formatEstimatedArrivalTime(seconds: result.estimatedDuration),
                fromImageUrl: URL(string: fromAsset.image),
                toImageUrl: URL(string: toAsset.image),
                fromNetworkImageUrl: fromAsset.stablecoin ? URL(string: fromAsset.networkImage) : nil
            )
            currentState = .content(content)
            didUpdateState?(.content(content))
        } catch {
            didShowError?(TKLocales.Errors.unknown)
        }
    }

    private func format(rate: Double) -> String {
        let formatted = amountFormatter.format(decimal: Decimal(rate), accessory: .symbol(toAsset.symbol, onLeft: false))
        let fromNetwork = RampItemConfigurator.networkLabel(network: fromAsset.network, networkName: fromAsset.networkName)
        let toNetwork = RampItemConfigurator.networkLabel(network: toAsset.network, networkName: toAsset.networkName)

        if fromAsset.symbol == toAsset.symbol {
            return "1 \(fromAsset.symbol) (\(fromNetwork)) ≈ \(formatted) (\(toNetwork))"
        } else {
            return "1 \(fromAsset.symbol) ≈ \(formatted)"
        }
    }

    private func formatAmount(_ value: Double, code: String) -> String {
        amountFormatter.format(decimal: Decimal(value), accessory: .symbol(code, onLeft: false))
    }

    private func formatEstimatedArrivalTime(seconds: Int) -> String {
        let minutes = max(1, (seconds + 59) / 60)
        return TKLocales.Ramp.Deposit.upToMin(minutes)
    }

    private func logDepositViewC2C() {
        guard
            let buyAsset = toAsset.depositAnalyticsAssetIdentifier.flatMap(DepositViewC2c.BuyAsset.init(rawValue:)),
            let sellAsset = fromAsset.depositAnalyticsAssetIdentifier
        else {
            return
        }

        analyticsProvider.log(
            DepositViewC2c(
                buyAsset: buyAsset,
                sellAsset: sellAsset
            )
        )
    }
}
