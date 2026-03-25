import BigInt
import Foundation
import TonSwift

public struct TonkeeperDeeplinkParser {
    public func parse(string: String?) throws -> Deeplink {
        guard let string else {
            throw DeeplinkParserError.unsupportedDeeplink(code: .nilValue, string: string)
        }

        guard var url = URL(string: string) else {
            throw DeeplinkParserError.unsupportedDeeplink(code: .notUrl, string: string)
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
            throw DeeplinkParserError.unsupportedDeeplink(
                code: .firstPathComponent,
                string: string
            )
        }

        switch firstPathComponent {
        case "transfer":
            return try .transfer(parseTransfer(url: url))
        case "buy-ton":
            return .buyTon
        case "staking":
            return .staking
        case "pool":
            return try .pool(parsePool(url: url))
        case "exchange":
            return .exchange(provider: parseExchange(url: url))
        case "swap":
            return .swap(parseSwap(url: url))
        case "action":
            return .action(eventId: parseAction(url: url))
        case "publish":
            return try .publish(sign: parsePublish(url: url))
        case "signer":
            return try .externalSign(parseExternalSign(url: url))
        case "ton-connect":
            return try .tonconnect(parseTonconnect(url: url))
        case "dapp":
            return try .dapp(parseDapp(url: url))
        case "battery":
            return .battery(parseBattery(url: url))
        case "browser":
            return .browser
        case "story":
            return try .story(storyId: parseStory(url: url))
        case "receive":
            return .receive
        case "backup":
            return .backup
        default:
            throw DeeplinkParserError.unsupportedDeeplink(
                code: .notSupportedPath,
                string: string
            )
        }
    }

    func parseTransfer(url: URL) throws -> Deeplink.Transfer {
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
        )

        let validQueryItems: Set<String> = ["amount", "text", "bin", "init", "jetton", "exp", "success_ret"]

        if let queryItems = components?.queryItems {
            for item in queryItems {
                if !validQueryItems.contains(item.name) {
                    throw DeeplinkParserError.unknownQueryItem(name: item.name)
                }
            }
        }

        let recipient: String = try {
            guard url.pathComponents.count > 1 else {
                throw DeeplinkParserError.invalidParameters
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
                throw DeeplinkParserError.invalidParameters
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
                expirationTimestamp: expirationTimestamp,
                successReturn: successReturn
            )
        )
    }

    func parsePool(url: URL) throws -> Address {
        try Address.parse(url.lastPathComponent)
    }

    func parseExchange(url: URL) -> String? {
        if url.pathComponents.count == 2 {
            return url.lastPathComponent
        } else {
            return nil
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

    func parseAction(url: URL) -> String {
        url.lastPathComponent
    }

    func parseTonconnect(url: URL) throws -> TonConnectPayload {
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
            returnStrategy: returnStrategy
        ), url)
    }

    func parsePublish(url: URL) throws -> Data {
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
        )

        guard let signHex = components?.queryItems?.first(where: { $0.name == "sign" })?.value,
              let signData = Data(hex: signHex)
        else {
            throw DeeplinkParserError.invalidParameters
        }

        return signData
    }

    func parseExternalSign(url: URL) throws -> ExternalSignDeeplink {
        let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: true
        )
        switch components?.path {
        case "signer/link":
            guard let pkHex = components?.queryItems?.first(where: { $0.name == "pk" })?.value,
                  let pkData = Data(hex: pkHex),
                  let name = components?.queryItems?.first(where: { $0.name == "name" })?.value
            else {
                throw DeeplinkParserError.invalidParameters
            }
            let publicKey = TonSwift.PublicKey(data: pkData)
            return ExternalSignDeeplink.link(publicKey: publicKey, name: name)
        default:
            throw DeeplinkParserError.unsupportedDeeplink(
                code: .notSupportedPath,
                string: url.absoluteString
            )
        }
    }

    private func parseDapp(url: URL) throws -> URL {
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
            throw DeeplinkParserError.unsupportedDeeplink(
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

    private func parseStory(url: URL) throws -> String {
        return try {
            guard url.pathComponents.count > 1 else {
                throw DeeplinkParserError.invalidParameters
            }
            return url.pathComponents[1]
        }()
    }
}
