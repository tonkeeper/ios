import KeeperCore
import TKLocalize
import TKUIKit
import UIKit

public extension WalletContractVersion {
    var tag: String? {
        switch self {
        case .v5Beta:
            "W5 BETA"
        case .v5R1:
            "W5"
        default: nil
        }
    }
}

public extension Wallet {
    var kindTag: String? {
        switch kind {
        case .regular:
            switch network {
            case .testnet: return "TESTNET"
            case .tetra: return "TETRA"
            case .mainnet: return nil
            }
        case .lockup:
            return nil
        case .watchonly:
            return TKLocales.WalletTags.watchOnly
        case .signer:
            return "SIGNER"
        case .ledger:
            return "LEDGER"
        case .keystone:
            return "KEYSTONE"
        }
    }

    var revisionTag: String? {
        try? contractVersion.tag
    }
}

public extension Wallet {
    func copyToastConfiguration() -> ToastPresenter.Configuration {
        let backgroundColor: UIColor
        let foregroundColor: UIColor

        switch kind {
        case .regular:
            if network == .mainnet {
                backgroundColor = .Background.contentTint
                foregroundColor = .Text.primary
            } else {
                backgroundColor = .Accent.orange
                foregroundColor = .Text.primary
            }
        case .lockup:
            backgroundColor = .Background.contentTint
            foregroundColor = .Text.primary
        case .watchonly:
            backgroundColor = .Accent.orange
            foregroundColor = .Text.primary
        default:
            backgroundColor = .Background.contentTint
            foregroundColor = .Text.primary
        }

        return ToastPresenter.Configuration(
            title: TKLocales.Toast.copied,
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            dismissRule: .default
        )
    }

    func balanceTagConfigurations() -> [TKTagView.Configuration] {
        [revisionTagConfiguration(), balanceKindTagConfiguration()].compactMap { $0 }
    }

    func listTagConfigurations() -> [TKTagView.Configuration] {
        [revisionTagConfiguration(), listTagConfiguration()].compactMap { $0 }
    }

    func balanceKindTagConfiguration() -> TKTagView.Configuration? {
        let color: UIColor? = {
            switch kind {
            case .regular:
                network == .mainnet ? nil : .Accent.orange
            case .lockup:
                nil
            case .watchonly:
                .Accent.orange
            case .signer:
                .Accent.purple
            case .ledger:
                .Accent.green
            case .keystone:
                .Accent.purple
            }
        }()
        guard let kindTag, let color else { return nil }
        return .accentTag(text: kindTag, color: color)
    }

    func revisionTagConfiguration() -> TKTagView.Configuration? {
        guard let revisionTag else { return nil }
        return .accentTag(text: revisionTag, color: .Accent.green)
    }

    func receiveTagConfiguration() -> TKTagView.Configuration? {
        guard let tag = kindTag else { return nil }

        let textColor: UIColor
        let backgroundColor: UIColor

        switch kind {
        case .regular:
            if network == .mainnet {
                return nil
            }
            textColor = .black
            backgroundColor = .Accent.orange
        case .lockup:
            return nil
        case .watchonly:
            textColor = .black
            backgroundColor = .Accent.orange
        case .signer:
            textColor = .Accent.purple
            backgroundColor = .Accent.purple.withAlphaComponent(0.16)
        case .ledger:
            textColor = .Accent.purple
            backgroundColor = .Accent.purple.withAlphaComponent(0.16)
        case .keystone:
            textColor = .Accent.purple
            backgroundColor = .Accent.purple.withAlphaComponent(0.16)
        }

        return TKTagView.Configuration(
            text: tag,
            textColor: textColor,
            textPadding: UIEdgeInsets(top: 2.5, left: 5, bottom: 3.5, right: 5),
            backgroundColor: backgroundColor,
            borderColor: .clear,
            backgroundPadding: UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
        )
    }

    func listTagConfiguration() -> TKTagView.Configuration? {
        guard let tag = kindTag else { return nil }
        return TKTagView.Configuration.tag(text: tag)
    }
}
