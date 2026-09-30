@preconcurrency import AnyCodable
import BigInt
import Foundation
import KeeperCore
import SwiftUI
import TKCore
import TKLocalize
import TKUIKit
import UIKit

private indirect enum WalletConnectRequestDetailJSONValue {
    case object([(String, WalletConnectRequestDetailJSONValue)])
    case array([WalletConnectRequestDetailJSONValue])
    case primitive(String)
}

struct WalletConnectRequestAssembly {
    private init() {}

    @MainActor
    static func module(
        request: WalletConnectSessionRequest,
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly
    ) -> MVVMModule<
        WalletConnectRequestHostingViewController,
        WalletConnectRequestModuleOutput,
        Void
    > {
        let content = makeContent(
            request: request,
            wallet: wallet,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )
        let viewModel = WalletConnectRequestViewModel(content: content)
        let viewController = WalletConnectRequestHostingViewController(
            requestId: request.id,
            topic: request.topic,
            viewModel: viewModel
        )
        return .init(view: viewController, output: viewModel, input: ())
    }
}

private extension WalletConnectRequestAssembly {
    static func makeContent(
        request: WalletConnectSessionRequest,
        wallet: Wallet,
        amountFormatter: AmountFormatter
    ) -> WalletConnectRequestContent {
        let chain = request.chain
        let dappHost = dappHost(for: request.dapp)
        let dappName = request.dapp.name.isEmpty ? dappHost : request.dapp.name
        let requestSummary = summaryRow(
            request: request,
            amountFormatter: amountFormatter
        )
        var rows: [WalletConnectRequestInfoRow] = [
            WalletConnectRequestInfoRow(
                id: .wallet,
                title: TKLocales.WalletConnect.Request.Rows.wallet,
                value: attributed(wallet.label),
                subtitle: nil,
                valueIcon: .TKUIKit.Icons.Size16.wallet,
                trailingIcon: nil,
                trailingIconColor: .iconTertiary
            ),
            WalletConnectRequestInfoRow(
                id: .app,
                title: TKLocales.WalletConnect.Request.Rows.app,
                value: attributed(dappHost, color: .Accent.blue),
                subtitle: nil,
                valueIcon: nil,
                trailingIcon: nil,
                trailingIconColor: .iconTertiary
            ),
            WalletConnectRequestInfoRow(
                id: .network,
                title: TKLocales.WalletConnect.Request.Rows.network,
                value: attributed(chain.multichainChain.shortDisplayTitle),
                subtitle: chain.standard,
                valueIcon: nil,
                trailingIcon: nil,
                trailingIconColor: .iconTertiary
            ),
            requestSummary.row,
        ]

        if let feeRow = feeRow(
            request: request,
            amountFormatter: amountFormatter
        ) {
            rows.append(feeRow)
        }

        return WalletConnectRequestContent(
            dappName: dappName,
            dappHost: dappHost,
            dappURL: dappURL(for: request.dapp),
            dappIconURL: request.dapp.iconURL.flatMap(URL.init(string:)),
            description: TKLocales.WalletConnect.Request.confirmAction,
            headline: headline(
                action: requestSummary.headlineAction,
                chainTitle: chain.multichainChain.shortDisplayTitle
            ),
            chainIcon: chain.multichainChain.tokenIcon44,
            rows: rows,
            advancedDetails: detailItems(for: request)
        )
    }

    static func summaryRow(
        request: WalletConnectSessionRequest,
        amountFormatter: AmountFormatter
    ) -> (headlineAction: String, row: WalletConnectRequestInfoRow) {
        switch request.payload {
        case let .signMessage(message):
            return (
                TKLocales.WalletConnect.Request.Actions.signMessage,
                WalletConnectRequestInfoRow(
                    id: .request,
                    title: TKLocales.WalletConnect.Request.Rows.request,
                    value: attributed(message.kind.title),
                    subtitle: message.address.map { TKLocales.WalletConnect.Request.Rows.address(shortAddress($0)) },
                    valueIcon: nil,
                    trailingIcon: nil,
                    trailingIconColor: .iconTertiary
                )
            )
        case let .evmTransaction(transaction, send):
            let amount = nativeAmountText(
                transaction.value,
                chain: request.chain,
                amountFormatter: amountFormatter
            )
            let amountValue = bigUInt(hexOrDecimal: transaction.value) ?? 0
            let hasCalldata = !transaction.data.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && transaction.data.trimmingCharacters(in: .whitespacesAndNewlines) != "0x"
            let headlineAction: String
            if send, !hasCalldata, amountValue > 0 {
                headlineAction = TKLocales.WalletConnect.Request.Actions.transfer(request.chain.nativeTokenSymbol)
            } else if send {
                headlineAction = TKLocales.WalletConnect.Request.Actions.sendTransaction
            } else {
                headlineAction = TKLocales.WalletConnect.Request.Actions.signTransaction
            }

            return (
                headlineAction,
                WalletConnectRequestInfoRow(
                    id: .request,
                    title: TKLocales.WalletConnect.Request.Rows.amount,
                    value: attributed(amount),
                    subtitle: transaction.to.map { TKLocales.WalletConnect.Request.Rows.to(shortAddress($0)) },
                    valueIcon: nil,
                    trailingIcon: nil,
                    trailingIconColor: .iconTertiary
                )
            )
        case let .tronTransaction(transaction):
            return (
                TKLocales.WalletConnect.Request.Actions.signTransaction,
                WalletConnectRequestInfoRow(
                    id: .request,
                    title: TKLocales.WalletConnect.Request.Rows.request,
                    value: attributed(TKLocales.WalletConnect.Request.Values.tronTransaction),
                    subtitle: transaction.txID.map {
                        TKLocales.WalletConnect.Request.Rows.transactionId(shortAddress($0))
                    },
                    valueIcon: nil,
                    trailingIcon: nil,
                    trailingIconColor: .iconTertiary
                )
            )
        case let .tonSendMessage(message):
            return (
                TKLocales.WalletConnect.Request.Actions.sendTransaction,
                WalletConnectRequestInfoRow(
                    id: .request,
                    title: TKLocales.WalletConnect.Request.Rows.request,
                    value: attributed(WalletConnectMethod.tonSendMessage.rawValue),
                    subtitle: "\(message.messagesCount) messages",
                    valueIcon: nil,
                    trailingIcon: nil,
                    trailingIconColor: .iconTertiary
                )
            )
        case let .tonSignData(signData):
            return (
                TKLocales.WalletConnect.Request.Actions.signMessage,
                WalletConnectRequestInfoRow(
                    id: .request,
                    title: TKLocales.WalletConnect.Request.Rows.request,
                    value: attributed(WalletConnectMethod.tonSignData.rawValue),
                    subtitle: signData.address.map { TKLocales.WalletConnect.Request.Rows.address(shortAddress($0)) },
                    valueIcon: nil,
                    trailingIcon: nil,
                    trailingIconColor: .iconTertiary
                )
            )
        case let .switchEthereumChain(chain):
            return (
                TKLocales.WalletConnect.Request.confirmAction,
                WalletConnectRequestInfoRow(
                    id: .request,
                    title: TKLocales.WalletConnect.Request.Rows.request,
                    value: attributed(chain.caip2),
                    subtitle: nil,
                    valueIcon: nil,
                    trailingIcon: nil,
                    trailingIconColor: .iconTertiary
                )
            )
        case .walletCapabilities:
            return (
                TKLocales.WalletConnect.Request.confirmAction,
                WalletConnectRequestInfoRow(
                    id: .request,
                    title: TKLocales.WalletConnect.Request.Rows.request,
                    value: attributed(WalletConnectMethod.walletGetCapabilities.rawValue),
                    subtitle: nil,
                    valueIcon: nil,
                    trailingIcon: nil,
                    trailingIconColor: .iconTertiary
                )
            )
        }
    }

    static func feeRow(
        request: WalletConnectSessionRequest,
        amountFormatter: AmountFormatter
    ) -> WalletConnectRequestInfoRow? {
        guard case let .evmTransaction(transaction, _) = request.payload,
              let gasLimit = transaction.gas.flatMap(bigUInt(hexOrDecimal:)),
              gasLimit > 0
        else {
            return nil
        }

        let gasPrice = transaction.gasPrice.flatMap(bigUInt(hexOrDecimal:))
        let maxFeePerGas = transaction.maxFeePerGas.flatMap(bigUInt(hexOrDecimal:))
        let price = request.chain.supportsEip1559Fees
            ? maxFeePerGas ?? gasPrice
            : gasPrice
        guard let price, price > 0 else {
            return nil
        }

        let amount = gasLimit * price
        let formatted = amountFormatter.format(
            amount: amount,
            fractionDigits: request.chain.nativeTokenFractionDigits,
            accessory: .tokenSymbol(request.chain.nativeTokenSymbol),
            style: .compact
        )

        return WalletConnectRequestInfoRow(
            id: .fee,
            title: TKLocales.WalletConnect.Request.Rows.networkFee,
            value: attributed(TKLocales.WalletConnect.Request.Rows.approximateValue(formatted)),
            subtitle: TKLocales.WalletConnect.Request.Rows.providedByDapp,
            valueIcon: nil,
            trailingIcon: nil,
            trailingIconColor: .accentBlue
        )
    }

    static func detailItems(for request: WalletConnectSessionRequest) -> [WalletConnectRequestDetailItem] {
        switch request.payload {
        case let .signMessage(message):
            switch message.kind {
            case .typedDataV4:
                return [rawDataItem(fromJSONString: message.message)].compactMap { $0 }
            case .personal, .tron:
                return [detail(TKLocales.WalletConnect.Request.Details.message, message.message)].compactMap { $0 }
            }

        case let .evmTransaction(transaction, _):
            return [
                detailItem(
                    title: TKLocales.WalletConnect.Request.Details.rawData,
                    value: evmTransactionJSON(transaction),
                    path: ["rawData"],
                    depth: 0
                ),
            ].compactMap { $0 }

        case let .tronTransaction(transaction):
            return [
                detailItem(
                    title: TKLocales.WalletConnect.Request.Details.rawData,
                    value: jsonValue(from: transaction.transactionJSON.value),
                    path: ["rawData"],
                    depth: 0
                ),
                detail(TKLocales.WalletConnect.Request.Details.rawDataHex, transaction.rawDataHex),
            ].compactMap { $0 }

        case let .tonSendMessage(message):
            return [rawDataItem(fromJSONString: message.rawParamsJSON)].compactMap { $0 }

        case let .tonSignData(signData):
            return [rawDataItem(fromJSONString: signData.rawParamsJSON)].compactMap { $0 }

        case let .switchEthereumChain(chain):
            return [
                detail(TKLocales.WalletConnect.Request.Details.rawData, chain.caip2),
            ].compactMap { $0 }

        case let .walletCapabilities(capabilities):
            return [
                detail(TKLocales.WalletConnect.Request.Details.rawData, capabilities.chainIds.joined(separator: ", ")),
            ].compactMap { $0 }
        }
    }

    static func detail(_ title: String, _ value: String?) -> WalletConnectRequestDetailItem? {
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return WalletConnectRequestDetailItem(
            id: title,
            title: title,
            value: .primitive(value),
            isDefaultExpanded: false
        )
    }

    static func rawDataItem(fromJSONString string: String) -> WalletConnectRequestDetailItem? {
        guard let value = jsonValue(fromJSONString: string) else {
            return detail(TKLocales.WalletConnect.Request.Details.rawData, string)
        }

        return detailItem(
            title: TKLocales.WalletConnect.Request.Details.rawData,
            value: value,
            path: ["rawData"],
            depth: 0
        )
    }

    static func evmTransactionJSON(_ transaction: WalletConnectEVMTransaction) -> WalletConnectRequestDetailJSONValue {
        .object(
            [
                ("from", transaction.from),
                ("to", transaction.to),
                ("value", transaction.value),
                ("data", transaction.data),
                ("gas", transaction.gas),
                ("gasPrice", transaction.gasPrice),
                ("maxFeePerGas", transaction.maxFeePerGas),
                ("maxPriorityFeePerGas", transaction.maxPriorityFeePerGas),
                ("nonce", transaction.nonce),
            ].compactMap { field in
                let (key, value) = field
                guard let value,
                      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    return nil
                }
                return (key, .primitive(value))
            }
        )
    }

    static func detailItem(
        title: String,
        value: WalletConnectRequestDetailJSONValue,
        path: [String],
        depth: Int
    ) -> WalletConnectRequestDetailItem? {
        let id = path.joined(separator: ".")

        switch value {
        case let .primitive(value):
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return WalletConnectRequestDetailItem(
                id: id,
                title: title,
                value: .primitive(value),
                isDefaultExpanded: false
            )

        case let .object(members):
            let children = members.compactMap { member in
                let (key, value) = member
                return detailItem(
                    title: formattedDetailTitle(key),
                    value: value,
                    path: path + [key],
                    depth: depth + 1
                )
            }

            guard !children.isEmpty else {
                return WalletConnectRequestDetailItem(
                    id: id,
                    title: title,
                    value: .primitive("{}"),
                    isDefaultExpanded: false
                )
            }

            return WalletConnectRequestDetailItem(
                id: id,
                title: title,
                value: .collection(children),
                isDefaultExpanded: isDefaultExpandedDetail(path: path, depth: depth)
            )

        case let .array(values):
            let children = values.enumerated().compactMap { index, value in
                detailItem(
                    title: "[\(index)]",
                    value: value,
                    path: path + ["[\(index)]"],
                    depth: depth + 1
                )
            }

            guard !children.isEmpty else {
                return WalletConnectRequestDetailItem(
                    id: id,
                    title: title,
                    value: .primitive("[]"),
                    isDefaultExpanded: false
                )
            }

            return WalletConnectRequestDetailItem(
                id: id,
                title: title,
                value: .collection(children),
                isDefaultExpanded: isDefaultExpandedDetail(path: path, depth: depth)
            )
        }
    }

    static func isDefaultExpandedDetail(path: [String], depth: Int) -> Bool {
        depth == 0 || path.last == "message"
    }

    static func jsonValue(fromJSONString string: String) -> WalletConnectRequestDetailJSONValue? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(
                  with: data,
                  options: [.fragmentsAllowed]
              )
        else {
            return nil
        }

        return jsonValue(from: object)
    }

    static func jsonValue(from value: Any) -> WalletConnectRequestDetailJSONValue {
        switch value {
        case let value as AnyCodable:
            return jsonValue(from: value.value)

        case let value as [String: AnyCodable]:
            return jsonValue(
                from: value.mapValues(\.value)
            )

        case let value as [AnyCodable]:
            return .array(value.map { jsonValue(from: $0.value) })

        case let value as [String: Any]:
            return .object(
                value
                    .sorted(by: compareDetailKeys)
                    .map { member in
                        let (key, value) = member
                        return (key, jsonValue(from: value))
                    }
            )

        case let value as [Any]:
            return .array(value.map { jsonValue(from: $0) })

        case let value as String:
            return .primitive(value)

        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return .primitive(value.boolValue ? "true" : "false")
            }
            return .primitive(value.stringValue)

        case _ as NSNull:
            return .primitive("null")

        default:
            return .primitive(String(describing: value))
        }
    }

    static func compareDetailKeys(
        _ lhs: Dictionary<String, Any>.Element,
        _ rhs: Dictionary<String, Any>.Element
    ) -> Bool {
        let lhsRank = detailKeyRank(lhs.key)
        let rhsRank = detailKeyRank(rhs.key)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
    }

    static func detailKeyRank(_ key: String) -> Int {
        switch key {
        case "primaryType":
            0
        case "types":
            1
        case "domain":
            2
        case "message":
            3
        case "from":
            4
        case "to":
            5
        case "content":
            6
        case "value":
            7
        case "data":
            8
        case "gas":
            9
        case "gasPrice":
            10
        case "maxFeePerGas":
            11
        case "maxPriorityFeePerGas":
            12
        case "nonce":
            13
        default:
            100
        }
    }

    static func formattedDetailTitle(_ key: String) -> String {
        guard !key.isEmpty else { return key }
        if key.first == "[", key.last == "]" {
            return key
        }

        let normalized = key.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let characters = Array(normalized)
        var words = [String]()
        var current = ""

        for index in characters.indices {
            let character = characters[index]
            if character == " " {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
                continue
            }

            if !current.isEmpty,
               character.isUppercase,
               index > characters.startIndex
            {
                let previous = characters[characters.index(before: index)]
                if previous.isLowercase || previous.isNumber {
                    words.append(current)
                    current = ""
                }
            }

            current.append(character)
        }

        if !current.isEmpty {
            words.append(current)
        }

        let title = words
            .enumerated()
            .map { index, word in
                index == 0 ? word.capitalized : word.lowercased()
            }
            .joined(separator: " ")
        return title.isEmpty ? key : title
    }

    static func headline(
        action: String,
        chainTitle: String
    ) -> AttributedString {
        var result = attributed("\(action) ")
        result += attributed(chainTitle, color: .Text.secondary)
        return result
    }

    static func attributed(
        _ string: String,
        color: UIColor = .Text.primary
    ) -> AttributedString {
        var value = AttributedString(string)
        value.foregroundColor = Color(uiColor: color)
        return value
    }

    static func nativeAmountText(
        _ value: String,
        chain: WalletConnectChain,
        amountFormatter: AmountFormatter
    ) -> String {
        guard let amount = bigUInt(hexOrDecimal: value) else {
            return value
        }
        return amountFormatter.format(
            amount: amount,
            fractionDigits: chain.nativeTokenFractionDigits,
            accessory: .tokenSymbol(chain.nativeTokenSymbol),
            style: .regular
        )
    }

    static func bigUInt(hexOrDecimal string: String) -> BigUInt? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasPrefix("0x") {
            return BigUInt(String(trimmed.dropFirst(2)), radix: 16)
        }
        return BigUInt(trimmed, radix: 10)
    }

    static func dappHost(for dapp: WalletConnectDapp) -> String {
        guard !dapp.url.isEmpty else {
            return dapp.name.isEmpty ? TKLocales.WalletConnect.Common.dapp : dapp.name
        }
        return URL(string: dapp.url)?.host ?? dapp.url
    }

    static func dappURL(for dapp: WalletConnectDapp) -> URL? {
        let urlString = dapp.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else { return nil }

        if let url = URL(string: urlString),
           url.scheme != nil
        {
            return url
        }

        if urlString.hasPrefix("//") {
            return URL(string: "https:\(urlString)")
        }

        return URL(string: "https://\(urlString)")
    }

    static func shortAddress(_ address: String) -> String {
        guard address.count > 14 else { return address }
        return "\(address.prefix(4))...\(address.suffix(4))"
    }
}

private extension WalletConnectSignMessageKind {
    var title: String {
        switch self {
        case .personal:
            TKLocales.WalletConnect.Request.Signature.personal
        case .typedDataV4:
            TKLocales.WalletConnect.Request.Signature.typedData
        case .tron:
            TKLocales.WalletConnect.Request.Signature.tronMessage
        }
    }
}

private extension WalletConnectChain {
    var standard: String {
        switch self {
        case .ton:
            "TON"
        case .eth:
            "ERC20"
        case .base:
            "Base"
        case .arb:
            "Arbitrum"
        case .bsc:
            "BEP20"
        case .tron:
            "TRC20"
        }
    }

    var nativeTokenSymbol: String {
        switch self {
        case .ton:
            "TON"
        case .eth, .base, .arb:
            "ETH"
        case .bsc:
            "BNB"
        case .tron:
            "TRX"
        }
    }

    var nativeTokenFractionDigits: Int {
        switch self {
        case .ton:
            9
        case .eth, .base, .arb, .bsc:
            18
        case .tron:
            6
        }
    }
}
