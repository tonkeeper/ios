import BigInt
import Foundation
import KeeperCoreComponents
import TonSwift

struct TonkeeperDeeplinkParser {
    private let walletConnectDeeplinkValidator: WalletConnectDeeplinkValidator

    init(walletConnectDeeplinkValidator: WalletConnectDeeplinkValidator) {
        self.walletConnectDeeplinkValidator = walletConnectDeeplinkValidator
    }

    func parse(
        string: String?,
        tonConnectSource: DappConnectionSource = .deeplink
    ) throws(DeeplinkParserError) -> Deeplink {
        guard let string else {
            throw .unsupportedDeeplink(code: .nilValue, string: string)
        }

        if string.isEmpty {
            return .main
        }

        guard var url = URL(string: string) else {
            throw .unsupportedDeeplink(code: .notUrl, string: string)
        }

        if let cleaned = string.removingPercentEncoding,
           let cleanedURL = URL(string: cleaned)
        {
            url = cleanedURL
        }

        if let secondCleaned = string.removingPercentEncoding?.removingPercentEncoding,
           let secondCleanedURL = URL(string: secondCleaned)
        {
            url = secondCleanedURL
        }

        guard let firstPathComponent = url.pathComponents.first else {
            throw .unsupportedDeeplink(
                code: .firstPathComponent,
                string: string
            )
        }

        switch firstPathComponent {
        case "transfer":
            return try .transfer(parseTransfer(url: url))
        case "staking":
            return .staking
        case "pool":
            return try .pool(parsePool(url: url))
        case "swap":
            return .swap(parseSwap(url: url))
        case "deposit":
            return .deposit(parseRamp(url: url))
        case "withdraw":
            return .withdraw(parseRamp(url: url))
        case "action":
            return .action(eventId: parseAction(url: url))
        case "publish":
            return try .publish(sign: parsePublish(url: url))
        case "signer":
            return try .externalSign(parseExternalSign(url: url))
        case "ton-connect":
            return try .tonconnect(
                parseTonconnect(
                    url: url,
                    source: tonConnectSource
                )
            )
        case "wc":
            return try .walletConnect(parseWalletConnect(url: url))
        case "dapp":
            return try .dapp(parseDapp(url: url))
        case "battery":
            return .battery(parseBattery(url: url))
        case "browser":
            return .browser(network: parseBrowserNetwork(url: url))
        // Raffle CTAs and tasks come from the backend as `migrate`; universal links use `migration`.
        case "migration", "migrate":
            return .migration
        case "trading":
            return .trading(gridID: parseTradingGridID(url: url))
        case "assets":
            return try .tradeAsset(assetID: parseTradeAssetID(url: url))
        case "story":
            return try .story(storyId: parseStory(url: url))
        case "receive":
            return .receive
        case "backup":
            return .backup
        case "add-wallet":
            return .addWallet
        case "main":
            return .main
        case "raffle":
            switch url.pathComponents.count {
            case 1:
                return .raffle
            case 2 where url.pathComponents[1] == "mystery_raffle":
                return .raffle
            default:
                throw .unsupportedDeeplink(code: .notSupportedPath, string: string)
            }
        default:
            throw .unsupportedDeeplink(
                code: .notSupportedPath,
                string: string
            )
        }
    }

    func parseTransfer(url: URL) throws(DeeplinkParserError) -> Deeplink.Transfer {
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
        )

        let validQueryItems = Set<String>([
            "amount",
            "text",
            "bin",
            "init",
            "jetton",
            "asset_id",
            "exp",
            "success_ret",
        ]).union(UtmParameters.queryItemNames)

        if let queryItems = components?.queryItems {
            for item in queryItems {
                if !validQueryItems.contains(item.name) {
                    throw .unknownQueryItem(name: item.name)
                }
            }
        }

        let recipient: String = try { () throws(DeeplinkParserError) in
            guard url.pathComponents.count > 1 else {
                throw .invalidParameters
            }
            return url.pathComponents[1]
        }()

        let amount: BigUInt? = {
            guard let amountParameter = components?.queryItems?.first(where: { $0.name == "amount" })?.value else {
                return nil
            }
            return BigUInt(amountParameter)
        }()

        let comment: String? = components?.queryItems?.first(where: { $0.name == "text" })?.value

        let bin: String? = components?.queryItems?.first(where: { $0.name == "bin" })?.value

        let stateInit: String? = components?.queryItems?.first(where: { $0.name == "init" })?.value?.replacingOccurrences(of: "\\", with: "")

        let jettonAddress: Address? = {
            guard let jettonAddressParameter = components?.queryItems?.first(where: { $0.name == "jetton" })?.value else {
                return nil
            }
            return try? Address.parse(jettonAddressParameter)
        }()

        let assetId: String? = {
            guard let value = components?.queryItems?.first(where: { $0.name == "asset_id" })?.value else {
                return nil
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()

        let expirationTimestamp: Int64? = {
            guard let exp = components?.queryItems?.first(where: { $0.name == "exp" })?.value else {
                return nil
            }
            return Int64(exp)
        }()

        let successReturn: URL? = {
            guard let urlString = components?.queryItems?.first(where: { $0.name == "success_ret" })?.value,
                  let url = URL(string: urlString)
            else {
                return nil
            }
            return url
        }()

        if bin != nil || stateInit != nil {
            if comment != nil && bin != nil {
                throw .invalidParameters
            }
            let bin: String? = {
                if let bin {
                    return bin
                }

                if let comment {
                    let text = Data(comment.utf8)
                    return try? Builder().store(int: 0, bits: 32).writeSnakeData(text).endCell().toBoc().base64EncodedString()
                }

                return nil
            }()
            return .signRawTransfer(.init(recipient: recipient, amount: amount, jettonAddress: jettonAddress, bin: bin, stateInit: stateInit, expirationTimestamp: expirationTimestamp))
        }

        return .sendTransfer(
            Deeplink.TransferData(
                recipient: recipient,
                amount: amount,
                comment: comment,
                jettonAddress: jettonAddress,
                assetId: assetId,
                expirationTimestamp: expirationTimestamp,
                successReturn: successReturn
            )
        )
    }

    func parsePool(url: URL) throws(DeeplinkParserError) -> Address {
        do {
            return try Address.parse(url.lastPathComponent)
        } catch {
            throw .invalidParameters
        }
    }

    func parseSwap(url: URL) -> Deeplink.SwapData {
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
        )
        let fromToken = components?.queryItems?.first(where: { $0.name == "ft" })?.value
        let toToken = components?.queryItems?.first(where: { $0.name == "tt" })?.value
        return Deeplink.SwapData(
            fromToken: fromToken,
            toToken: toToken
        )
    }

    func parseRamp(url: URL) -> RampDeeplinkParameters {
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
        )

        let fromToken = components?.queryItems?.first(where: { $0.name == "ft" })?.value
        let toToken = components?.queryItems?.first(where: { $0.name == "tt" })?.value
        let toNetwork = components?.queryItems?.first(where: { $0.name == "tn" })?.value
        let fromNetwork = components?.queryItems?.first(where: { $0.name == "fn" })?.value
        let cashMethod = components?.queryItems?.first(where: { $0.name == "cm" })?.value
        let itemType = components?.queryItems?.first(where: { $0.name == "it" })?.value
            .flatMap { OnRampLayoutItemType(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }

        return RampDeeplinkParameters(
            fromToken: fromToken,
            toToken: toToken,
            toNetwork: toNetwork,
            fromNetwork: fromNetwork,
            cashMethod: cashMethod,
            itemType: itemType
        )
    }

    func parseAction(url: URL) -> String {
        url.lastPathComponent
    }

    func parseTonconnect(
        url: URL,
        source: DappConnectionSource = .deeplink
    ) throws(DeeplinkParserError) -> TonConnectPayload {
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
        )

        let returnStrategy = components?.queryItems?.first(where: { $0.name == "ret" })?.value

        guard let versionParameter = components?.queryItems?.first(where: { $0.name == "v" })?.value,
              let version = TonConnectParameters.Version(rawValue: versionParameter),
              let clientId = components?.queryItems?.first(where: { $0.name == "id" })?.value,
              let requestPayloadValue = components?.queryItems?.first(where: { $0.name == "r" })?.value,
              let requestPayloadData = requestPayloadValue.data(using: .utf8),
              let requestPayload = try? JSONDecoder().decode(TonConnectRequestPayload.self, from: requestPayloadData)
        else {
            return .empty
        }

        return .withParameters(TonConnectParameters(
            version: version,
            clientId: clientId,
            requestPayload: requestPayload,
            returnStrategy: returnStrategy,
            source: source
        ), url)
    }

    func parseWalletConnect(url: URL) throws(DeeplinkParserError) -> WalletConnectDeeplink {
        guard let wrappedURI = WalletConnectURIParser.wrappedURI(from: url.absoluteString) else {
            throw .ignoredWalletConnectWakeUp
        }

        let uri = WalletConnectURIParser.normalized(wrappedURI)
        guard walletConnectDeeplinkValidator.isPairingURI(uri) else {
            if WalletConnectURIParser.wakeUpTopic(from: uri) != nil {
                throw .ignoredWalletConnectWakeUp
            }
            throw .invalidParameters
        }

        return WalletConnectDeeplink(
            uri: uri,
            source: .deeplink
        )
    }

    func parsePublish(url: URL) throws(DeeplinkParserError) -> Data {
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
        )

        guard let signHex = components?.queryItems?.first(where: { $0.name == "sign" })?.value,
              let signData = Data(strictHex: signHex)
        else {
            throw .invalidParameters
        }

        return signData
    }

    func parseExternalSign(url: URL) throws(DeeplinkParserError) -> ExternalSignDeeplink {
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
        )
        switch components?.path {
        case "signer/link":
            guard let pkHex = components?.queryItems?.first(where: { $0.name == "pk" })?.value,
                  let pkData = Data(strictHex: pkHex),
                  let name = components?.queryItems?.first(where: { $0.name == "name" })?.value
            else {
                throw .invalidParameters
            }
            let publicKey = TonSwift.PublicKey(data: pkData)
            return ExternalSignDeeplink.link(publicKey: publicKey, name: name)
        default:
            throw .unsupportedDeeplink(
                code: .notSupportedPath,
                string: url.absoluteString
            )
        }
    }

    private func parseDapp(url: URL) throws(DeeplinkParserError) -> URL {
        let dappPrefix = "dapp/"
        var stringURL = url
            .absoluteString
            .removingPercentEncoding ?? url.absoluteString

        if stringURL.hasPrefix(dappPrefix) {
            stringURL = String(stringURL.dropFirst(dappPrefix.count))
        }

        let httpsPrefix = "https://"
        if !stringURL.hasPrefix(httpsPrefix) {
            stringURL = "\(httpsPrefix)\(stringURL)"
        }

        let components = URLComponents(string: "\(stringURL)")

        guard let resultURL = components?.url else {
            throw .unsupportedDeeplink(
                code: .notUrl,
                string: url.absoluteString
            )
        }

        return resultURL
    }

    private func parseBattery(url: URL) -> Deeplink.Battery {
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
        )

        let promocode = components?.queryItems?.first(where: { $0.name == "promocode" })?.value
        let masterJettonAddress: Address? = {
            guard let jettonValue = components?.queryItems?.first(where: { $0.name == "jetton" })?.value else {
                return nil
            }
            return try? Address.parse(jettonValue)
        }()

        return Deeplink.Battery(
            promocode: promocode,
            masterJettonAddress: masterJettonAddress
        )
    }

    private func parseStory(url: URL) throws(DeeplinkParserError) -> String {
        return try { () throws(DeeplinkParserError) in
            guard url.pathComponents.count > 1 else {
                throw .invalidParameters
            }
            return url.pathComponents[1]
        }()
    }

    private func parseBrowserNetwork(url: URL) -> MultichainChain? {
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
        )
        guard let value = components?.queryItems?.first(where: { $0.name == "network" })?.value else {
            return nil
        }
        return MultichainChain(assetIdChain: value)
    }

    private func parseTradingGridID(url: URL) -> String? {
        guard url.pathComponents.count > 1 else {
            return nil
        }
        return url.pathComponents[1]
    }

    private func parseTradeAssetID(url: URL) throws(DeeplinkParserError) -> String {
        let assetID = url.pathComponents
            .dropFirst()
            .joined(separator: "/")
        guard !assetID.isEmpty else {
            throw .invalidParameters
        }
        return assetID
    }
}
