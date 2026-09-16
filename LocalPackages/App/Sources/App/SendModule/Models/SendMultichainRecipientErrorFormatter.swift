import KeeperCore
import TKLocalize

enum SendMultichainRecipientErrorFormatter {
    static func invalidAddressDescription(selectedChain: MultichainChain?) -> String {
        guard let selectedChain else {
            return TKLocales.Send.invalidAddress
        }
        // Native coins can have identical network and token type titles.
        let network = selectedChain.shortDisplayTitle
        let label = network == selectedChain.tokenType ? network : "\(network) (\(selectedChain.tokenType))"
        return TKLocales.Send.invalidAddressForNetwork(label)
    }
}
