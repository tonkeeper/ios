import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

extension WalletConnectValidation {
    var proposalTitleAccentColor: TKColor {
        switch self {
        case .valid:
            .accentBlue
        case .unknown:
            .accentOrange
        case .invalid, .scam:
            .accentRed
        }
    }

    var proposalActionButtonAppearance: ButtonView.Appearance {
        switch self {
        case .valid:
            .primary
        case .unknown:
            .primaryAttention
        case .invalid, .scam:
            .primaryDestructive
        }
    }

    var proposalActionDescription: String {
        switch self {
        case .valid:
            TKLocales.WalletConnect.Proposal.Validation.validDescription
        case .unknown:
            TKLocales.WalletConnect.Proposal.Validation.unknownDescription
        case .invalid:
            TKLocales.WalletConnect.Proposal.Validation.invalidDescription
        case .scam:
            TKLocales.WalletConnect.Proposal.Validation.scamDescription
        }
    }

    var proposalActionDescriptionColor: TKColor {
        switch self {
        case .valid:
            .textTertiary
        case .unknown:
            .textSecondary
        case .invalid, .scam:
            .accentRed
        }
    }

    var proposalBadge: WalletConnectProposalValidationBadge? {
        switch self {
        case .valid:
            return nil
        case .unknown:
            return WalletConnectProposalValidationBadge(
                icon: UIImage.TKUIKit.Icons.Size16.exclamationMarkCircle,
                tintColor: .accentOrange
            )
        case .invalid, .scam:
            return WalletConnectProposalValidationBadge(
                icon: UIImage.TKUIKit.Icons.Size16.exclamationmarkTriangle,
                tintColor: .accentRed
            )
        }
    }
}
