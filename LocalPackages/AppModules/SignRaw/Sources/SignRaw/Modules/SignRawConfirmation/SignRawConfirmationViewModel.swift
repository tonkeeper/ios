import BigInt
import KeeperCore
import SwiftUI
import TKFeatureFlags
import TKLocalize
import TKUIKit
import TonSwift
import UIKit
import WalletExtensions

public enum SignRawAnalyticsPayload {
    case send(
        SignRawSendAnalyticsPayload,
        emulation: SignRawEmulation,
        transferType: TransferType
    )
    case general(
        emulation: SignRawEmulation,
        transferType: TransferType
    )
}

public struct SignRawSendAnalyticsPayload {
    public enum FeePaidIn {
        case ton
        case battery
        case gasless
    }

    public let asset: String
    public let amount: Double
    public let feePaidIn: FeePaidIn

    public init(
        asset: String,
        amount: Double,
        feePaidIn: FeePaidIn
    ) {
        self.asset = asset
        self.amount = amount
        self.feePaidIn = feePaidIn
    }
}

public enum SignRawSignFailure: Error {
    case failedToSign(message: String?)
    case canceled
}

@MainActor
public protocol SignRawConfirmationModuleOutput: AnyObject {
    var didRequireSign: ((TransferData, Wallet) async throws(SignRawSignFailure) -> SignedTransactions)? { get set }
    var didConfirm: (() -> Void)? { get set }
    var didCancelAttempt: (() -> Void)? { get set }
    var didCancel: (() -> Void)? { get set }
    var didRequestSendOpen: ((SignRawSendAnalyticsPayload) -> Void)? { get set }
    var didRequestConfirm: ((SignRawAnalyticsPayload) -> Void)? { get set }
    var didRequestShowInfoPopup: ((_ title: String, _ caption: String) -> Void)? { get set }
    var didRequireShowInsufficientPopup: ((_ wallet: Wallet, _ error: InsufficientFundsError) -> Void)? { get set }
}

@MainActor
public protocol SignRawConfirmationModuleInput: AnyObject {
    func cancel()
}

@MainActor
protocol SignRawConfirmationViewModel: AnyObject {
    var didUpdateHeader: ((TKBottomSheetHeaderConfiguration) -> Void)? { get set }
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)? { get set }

    func viewDidLoad()
}

@MainActor
final class SignRawConfirmationViewModelImplementation: SignRawConfirmationViewModel, SignRawConfirmationModuleOutput, SignRawConfirmationModuleInput {
    // MARK: - SignRawConfirmationModuleOutput

    var didRequireSign: ((TransferData, Wallet) async throws(SignRawSignFailure) -> SignedTransactions)?
    var didConfirm: (() -> Void)?
    var didCancelAttempt: (() -> Void)?
    var didCancel: (() -> Void)?
    var didRequestSendOpen: ((SignRawSendAnalyticsPayload) -> Void)?
    var didRequestConfirm: ((SignRawAnalyticsPayload) -> Void)?
    var didRequestShowInfoPopup: ((_ title: String, _ caption: String) -> Void)?
    var didRequireShowInsufficientPopup: ((_ wallet: Wallet, _ error: InsufficientFundsError) -> Void)?

    // MARK: - SignRawConfirmationModuleInput

    func cancel() {
        signRawController.cancel()
    }

    // MARK: - SignRawConfirmationViewModel

    var didUpdateHeader: ((TKBottomSheetHeaderConfiguration) -> Void)?
    var didUpdateConfiguration: ((TKPopUp.Configuration) -> Void)?

    func viewDidLoad() {
        signRawController.signHandler = { [weak self] transferData, wallet throws(TransactionConfirmationError) in
            guard let self else {
                throw .cancelledByUser
            }
            return try await signHandler(transferData: transferData, wallet: wallet)
        }

        didUpdateHeader?(createHeaderConfiguration())
        updateConfiguration()
        emulate()
    }

    private func signHandler(
        transferData: TransferData,
        wallet: Wallet
    ) async throws(TransactionConfirmationError) -> SignedTransactions {
        guard let didRequireSign else {
            throw .cancelledByUser
        }
        do {
            return try await didRequireSign(transferData, wallet)
        } catch {
            switch error {
            case .canceled:
                throw .cancelledByUser
            case let .failedToSign(message):
                throw .failedToSign(message: message)
            }
        }
    }

    // MARK: - State

    private struct State {
        enum EmulationState {
            case emulating
            case success(model: SignRawConfirmationModel, emulation: SignRawEmulation, transferType: TransferType)
            case fail

            var transferType: TransferType {
                switch self {
                case .emulating:
                    return .default
                case let .success(_, _, transferType):
                    return transferType
                case .fail:
                    return .default
                }
            }
        }

        enum ConfirmationState {
            case idle
            case process
            case success
            case failed
        }

        var emulationState: EmulationState = .emulating
        var confirmationState: ConfirmationState = .idle
    }

    private var state = State() {
        didSet {
            updateConfiguration()
        }
    }

    private let wallet: Wallet
    private let signRawController: SignRawController
    private let signRawConfirmationMapper: SignRawConfirmationMapper
    private let fundsValidator: InsufficientFundsValidator
    private let configurationAssembly: ConfigurationAssembly

    init(
        wallet: Wallet,
        signRawController: SignRawController,
        signRawConfirmationMapper: SignRawConfirmationMapper,
        fundsValidator: InsufficientFundsValidator,
        configurationAssembly: ConfigurationAssembly
    ) {
        self.wallet = wallet
        self.signRawController = signRawController
        self.signRawConfirmationMapper = signRawConfirmationMapper
        self.fundsValidator = fundsValidator
        self.configurationAssembly = configurationAssembly
    }

    private func emulate() {
        Task { [weak self] in
            guard let self else { return }

            do {
                let emulationResult = try await signRawController.emulate()
                let model = signRawConfirmationMapper.mapEmulationResult(
                    emulation: emulationResult,
                    wallet: wallet
                )
                try fundsValidator
                    .validateEmulationResultIfNeeded(
                        emulationResult,
                        wallet: wallet,
                        numOfInternals: await signRawController.numOfMessages()
                    )
                state.emulationState = .success(
                    model: model,
                    emulation: emulationResult,
                    transferType: emulationResult.transferType
                )
                if case let .send(payload, _, _) = makeSendAnalyticsPayload(
                    emulation: emulationResult,
                    transferType: emulationResult.transferType
                ) {
                    didRequestSendOpen?(payload)
                }
            } catch {
                if let error = error as? InsufficientFundsError {
                    self.didRequireShowInsufficientPopup?(self.wallet, error)
                }

                state.emulationState = .fail
            }
        }
    }

    private func updateConfiguration() {
        var items = [TKPopUp.Item]()
        if let loaderItem = createLoaderItem() {
            items.append(loaderItem)
        }
        if let contentItem = createContentItem() {
            items.append(contentItem)
        }
        items.append(createProcessItem())

        let configuration = TKPopUp.Configuration(
            items: items
        )
        didUpdateConfiguration?(configuration)
    }

    private func createLoaderItem() -> TKPopUp.Item? {
        guard case .emulating = state.emulationState else { return nil }
        return TKPopUp.Component.GroupComponent(
            padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16),
            items: [
                TKPopUp.Component.Loader(
                    size: .medium,
                    style: .primary
                ),
            ]
        )
    }

    private func createProcessItem() -> TKPopUp.Item {
        var items = [TKPopUp.Item]()
        if configurationAssembly.configuration.isConfirmButtonInsteadSlider {
            items.append(createButtonsItem())
        } else {
            items.append(createSliderItem())
        }

        items.append(createRiskItem())

        return TKPopUp.Component.Process(
            items: items,
            state: {
                switch state.confirmationState {
                case .idle:
                    return .idle
                case .process:
                    return .process
                case .success:
                    return .success
                case .failed:
                    return .failed
                }
            }(),
            successTitle: TKLocales.Result.success,
            errorTitle: TKLocales.Result.failure
        )
    }

    private func createButtonsItem() -> TKPopUp.Item {
        let isEnable: Bool
        let isWarning: Bool
        switch state.emulationState {
        case .emulating:
            isEnable = false
            isWarning = false
        case .success:
            isEnable = true
            isWarning = false
        case .fail:
            isEnable = true
            isWarning = true
        }

        var confirmButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .primary, size: .large)
        confirmButtonConfiguration.content = .init(title: .plainString(TKLocales.Actions.Confirm.title))
        confirmButtonConfiguration.isEnabled = isEnable
        confirmButtonConfiguration.action = { [weak self] in
            self?.confirmTransaction()
        }
        if isWarning {
            confirmButtonConfiguration.backgroundColors = [
                .normal: .Accent.orange,
                .highlighted: .Accent.orange.withAlphaComponent(0.7),
                .disabled: .Accent.orange.withAlphaComponent(0.48),
            ]
        }

        var cancelButtonConfiguration = TKButton.Configuration.actionButtonConfiguration(category: .secondary, size: .large)
        cancelButtonConfiguration.content = .init(title: .plainString(TKLocales.Actions.cancel))
        cancelButtonConfiguration.action = { [weak self] in
            self?.cancel()
            self?.didCancel?()
        }

        return TKPopUp.Component.HorizontalGroupComponent(
            padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16),
            items: [
                TKPopUp.Component.ButtonComponent(
                    buttonConfiguration: cancelButtonConfiguration
                ),
                TKPopUp.Component.ButtonComponent(
                    buttonConfiguration: confirmButtonConfiguration
                ),
            ],
            spacing: 8,
            distribution: .fillEqually
        )
    }

    private func createSliderItem() -> TKPopUp.Item {
        let isEnable: Bool
        let isWarning: Bool
        switch state.emulationState {
        case .emulating:
            isEnable = false
            isWarning = false
        case .success:
            isEnable = true
            isWarning = false
        case .fail:
            isEnable = true
            isWarning = true
        }

        let sliderItem = TKPopUp.Component.Slider(
            title: TKLocales.Actions.Confirm.title.withTextStyle(.label1, color: .Text.tertiary, alignment: .center),
            isEnable: isEnable,
            appearance: isWarning ? .warning : .standart,
            didConfirm: { [weak self] in
                self?.confirmTransaction()
            }
        )

        return TKPopUp.Component.GroupComponent(
            padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
            items: [
                sliderItem,
            ]
        )
    }

    private func createWarningBanner() -> TKPopUp.Item {
        let banner = TKPopUp.Component.WarningBanner(title: TKLocales.ConfirmSend.FailedEmulationWarning.title)
        return TKPopUp.Component.GroupComponent(
            padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16),
            items: [
                banner,
            ]
        )
    }

    private func createRiskItem() -> TKPopUp.Item {
        let failedItem: () -> TKPopUp.Item = {
            TKPopUp.Component.LabelComponent(
                text: TKLocales.State.failed.withTextStyle(
                    .body2,
                    color: .Text.secondary,
                    alignment: .center,
                    lineBreakMode: .byTruncatingTail
                ),
                numberOfLines: 1
            )
        }

        let loadingItem: () -> TKPopUp.Item = {
            TKPopUp.Component.LabelComponent(
                text: TKLocales.Toast.loading.withTextStyle(
                    .body2,
                    color: .Text.secondary,
                    alignment: .center,
                    lineBreakMode: .byTruncatingTail
                ),
                numberOfLines: 1
            )
        }

        switch state.emulationState {
        case .emulating:
            return loadingItem()
        case let .success(model, _, _):
            guard let risk = model.risk else { return failedItem() }
            return SignRawRiskView.Model(
                bottomSpace: 0,
                title: risk.title,
                isRisk: risk.isRisk,
                action: { [weak self] in
                    guard let self, let risk = model.risk else {
                        return
                    }
                    self.didRequestShowInfoPopup?(risk.title, risk.caption)
                }
            )
        case .fail:
            return failedItem()
        }
    }

    private func createContentItem() -> TKPopUp.Item? {
        switch state.emulationState {
        case .emulating:
            return nil
        case let .success(model, _, _):
            return TKPopUp.Component.GroupComponent(
                padding: UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16),
                items: [SignRawContentView.Configuration(
                    actionsConfiguration: model.contentModel
                )]
            )
        case .fail:
            return createWarningBanner()
        }
    }

    private func createHeaderConfiguration() -> TKBottomSheetHeaderConfiguration {
        let wallet = wallet
        let subtitle: (TKPalette) -> Text = { palette in
            Text("\(TKLocales.ConfirmSend.wallet): ")
                .foregroundColor(palette.text.secondary)
                + wallet.bottomSheetHeaderText(palette: palette)
        }

        return TKBottomSheetHeaderConfiguration(
            title: .text(
                title: .init(
                    TKLocales.ConfirmSend.TokenTransfer.title,
                    textStyle: .h3,
                    foregroundColor: .textPrimary
                ),
                subtitle: .init(
                    text: subtitle,
                    textStyle: .body2,
                    lineLimit: 1
                )
            ),
            contentInsets: UIEdgeInsets(
                top: 8,
                left: 16,
                bottom: 8,
                right: 16
            )
        )
    }

    private func confirmTransaction() {
        Task {
            await confirmTransaction()
        }
    }

    private func confirmTransaction() async {
        switch state.emulationState {
        case let .success(_, emulation, transferType):
            didRequestConfirm?(
                makeSendAnalyticsPayload(
                    emulation: emulation,
                    transferType: transferType
                )
            )
        default:
            break
        }
        state.confirmationState = .process
        do {
            try await signRawController.sendTransaction(transactionType: state.emulationState.transferType)
            state.confirmationState = .success
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            didConfirm?()
        } catch {
            switch error {
            case let .secondOption(transactionError) where transactionError.isCancel:
                state.confirmationState = .idle
                didCancelAttempt?()
            default:
                state.confirmationState = .failed
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                state.confirmationState = .idle
            }
        }
    }

    private func makeSendAnalyticsPayload(
        emulation: SignRawEmulation,
        transferType: TransferType
    ) -> SignRawAnalyticsPayload {
        let feePaidIn: SignRawSendAnalyticsPayload.FeePaidIn
        if transferType.isBattery {
            feePaidIn = .battery
        } else if transferType.isGasless {
            feePaidIn = .gasless
        } else {
            feePaidIn = .ton
        }
        guard emulation.event.actions.count == 1,
              let action = emulation.event.actions.first
        else {
            return .general(
                emulation: emulation,
                transferType: transferType
            )
        }
        let sendPayload: SignRawSendAnalyticsPayload
        switch action.type {
        case let .tonTransfer(transfer):
            let amountValue = amountDouble(
                value: BigUInt(transfer.amount.magnitude),
                decimals: TonInfo.fractionDigits
            )
            sendPayload = SignRawSendAnalyticsPayload(
                asset: Token.ton(.ton).assetId(network: wallet.network),
                amount: amountValue,
                feePaidIn: feePaidIn
            )
        case let .jettonTransfer(transfer):
            let amountValue = amountDouble(
                value: transfer.amount,
                decimals: transfer.jettonInfo.fractionDigits
            )
            sendPayload = SignRawSendAnalyticsPayload(
                asset: AssetId.jetton(address: transfer.jettonInfo.address, network: wallet.network),
                amount: amountValue,
                feePaidIn: feePaidIn
            )
        case let .nftItemTransfer(transfer):
            sendPayload = SignRawSendAnalyticsPayload(
                asset: AssetId.nft(address: transfer.nftAddress, network: wallet.network),
                amount: 1,
                feePaidIn: feePaidIn
            )
        default:
            return .general(
                emulation: emulation,
                transferType: transferType
            )
        }
        return .send(sendPayload, emulation: emulation, transferType: transferType)
    }

    private func amountDouble(value: BigUInt, decimals: Int) -> Double {
        NSDecimalNumber.fromBigUInt(value: value, decimals: decimals).doubleValue
    }
}
