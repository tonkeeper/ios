import Foundation
import KeeperCore
import OperationReviewModels
import SwiftUI
import TKLogging
import TKUIKit

@MainActor
protocol WalletConnectRequestModuleOutput: AnyObject {
    var didApprove: ((WalletConnectEVMFee?, OperationConsent) async throws -> Void)? { get set }
    var didReject: (() async throws -> Void)? { get set }
    var didDeliverResponse: (() -> Void)? { get set }
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
    var rows: [WalletConnectRequestInfoRow]
    let advancedDetails: [WalletConnectRequestDetailItem]
}

/// The wallet's own price of an EVM transaction, loaded while the request is on screen.
struct WalletConnectRequestFeeQuote {
    enum Display {
        case loading
        case loaded(WalletConnectEVMFee)
        case unavailable
    }

    let load: () async throws -> WalletConnectEVMFee
    let row: (Display) -> WalletConnectRequestInfoRow
    var loadFiatPrice: () async -> Void = {}
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
    @Published private var feeState: WalletConnectRequestFeeState
    @Published private var reviewState = WalletConnectRequestReviewState.loading
    @Published var isAdvancedDetailsExpanded = false
    private(set) var hasFailedApprovalDelivery = false

    var didApprove: ((WalletConnectEVMFee?, OperationConsent) async throws -> Void)?
    var didReject: (() async throws -> Void)?
    var didDeliverResponse: (() -> Void)?
    var didOpenDAppHost: ((URL) -> Void)?
    var didComplete: (() -> Void)?
    /// A fresh consent for each approval, asked on the screen.
    var consent: (() -> OperationConsent)?

    var canApprove: Bool {
        lifecycleState.canApprove && feeState.allowsApproval
    }

    var review: OperationReview? {
        guard case let .loaded(review) = reviewState else { return nil }
        return review
    }

    var canReject: Bool {
        lifecycleState.canReject
    }

    var canDismiss: Bool {
        lifecycleState.canReject
    }

    private let feeQuote: WalletConnectRequestFeeQuote?
    private let loadReview: () async -> OperationReview?
    private let waitForResultPresentation: () async -> Void
    private let showErrorToast: (String) -> Void
    private var responseTask: Task<Void, Never>?
    private var responseDelivered = false
    private var isFiatPriceLoaded = false
    private var submissionNotificationHandled = false
    private var closedSubmittedRequestId: String?

    init(
        content: WalletConnectRequestContent,
        feeQuote: WalletConnectRequestFeeQuote? = nil,
        review: @escaping () async -> OperationReview?,
        resultPresentationDuration: UInt64 = Layout.resultPresentationDuration,
        waitForResultPresentation: (() async -> Void)? = nil,
        showErrorToast: @escaping (String) -> Void = { message in
            ToastPresenter.showToast(
                configuration: ToastPresenter.Configuration(
                    title: message
                )
            )
        }
    ) {
        self.content = content
        self.feeQuote = feeQuote
        self.feeState = feeQuote == nil ? .notRequired : .loading
        self.loadReview = review
        self.waitForResultPresentation = waitForResultPresentation ?? {
            try? await Task.sleep(nanoseconds: resultPresentationDuration)
        }
        self.showErrorToast = showErrorToast
    }

    /// The fee and the review of what is signed, loaded alongside while the request is on screen.
    /// SwiftUI restarts the task each time the screen appears again, as after the passcode: what
    /// loaded is kept, and a load the screen left before it finished is made again.
    func load() async {
        async let fee: Void = loadFee()
        if case .loading = reviewState {
            let review = await loadReview()
            if !Task.isCancelled {
                reviewState = .loaded(review)
            }
        }
        await fee
    }

    func loadFee() async {
        guard let feeQuote else { return }
        async let fiatPrice: Void = loadFiatPrice(of: feeQuote)
        guard case .loading = feeState else {
            await fiatPrice
            return
        }
        let display: WalletConnectRequestFeeQuote.Display
        do {
            let fee = try await feeQuote.load()
            feeState = .loaded(fee)
            display = .loaded(fee)
        } catch {
            guard !Task.isCancelled else { return }
            Log.walletConnect.w("request fee quote failed", error: error)
            feeState = .unavailable
            display = .unavailable
        }
        showFeeRow(display, of: feeQuote)
        await fiatPrice
    }

    func openDAppHost() {
        guard let dappURL = content.dappURL else { return }
        didOpenDAppHost?(dappURL)
    }

    func toggleAdvancedDetails() {
        isAdvancedDetailsExpanded.toggle()
    }

    func approve() {
        guard canApprove else { return }
        hasFailedApprovalDelivery = false
        let evmFee = feeState.quotedFee
        let consent = consent?() ?? .refuse
        lifecycleState = .approving
        actionBarState = .loading

        responseTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await didApprove?(evmFee, consent)
                responseDelivered = true
                didDeliverResponse?()
                guard !Task.isCancelled else { return }
                lifecycleState = .resolved
                actionBarState = .success
            } catch {
                guard !Task.isCancelled else {
                    // Expiry can close the screen before an in-flight broadcast succeeds.
                    if let id = closedSubmittedRequestId {
                        showFailure(WalletConnectResponseError.requestExpiredAfterBroadcast(id: id))
                    } else if let responseError = responseError(from: error), case .requestExpiredAfterBroadcast = responseError {
                        showFailure(error)
                    }
                    return
                }
                await handleFailure(error, fallbackRetryAction: .approve)
                return
            }

            await waitForResultPresentation()
            guard !Task.isCancelled else { return }
            didComplete?()
        }
    }

    func reject() {
        guard lifecycleState.canReject else { return }
        lifecycleState = .rejecting
        actionBarState = .loading

        responseTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await didReject?()
                responseDelivered = true
                didDeliverResponse?()
                guard !Task.isCancelled else { return }
                lifecycleState = .resolved
                didComplete?()
            } catch {
                guard !Task.isCancelled else { return }
                await handleFailure(error, fallbackRetryAction: .reject)
            }
        }
    }

    func disappeared() {
        guard lifecycleState.canReject else { return }
        lifecycleState = .resolved
        let didReject = didReject
        let didDeliverResponse = didDeliverResponse
        let didComplete = didComplete
        responseTask = Task { @MainActor [weak self] in
            do {
                try await didReject?()
                self?.responseDelivered = true
                didDeliverResponse?()
                guard !Task.isCancelled else { return }
            } catch {
                // Leaving the screen completes even when its rejection could not be delivered.
            }
            guard !Task.isCancelled else { return }
            didComplete?()
        }
    }

    /// A delivered response finishes its normal dismissal and dApp redirect.
    @discardableResult
    func completeWithoutReject(submittedRequestId: String? = nil, submissionNotificationHandled: Bool = false) -> Bool {
        guard !responseDelivered else { return false }
        closedSubmittedRequestId = submittedRequestId ?? closedSubmittedRequestId
        self.submissionNotificationHandled = self.submissionNotificationHandled || submissionNotificationHandled
        lifecycleState = .resolved
        responseTask?.cancel()
        responseTask = nil
        return true
    }
}

private extension WalletConnectRequestViewModel {
    func loadFiatPrice(of feeQuote: WalletConnectRequestFeeQuote) async {
        guard !isFiatPriceLoaded else { return }
        await feeQuote.loadFiatPrice()
        guard !Task.isCancelled else { return }
        isFiatPriceLoaded = true
        if case let .loaded(fee) = feeState {
            showFeeRow(.loaded(fee), of: feeQuote)
        }
    }

    func showFeeRow(_ display: WalletConnectRequestFeeQuote.Display, of feeQuote: WalletConnectRequestFeeQuote) {
        guard let index = content.rows.firstIndex(where: { $0.id == .fee }) else { return }
        content.rows[index] = feeQuote.row(display)
    }

    func handleFailure(
        _ error: Error,
        fallbackRetryAction: WalletConnectRequestRetryAction
    ) async {
        actionBarState = .failure
        hasFailedApprovalDelivery = retryAction(for: error, fallbackRetryAction: fallbackRetryAction) == .approve
        showFailure(error)
        if isExpiredRequestError(error) {
            lifecycleState = .resolved
            didComplete?()
            return
        }

        await waitForResultPresentation()
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

    func showFailure(_ error: Error) {
        if let responseError = responseError(from: error), case .requestExpiredAfterBroadcast = responseError {
            guard !submissionNotificationHandled else { return }
            submissionNotificationHandled = true
        }
        showErrorToast(errorMessage(error))
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
        switch error {
        case .requestExpired, .requestExpiredAfterBroadcast:
            return true
        default:
            return false
        }
    }

    enum Layout {
        static let resultPresentationDuration: UInt64 = 1_500_000_000
    }
}

private enum WalletConnectRequestFeeState {
    case notRequired
    case loading
    case loaded(WalletConnectEVMFee)
    case unavailable

    var allowsApproval: Bool {
        switch self {
        case .notRequired, .loaded:
            return true
        case .loading, .unavailable:
            return false
        }
    }

    var quotedFee: WalletConnectEVMFee? {
        guard case let .loaded(fee) = self else { return nil }
        return fee
    }
}

private enum WalletConnectRequestReviewState {
    case loading
    case loaded(OperationReview?)
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
