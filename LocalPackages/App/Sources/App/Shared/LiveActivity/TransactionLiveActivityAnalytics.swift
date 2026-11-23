import ActivityKit
import Foundation
import TKCore
import UIKit

extension LiveActivityOperation {
    init(transactionId: String) {
        if transactionId.hasPrefix(TransactionLiveActivityLink.perpsFundingPrefix) {
            self = .perpsFunding
        } else if transactionId.hasPrefix("perps-") {
            self = .perpsTrade
        } else {
            self = .other
        }
    }

    @available(iOS 16.1, *)
    init(_ state: TransactionLiveActivityAttributes.ContentState) {
        switch (Self(transactionId: state.transactionId), state.kind) {
        case (.other, .send): self = .send
        case (.other, .receive): self = .receive
        case (.other, .swap): self = .swap
        case let (operation, _): self = operation
        }
    }
}

extension LiveActivityClick {
    /// Reads the activity at tap time: by the time the app opens the transaction, a refresh may have moved it on.
    @MainActor
    init(link: TransactionLiveActivityLink, isColdStart: Bool) {
        if #available(iOS 16.2, *),
           let state = Activity<TransactionLiveActivityAttributes>.activities.lazy
           .filter({ $0.attributes.walletId == link.walletId })
           .map(\.transactionState)
           .first(where: { $0.transactionId == link.transactionId })
        {
            self.init(
                operation: LiveActivityOperation(state),
                status: Status(rawValue: state.status.rawValue) ?? .unknown,
                isColdStart: isColdStart
            )
        } else {
            self.init(
                operation: LiveActivityOperation(transactionId: link.transactionId),
                status: .unknown,
                isColdStart: isColdStart
            )
        }
    }
}

extension LaunchApp.LiveActivities {
    @MainActor
    static var current: Self {
        guard #available(iOS 16.2, *), UIDevice.current.userInterfaceIdiom == .phone,
              !ProcessInfo.processInfo.isiOSAppOnMac
        else {
            return .unsupported
        }
        return ActivityAuthorizationInfo().areActivitiesEnabled ? .enabled : .disabled
    }
}
