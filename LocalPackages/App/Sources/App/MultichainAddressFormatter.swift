import Foundation
import KeeperCore
import TonSwift

enum MultichainAddressFormatter {
    static func fullAddress(_ address: String, chain: MultichainChain) -> String {
        guard chain == .ton else {
            return address
        }

        return tonNonBounceableAddress(address) ?? address
    }

    static func shortAddress(_ address: String, chain: MultichainChain) -> String {
        let address = fullAddress(address, chain: chain)
        guard address.count > Constants.shortAddressLength else {
            return address
        }
        return "\(address.prefix(Constants.shortAddressPrefixLength))...\(address.suffix(Constants.shortAddressSuffixLength))"
    }
}

private extension MultichainAddressFormatter {
    enum Constants {
        static let shortAddressLength = 14
        static let shortAddressPrefixLength = 4
        static let shortAddressSuffixLength = 4
    }

    static func tonNonBounceableAddress(_ value: String) -> String? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }

        if let friendlyAddress = try? FriendlyAddress(string: value) {
            return friendlyAddress.address.toString(
                testOnly: friendlyAddress.isTestOnly,
                bounceable: false
            )
        }

        if let address = try? Address.parse(raw: value) {
            return address.toString(
                testOnly: false,
                bounceable: false
            )
        }

        if let address = try? Address.parse(value) {
            return address.toString(
                testOnly: false,
                bounceable: false
            )
        }

        return nil
    }
}
