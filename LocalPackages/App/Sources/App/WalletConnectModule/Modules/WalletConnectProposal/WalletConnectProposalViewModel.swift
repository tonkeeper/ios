import Foundation
import KeeperCore
import TKLocalize
import TKUIKit

@MainActor
protocol WalletConnectProposalModuleOutput: AnyObject {
    var didApprove: ((Wallet) async throws -> Void)? { get set }
    var didReject: (() async throws -> Void)? { get set }
    var didTapWalletPicker: ((Wallet) -> Void)? { get set }
    var didOpenDAppHost: ((URL) -> Void)? { get set }
    var didRequestValidationConfirmation: ((WalletConnectValidation, @escaping () -> Void) -> Void)? { get set }
    var didComplete: (() -> Void)? { get set }
}

@MainActor
protocol WalletConnectProposalModuleInput: AnyObject {
    func setWallet(_ wallet: Wallet)
}

struct WalletConnectProposalChainItem: Identifiable {
    let chain: WalletConnectChain
    let cellContent: WalletConnectChainCellContent

    var id: WalletConnectChain {
        chain
    }
}

struct WalletConnectProposalPermissionItem: Identifiable, Equatable {
    enum Permission: Equatable {
        case infoAndActivity
        case transactionApproval
        case messageSign

        var title: String {
            switch self {
            case .infoAndActivity:
                TKLocales.WalletConnect.Proposal.Permissions.infoAndActivity
            case .transactionApproval:
                TKLocales.WalletConnect.Proposal.Permissions.transactionApproval
            case .messageSign:
                TKLocales.WalletConnect.Proposal.Permissions.messageSign
            }
        }
    }

    let permission: Permission

    var id: Permission {
        permission
    }

    var title: String {
        permission.title
    }

    static func items(methods: Set<WalletConnectMethod>) -> [WalletConnectProposalPermissionItem] {
        var result = [
            WalletConnectProposalPermissionItem(permission: .infoAndActivity),
        ]

        if !methods.isDisjoint(with: transactionApprovalMethods) {
            result.append(WalletConnectProposalPermissionItem(permission: .transactionApproval))
        }

        if !methods.isDisjoint(with: messageSignMethods) {
            result.append(WalletConnectProposalPermissionItem(permission: .messageSign))
        }

        return result
    }
}

private extension WalletConnectProposalPermissionItem {
    static let transactionApprovalMethods: Set<WalletConnectMethod> = [
        .ethSendTransaction,
        .ethSignTransaction,
        .tronSignTransaction,
        .tonSendMessage,
    ]

    static let messageSignMethods: Set<WalletConnectMethod> = [
        .personalSign,
        .ethSignTypedDataV4,
        .tronSignMessage,
        .tonSignData,
    ]
}

struct WalletConnectProposalContent {
    let dappName: String
    let dappHost: String
    let dappURL: URL?
    let dappIconURL: URL?
    let walletTitle: String
    let walletBalance: String?
    let walletAddress: String
    let validation: WalletConnectValidation
    let canApprove: Bool
    let permissions: [WalletConnectProposalPermissionItem]
    let chains: [WalletConnectProposalChainItem]
}

enum WalletConnectProposalActionBarState: Equatable {
    case idle
    case loading
    case success
    case failure
}

enum WalletConnectProposalRetryAction: Equatable {
    case approve
    case reject
}

@MainActor
final class WalletConnectProposalViewModel:
    ObservableObject,
    WalletConnectProposalModuleOutput,
    WalletConnectProposalModuleInput
{
    @Published private(set) var content: WalletConnectProposalContent
    @Published private(set) var actionBarState = WalletConnectProposalActionBarState.idle
    @Published private var lifecycleState = WalletConnectProposalLifecycleState.idle

    var didApprove: ((Wallet) async throws -> Void)?
    var didReject: (() async throws -> Void)?
    var didTapWalletPicker: ((Wallet) -> Void)?
    var didOpenDAppHost: ((URL) -> Void)?
    var didTapNetworksList: (() -> Void)?
    var didRequestValidationConfirmation: ((WalletConnectValidation, @escaping () -> Void) -> Void)?
    var didComplete: (() -> Void)?

    var canApprove: Bool {
        lifecycleState.canApprove && content.canApprove
    }

    var canReject: Bool {
        lifecycleState.canReject
    }

    private var wallet: Wallet
    private let contentProvider: (Wallet) -> WalletConnectProposalContent
    private let resultPresentationDuration: UInt64
    private let showErrorToast: (String) -> Void

    init(
        wallet: Wallet,
        content: WalletConnectProposalContent,
        contentProvider: @escaping (Wallet) -> WalletConnectProposalContent,
        resultPresentationDuration: UInt64 = Layout.resultPresentationDuration,
        showErrorToast: @escaping (String) -> Void = { message in
            ToastPresenter.showToast(
                configuration: ToastPresenter.Configuration(title: message)
            )
        }
    ) {
        self.wallet = wallet
        self.content = content
        self.contentProvider = contentProvider
        self.resultPresentationDuration = resultPresentationDuration
        self.showErrorToast = showErrorToast
    }

    func setWallet(_ wallet: Wallet) {
        guard lifecycleState.canChangeWallet else { return }
        self.wallet = wallet
        content = contentProvider(wallet)
    }

    func tapWalletPicker() {
        guard lifecycleState.canChangeWallet else { return }
        didTapWalletPicker?(wallet)
    }

    func openDAppHost() {
        guard let dappURL = content.dappURL else { return }
        didOpenDAppHost?(dappURL)
    }

    func tapNetworksList() {
        didTapNetworksList?()
    }

    func approve() {
        guard canApprove else { return }

        if content.validation.requiresConfirmation {
            if let didRequestValidationConfirmation {
                didRequestValidationConfirmation(content.validation) { [weak self] in
                    Task { @MainActor in
                        self?.approveConfirmed()
                    }
                }
                return
            }
        }

        approveConfirmed()
    }

    private func approveConfirmed() {
        guard canApprove else { return }
        lifecycleState = .approving
        actionBarState = .loading

        Task { @MainActor [weak self, wallet] in
            guard let self else { return }
            do {
                try await didApprove?(wallet)
                lifecycleState = .resolved
                actionBarState = .success
            } catch {
                await handleFailure(error, fallbackRetryAction: .approve)
                return
            }

            try? await Task.sleep(nanoseconds: resultPresentationDuration)
            guard !Task.isCancelled else { return }
            didComplete?()
        }
    }

    func reject() {
        guard lifecycleState.canReject else { return }
        lifecycleState = .rejecting
        actionBarState = .loading

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await didReject?()
                lifecycleState = .resolved
                didComplete?()
            } catch {
                await handleFailure(error, fallbackRetryAction: .reject)
            }
        }
    }

    func disappeared() {
        guard lifecycleState.canReject else { return }
        lifecycleState = .resolved
        let didReject = didReject
        let didComplete = didComplete
        Task { @MainActor in
            try? await didReject?()
            didComplete?()
        }
    }

    func completeWithoutReject() {
        lifecycleState = .resolved
    }
}

private extension WalletConnectProposalViewModel {
    func handleFailure(
        _ error: Error,
        fallbackRetryAction: WalletConnectProposalRetryAction
    ) async {
        actionBarState = .failure
        showErrorToast(errorMessage(error))

        try? await Task.sleep(nanoseconds: resultPresentationDuration)
        guard !Task.isCancelled else { return }

        if let retryAction = retryAction(for: error, fallbackRetryAction: fallbackRetryAction) {
            lifecycleState = .waitingForRetry(retryAction)
            actionBarState = .idle
            return
        }

        lifecycleState = .resolved
        didComplete?()
    }

    func errorMessage(_ error: Error) -> String {
        return (error as? LocalizedError)?.errorDescription ?? "\(error)"
    }

    func retryAction(
        for error: Error,
        fallbackRetryAction: WalletConnectProposalRetryAction
    ) -> WalletConnectProposalRetryAction? {
        if let error = error as? WalletConnectSessionApprovalError {
            if case let .rejectionFailed(rejectionError) = error,
               rejectionError.isRetryableDeliveryFailure
            {
                return .reject
            }
            if error.isRetryableDeliveryFailure {
                return fallbackRetryAction
            }
        }

        if let error = error as? WalletConnectSessionRejectionError,
           error.isRetryableDeliveryFailure
        {
            return fallbackRetryAction
        }

        return nil
    }

    enum Layout {
        static let resultPresentationDuration: UInt64 = 1_500_000_000
    }
}

private enum WalletConnectProposalLifecycleState: Equatable {
    case idle
    case approving
    case rejecting
    case waitingForRetry(WalletConnectProposalRetryAction)
    case resolved

    var canApprove: Bool {
        switch self {
        case .idle,
             .waitingForRetry(.approve):
            return true
        case .approving,
             .rejecting,
             .waitingForRetry(.reject),
             .resolved:
            return false
        }
    }

    var canReject: Bool {
        switch self {
        case .idle,
             .waitingForRetry(.reject):
            return true
        case .approving,
             .rejecting,
             .waitingForRetry(.approve),
             .resolved:
            return false
        }
    }

    var canChangeWallet: Bool {
        switch self {
        case .idle:
            return true
        case .approving,
             .rejecting,
             .waitingForRetry,
             .resolved:
            return false
        }
    }
}

private extension WalletConnectValidation {
    var requiresConfirmation: Bool {
        switch self {
        case .valid:
            false
        case .invalid, .scam, .unknown:
            true
        }
    }
}
