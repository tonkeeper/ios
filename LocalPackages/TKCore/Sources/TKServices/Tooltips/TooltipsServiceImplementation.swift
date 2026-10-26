import Foundation
import SwiftUI
import TKLocalize
import TKLogging
import TKUIKit
import UIKit

final class TooltipsServiceImplementation {
    private struct PendingRequest {
        let order: Int
        let id: TooltipID
        let sourceView: UIView
        let targetActionViews: [UIView]
        let configuration: HintConfiguration
        let onTargetAction: (() -> Void)?
    }

    private enum State {
        case idle
        case preparing(PendingRequest)
        case presenting(TooltipPresentationSession)
        case dismissing(TooltipPresentationDescriptor)
    }

    private let tooltipControllerFactory: TooltipControllerFactory
    private let viewControllerFactory: TooltipViewControllerFactory
    private var pendingRequests: [PendingRequest] = []
    private var pendingRequestOrder = 0
    private var state: State = .idle

    init(
        tooltipControllerFactory: TooltipControllerFactory,
        viewControllerFactory: TooltipViewControllerFactory
    ) {
        self.tooltipControllerFactory = tooltipControllerFactory
        self.viewControllerFactory = viewControllerFactory
    }
}

extension TooltipsServiceImplementation: TooltipsService {
    @MainActor
    func showTooltipIfNeeded(
        id: TooltipID,
        sourceView: UIView,
        targetActionViews: [UIView] = [],
        configuration: HintConfiguration,
        onTargetAction: (() -> Void)? = nil
    ) {
        let order = pendingRequestOrder
        pendingRequestOrder += 1
        let request = PendingRequest(
            order: order,
            id: id,
            sourceView: sourceView,
            targetActionViews: targetActionViews,
            configuration: configuration,
            onTargetAction: onTargetAction
        )
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            enqueue(request)
        }
    }

    func didPerformTooltipTargetAction(id: TooltipID) {
        let controller = tooltipControllerFactory.controller(for: id)
        controller.didPerformTargetAction()
        pendingRequests.removeAll {
            $0.id == id
        }
    }
}

extension TooltipsServiceImplementation {
    @MainActor
    private func enqueue(_ request: PendingRequest) {
        pendingRequests.removeAll {
            $0.id == request.id
        }
        pendingRequests.append(request)
        pendingRequests.sort { $0.order < $1.order }
        processQueueIfPossible()
    }

    @MainActor
    private func processQueueIfPossible() {
        guard case .idle = state else {
            return
        }
        // Pick the first reachable request rather than bailing on the head of the
        // queue. Otherwise a stale request whose source view never becomes
        // reachable (e.g. it belongs to another screen) would block every later
        // request indefinitely.
        guard let index = pendingRequests.firstIndex(where: { $0.sourceView.isReachableByUser }) else {
            return
        }
        let request = pendingRequests.remove(at: index)
        Log.tooltips.i("tooltip request \(request.id.logName) is preparing")
        state = .preparing(request)
        Task {
            await present(request)
        }
    }

    @MainActor
    private func present(_ request: PendingRequest) async {
        let controller = tooltipControllerFactory.controller(for: request.id)
        guard request.sourceView.isReachableByUser else {
            Log.tooltips.d("tooltip request \(request.id.logName) is skipped. view is not reachable by user")
            state = .idle
            return processQueueIfPossible()
        }
        guard controller.canShowTooltip else {
            Log.tooltips.d("tooltip request \(request.id.logName) is rejected. cannot show tooltip")
            state = .idle
            return processQueueIfPossible()
        }
        let presentationDescriptor = TooltipPresentationDescriptor(
            id: request.id,
            sourceView: request.sourceView
        )
        let session = TooltipPresentationSession(
            descriptor: presentationDescriptor,
            tooltipController: controller
        )
        Log.tooltips.i("will show \(request.id.logName) tooltip request")
        state = .presenting(session)
        let hintInteractionResult = await session.present(
            configuration: request.configuration,
            targetActionViews: request.targetActionViews,
            contentViewControllerProvider: { [viewControllerFactory] resolvedDirection in
                viewControllerFactory.makeHintViewController(
                    id: request.id,
                    direction: resolvedDirection,
                    maximumWidth: request.configuration.maximumWidth
                )
            }
        )
        switch hintInteractionResult {
        case let .success(interaction):
            Log.tooltips.i("present: \(request.id.logName) tooltip content interaction result - \(interaction)")
            switch interaction {
            case .hintContentTap:
                controller.didPerformTargetAction()
                request.onTargetAction?()
            case .performedTargetAction:
                controller.didPerformTargetAction()
                request.onTargetAction?()
            case .outsideTap:
                controller.didDismiss()
            }
        case let .failure(error):
            Log.tooltips.i("present: failed to show \(request.id.logName) tooltip due to \(error)")
            state = .idle
            processQueueIfPossible()
            return
        }
        state = .dismissing(presentationDescriptor)
        Log.tooltips.i("present: will dismiss tooltip: \(request.id.logName)")
        await HintController.dismiss(sourceView: presentationDescriptor.sourceView)
        Log.tooltips.i("present: tooltip dismissed: id=\(request.id.logName)")
        state = .idle
        processQueueIfPossible()
    }
}

private extension TooltipID {
    var logName: String {
        switch self {
        case .walletBalanceWithdraw:
            "walletBalanceWithdraw"
        case .newHistoryEntryPoint:
            "newHistoryEntryPoint"
        case .tradeTab:
            "tradeTab"
        case .tradeFavorite:
            "tradeFavorite"
        case .addMultichainWalletMain:
            "addMultichainWalletMain"
        case .addMultichainWalletWalletsList:
            "addMultichainWalletWalletsList"
        }
    }
}

extension TooltipPresentationSession.PresentationFailure: CustomStringConvertible {
    var description: String {
        switch self {
        case .failedToPresent:
            "failedToPresent"
        case .alreadyPresented:
            "alreadyPresented"
        }
    }
}
