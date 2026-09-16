import Foundation
import KeeperCore
import SwiftUI
import TKLogging
import TKUIKit

@MainActor
protocol WalletConnectRequestModuleOutput: AnyObject {
    var didApprove: (() async throws -> Void)? { get set }
    var didReject: (() async throws -> Void)? { get set }
    var didOpenDAppHost: ((URL) -> Void)? { get set }
    var didComplete: (() -> Void)? { get set }
}

struct WalletConnectRequestContent {
    let dappName: String
    let dappHost: String
    let dappURL: URL?
    let dappIconURL: URL?
    let description: String
    let headline: AttributedString
    let chainIcon: UIImage
    let rows: [WalletConnectRequestInfoRow]
    let advancedDetails: [WalletConnectRequestDetailItem]
}

struct WalletConnectRequestInfoRow: Identifiable {
    enum ID: Hashable {
        case wallet
        case app
        case network
        case request
        case fee
    }

    let id: ID
    let title: String
    let value: AttributedString
    let subtitle: String?
    let valueIcon: UIImage?
    let trailingIcon: UIImage?
    let trailingIconColor: TKColor
}

struct WalletConnectRequestDetailItem {
    indirect enum Value {
        case primitive(String)
        case collection([WalletConnectRequestDetailItem])
    }

    let id: String
    let title: String
    let value: Value
    let isDefaultExpanded: Bool
}

enum WalletConnectRequestActionBarState: Equatable {
    case idle
    case loading
    case success
    case failure
}

enum WalletConnectRequestRetryAction: Equatable {
    case approve
    case reject
}

enum WalletConnectRequestDeliveryRetryError: LoggableError, Equatable {
    case approve(WalletConnectResponseError)
    case reject(WalletConnectResponseError)

    var retryAction: WalletConnectRequestRetryAction {
        switch self {
        case .approve:
            return .approve
        case .reject:
            return .reject
        }
    }

    var responseError: WalletConnectResponseError {
        switch self {
        case let .approve(error),
             let .reject(error):
            return error
        }
    }

    var logDescription: String {
        let action: String
        switch self {
        case .approve:
            action = "approve"
        case .reject:
            action = "reject"
        }
        return "type=WalletConnectRequestDeliveryRetryError, action=\(action), underlying=\(responseError.logDescription)"
    }
}

extension WalletConnectRequestDeliveryRetryError: LocalizedError {
    var errorDescription: String? {
        responseError.errorDescription
    }
}

@MainActor
final class WalletConnectRequestViewModel:
    ObservableObject,
    WalletConnectRequestModuleOutput
{
    @Published private(set) var content: WalletConnectRequestContent
    @Published private(set) var actionBarState = WalletConnectRequestActionBarState.idle
    @Published private var lifecycleState = WalletConnectRequestLifecycleState.idle
    @Published var isAdvancedDetailsExpanded = false

    var didApprove: (() async throws -> Void)?
    var didReject: (() async throws -> Void)?
    var didOpenDAppHost: ((URL) -> Void)?
    var didComplete: (() -> Void)?

    var canApprove: Bool {
        lifecycleState.canApprove
    }

    var canReject: Bool {
        lifecycleState.canReject
    }

    var canDismiss: Bool {
        lifecycleState.canReject
    }

    private let resultPresentationDuration: UInt64
    private let showErrorToast: (String) -> Void

    init(
        content: WalletConnectRequestContent,
        resultPresentationDuration: UInt64 = Layout.resultPresentationDuration,
        showErrorToast: @escaping (String) -> Void = { message in
            ToastPresenter.showToast(
                configuration: ToastPresenter.Configuration(
                    title: message
                )
            )
        }
    ) {
        self.content = content
        self.resultPresentationDuration = resultPresentationDuration
        self.showErrorToast = showErrorToast
    }

    func openDAppHost() {
        guard let dappURL = content.dappURL else { return }
        didOpenDAppHost?(dappURL)
    }

    func toggleAdvancedDetails() {
        isAdvancedDetailsExpanded.toggle()
    }

    func approve() {
        guard lifecycleState.canApprove else { return }
        lifecycleState = .approving
        actionBarState = .loading

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await didApprove?()
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

private extension WalletConnectRequestViewModel {
    func handleFailure(
        _ error: Error,
        fallbackRetryAction: WalletConnectRequestRetryAction
    ) async {
        actionBarState = .failure
        showErrorToast(errorMessage(error))
        if isExpiredRequestError(error) {
            lifecycleState = .resolved
            didComplete?()
            return
        }

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
        (error as? LocalizedError)?.errorDescription ?? "\(error)"
    }

    func retryAction(
        for error: Error,
        fallbackRetryAction: WalletConnectRequestRetryAction
    ) -> WalletConnectRequestRetryAction? {
        if let error = error as? WalletConnectRequestDeliveryRetryError {
            return error.retryAction
        }

        guard let error = responseError(from: error),
              error.isRetryableDeliveryFailure
        else {
            return nil
        }
        return fallbackRetryAction
    }

    func responseError(from error: Error) -> WalletConnectResponseError? {
        if let error = error as? WalletConnectRequestDeliveryRetryError {
            return error.responseError
        }
        return error as? WalletConnectResponseError
    }

    func isExpiredRequestError(_ error: Error) -> Bool {
        guard let error = responseError(from: error) else {
            return false
        }
        if case .requestExpired = error {
            return true
        }
        return false
    }

    enum Layout {
        static let resultPresentationDuration: UInt64 = 1_500_000_000
    }
}

private enum WalletConnectRequestLifecycleState: Equatable {
    case idle
    case approving
    case rejecting
    case waitingForRetry(WalletConnectRequestRetryAction)
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
}
