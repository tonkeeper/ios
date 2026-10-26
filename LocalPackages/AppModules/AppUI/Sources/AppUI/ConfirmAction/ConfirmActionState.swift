import SwiftUI
import TKUIKit
import UIKit

/// Everything the "Confirm Action" screen renders: a transfer, a stake, a Perps trade or
/// funding. The owner builds it from its domain model; the view draws it and reports taps.
public struct ConfirmActionState {
    public enum Header {
        case avatar(AssetAvatarViewImageSource, shape: AssetAvatarView.Shape = .circle)
        /// Stands in for an icon the asset does not have.
        case letter(String)
        case custom(AnyView)
    }

    public struct Notice {
        public let text: String
        public let isError: Bool
        public let isWarning: Bool

        public init(text: String, isError: Bool = false, isWarning: Bool = false) {
            self.text = text
            self.isError = isError
            self.isWarning = isWarning
        }
    }

    public var header: Header
    public var caption: String?
    public var title: String?
    /// Shown after the title in tertiary: the network the asset lives on.
    public var titleSuffix: String?
    public var rows: [ConfirmActionRow]
    public var notice: Notice?
    public var footer: AnyView?
    public var action: ConfirmActionBarState

    public init(
        header: Header,
        caption: String?,
        title: String?,
        titleSuffix: String? = nil,
        rows: [ConfirmActionRow],
        notice: Notice? = nil,
        footer: AnyView? = nil,
        action: ConfirmActionBarState
    ) {
        self.header = header
        self.caption = caption
        self.title = title
        self.titleSuffix = titleSuffix
        self.rows = rows
        self.notice = notice
        self.footer = footer
        self.action = action
    }
}

public struct ConfirmActionRow: Identifiable {
    public enum Tone: Equatable {
        case primary, positive, negative, tertiary, accent
    }

    public struct Part: Equatable {
        public let text: String
        public let tone: Tone

        public init(text: String, tone: Tone) {
            self.text = text
            self.tone = tone
        }
    }

    public enum Value {
        case text(String, subtitle: String? = nil, tone: Tone = .primary)
        /// One line in several tones, e.g. "$120 → $95".
        case parts([Part], subtitle: String? = nil)
        case wallet(name: String, emoji: String?, icon: UIImage?)
        /// A fee paid in `token`, which the user can switch when `showsPicker`.
        case feeOption(String, token: String?, showsPicker: Bool)
        case unavailable(String, retryTitle: String, retry: () -> Void)
        case loading
    }

    public enum Interaction {
        case none
        case tap(() -> Void, showsChevron: Bool = false)
        /// Shows the full value in a tooltip, for one the row had to shorten.
        case hint(String)
    }

    public let id: String
    public let title: String
    public let value: Value
    public let interaction: Interaction
    public let titleHint: String?
    public let isEnabled: Bool

    public init(
        id: String,
        title: String,
        value: Value,
        interaction: Interaction = .none,
        titleHint: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.interaction = interaction
        self.titleHint = titleHint
        self.isEnabled = isEnabled
    }
}

public struct ConfirmActionBarState {
    public enum Kind: Equatable {
        case slider(title: String, subtitle: String)
        case button(title: String)
    }

    public enum Process: Equatable {
        case idle, processing, success, failed
    }

    public var kind: Kind
    public var isEnabled: Bool
    public var process: Process
    public var successTitle: String
    public var failureTitle: String
    public var accessibilityIdentifier: String
    /// A change springs a swiped slider back, for a confirmation that ended without leaving the screen.
    public var resetToken: Int
    public var onConfirm: () -> Void

    public init(
        kind: Kind,
        isEnabled: Bool,
        process: Process = .idle,
        successTitle: String,
        failureTitle: String,
        accessibilityIdentifier: String = "confirm_swipe",
        resetToken: Int = 0,
        onConfirm: @escaping () -> Void
    ) {
        self.kind = kind
        self.isEnabled = isEnabled
        self.process = process
        self.successTitle = successTitle
        self.failureTitle = failureTitle
        self.accessibilityIdentifier = accessibilityIdentifier
        self.resetToken = resetToken
        self.onConfirm = onConfirm
    }
}
