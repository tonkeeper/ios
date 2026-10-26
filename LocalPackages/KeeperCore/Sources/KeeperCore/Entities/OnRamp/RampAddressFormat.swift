import ChainKit
import Foundation

enum RampAddressFormat {
    case ton
    case tron
    case evm
    case solana
    case near

    init?(assetId: String) {
        guard let components = AssetIdComponents(assetId: assetId) else {
            return nil
        }
        switch components.chain.lowercased() {
        case "ton":
            self = .ton
        case "tron":
            self = .tron
        case "eth", "bsc", "arb", "op", "polygon", "base", "avax", "robinhood":
            self = .evm
        case "sol":
            self = .solana
        case "near":
            self = .near
        default:
            return nil
        }
    }

    func recipient(fromQRCode qrCode: String) -> String? {
        let payload = qrCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let recipient = linkRecipient(in: payload) ?? payload.droppingAmountOnlyQuery() else {
            return nil
        }
        return isValid(recipient) ? recipient : nil
    }
}

private extension RampAddressFormat {
    func linkRecipient(in payload: String) -> String? {
        switch self {
        case .evm:
            EthereumTransferLinkParser().recipient(string: payload)
        case .solana:
            pathRecipient(in: payload, prefix: "solana:")
        case .ton:
            pathRecipient(in: payload, prefix: "ton://transfer/")
        case .tron, .near:
            nil
        }
    }

    func pathRecipient(in payload: String, prefix: String) -> String? {
        guard payload.lowercased().hasPrefix(prefix) else {
            return nil
        }
        return String(payload.dropFirst(prefix.count).prefix { $0 != "?" })
    }

    func isValid(_ address: String) -> Bool {
        switch self {
        case .ton:
            isValid(address, coin: .ton)
        case .tron:
            isValid(address, coin: .tron)
        case .evm:
            isValid(address, coin: .ethereum)
        case .solana:
            isValid(address, coin: .solana)
        case .near:
            isNearAccountId(address)
        }
    }

    func isValid(_ address: String, coin: Wallet_core_kotlinCoinType) -> Bool {
        Wallet_core_kotlinAnyAddress.Companion.shared.isValid(string: address, coin: coin)
    }

    func isNearAccountId(_ string: String) -> Bool {
        guard (2 ... 64).contains(string.count) else {
            return false
        }
        return string.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
            label.split(omittingEmptySubsequences: false) { $0 == "-" || $0 == "_" }.allSatisfy { part in
                !part.isEmpty && part.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber) }
            }
        }
    }
}
