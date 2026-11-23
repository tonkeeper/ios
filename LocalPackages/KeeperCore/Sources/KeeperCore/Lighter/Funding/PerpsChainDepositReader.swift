import BigInt
import Foundation
import TKLogging

enum PerpsChainDepositReader {
    static let depositErc20Selector = "e8017952"
    static let depositNativeSelector = "49290c1c"
    static let transferAndMulticallSelector = "f9e4bab4"

    private static let transferAndMulticallHeadWords = 6
    private static let wordBytes: BigUInt = 32
    private static let maxShortfallBps: BigUInt = 100
    private static let routerMaxShortfallBps: BigUInt = 300

    static func fitsBudget(_ sent: BigUInt, budget: BigUInt, maxShortfallBps: BigUInt = maxShortfallBps) -> Bool {
        sent > 0 && sent <= budget && sent * 10000 >= budget * (10000 - maxShortfallBps)
    }

    static func readRelay(
        _ quote: PerpsDepositQuote,
        budget: BigUInt,
        security: PerpsSecurityConfig?
    ) throws(PerpsDepositQuoteError) -> BigUInt {
        guard quote.sourceAsset.raw.lowercased() != PerpsFundingAssetId.usdcEthereum else {
            throw refusal("relay source")
        }
        let depositories = security?.relayEVMDepositories[quote.sourceAsset.chain.rawValue] ?? []
        let routers = security?.relayRouters[quote.sourceAsset.chain.rawValue] ?? [:]
        guard !depositories.isEmpty || !routers.isEmpty else { throw refusal("relay depository") }
        let (approval, payment) = try split(evmCalls(of: quote.payloads))
        let sender = quote.sender.lowercased()
        let target = payment.to.lowercased()
        switch quote.sourceAsset.kind {
        case .coin:
            guard approval == nil else { throw refusal("calls") }
            let shortfall: BigUInt
            if depositories.contains(target) {
                try readNativeDeposit(payment, depositor: sender)
                shortfall = maxShortfallBps
            } else if routers[target] == .erc20Router {
                shortfall = routerMaxShortfallBps
            } else {
                throw refusal("relay target")
            }
            guard let value = BigUInt(payment.valueUnits, radix: 10), fitsBudget(value, budget: budget, maxShortfallBps: shortfall) else {
                throw refusal("value")
            }
            return value
        case let .token(token):
            guard BigUInt(payment.valueUnits, radix: 10) == 0, target != token.lowercased() else {
                throw refusal("relay payment")
            }
            var allowance: BigUInt?
            if let approval {
                allowance = try readApproval(approval, token: token, spender: target, budget: budget)
            }
            if depositories.contains(target) {
                return try readTokenDeposit(payment, depositor: sender, token: token, budget: budget)
            }
            switch routers[target] {
            case .approvalProxy:
                return try readApprovalProxyTransfer(payment, token: token, budget: budget, allowance: allowance)
            case .erc20Router, .relayReceiver:
                guard let allowance else { throw refusal("approve") }
                return allowance
            case nil:
                throw refusal("relay target")
            }
        }
    }

    static func readTron(
        _ quote: PerpsDepositQuote,
        budget: BigUInt,
        security: PerpsSecurityConfig?
    ) throws(PerpsDepositQuoteError) -> BigUInt {
        guard quote.provider == .relay else { throw refusal("provider") }
        guard let depositories = security?.relayTronDepositories, !depositories.isEmpty else {
            throw refusal("relay depository")
        }
        guard quote.payloads.allSatisfy({ $0.kind == .main || $0.kind == .approval }) else {
            throw refusal("payloads")
        }
        let (approval, payment) = try split(quote.payloads)
        let depository = PerpsDepositCalldata.normalizedAddress(payment.to)
        guard depositories.contains(where: { PerpsDepositCalldata.normalizedAddress($0) == depository }) else {
            throw refusal("relay target")
        }
        let sender = PerpsDepositCalldata.normalizedAddress(quote.sender)
        switch quote.sourceAsset.kind {
        case .coin:
            guard approval == nil else { throw refusal("calls") }
            try readNativeDeposit(payment, depositor: sender)
            guard let value = BigUInt(payment.valueUnits, radix: 10), fitsBudget(value, budget: budget) else {
                throw refusal("value")
            }
            return value
        case let .token(token):
            guard BigUInt(payment.valueUnits, radix: 10) == 0 else { throw refusal("relay payment") }
            if let approval {
                _ = try readApproval(approval, token: token, spender: payment.to, budget: budget)
            }
            return try readTokenDeposit(payment, depositor: sender, token: token, budget: budget)
        }
    }

    private static func evmCalls(of payloads: [PerpsDepositQuotePayload]) throws(PerpsDepositQuoteError) -> [PerpsDepositQuotePayload] {
        var calls = [PerpsDepositQuotePayload]()
        for payload in payloads {
            switch payload.kind {
            case .approval, .main:
                calls.append(payload)
            case .batch:
                do {
                    calls += try PerpsDepositCalldata.readBatch(payload)
                } catch {
                    throw refusal("batch")
                }
            case .prebuilt:
                throw refusal("payloads")
            }
        }
        return calls
    }

    private static func split(
        _ calls: [PerpsDepositQuotePayload]
    ) throws(PerpsDepositQuoteError) -> (approval: PerpsDepositQuotePayload?, payment: PerpsDepositQuotePayload) {
        switch calls.count {
        case 1: (nil, calls[0])
        case 2: (calls[0], calls[1])
        default: throw refusal("calls")
        }
    }

    private static func readApproval(
        _ approval: PerpsDepositQuotePayload,
        token: String,
        spender: String,
        budget: BigUInt
    ) throws(PerpsDepositQuoteError) -> BigUInt {
        do {
            return try PerpsDepositCalldata.readApproval(approval, token: token, spender: spender, amountUnits: budget, exactAmount: false).amountUnits
        } catch {
            throw refusal("approve")
        }
    }

    private static func readNativeDeposit(_ payment: PerpsDepositQuotePayload, depositor: String) throws(PerpsDepositQuoteError) {
        guard let call = try? PerpsDepositCalldata.call(of: payment), call.selector == depositNativeSelector, call.arguments.count == 2 else {
            throw refusal("deposit")
        }
        guard PerpsDepositCalldata.address(word: call.arguments[0]) == depositor else { throw refusal("depositor") }
    }

    private static func readTokenDeposit(
        _ payment: PerpsDepositQuotePayload,
        depositor: String,
        token: String,
        budget: BigUInt
    ) throws(PerpsDepositQuoteError) -> BigUInt {
        guard let call = try? PerpsDepositCalldata.call(of: payment), call.selector == depositErc20Selector, call.arguments.count == 4 else {
            throw refusal("deposit")
        }
        guard PerpsDepositCalldata.address(word: call.arguments[0]) == depositor else { throw refusal("depositor") }
        guard PerpsDepositCalldata.address(word: call.arguments[1]) == PerpsDepositCalldata.normalizedAddress(token) else {
            throw refusal("token")
        }
        guard let sent = BigUInt(call.arguments[2], radix: 16), fitsBudget(sent, budget: budget) else { throw refusal("amount") }
        return sent
    }

    private static func readApprovalProxyTransfer(
        _ payment: PerpsDepositQuotePayload,
        token: String,
        budget: BigUInt,
        allowance: BigUInt?
    ) throws(PerpsDepositQuoteError) -> BigUInt {
        guard let call = try? PerpsDepositCalldata.call(of: payment), call.selector == transferAndMulticallSelector,
              call.arguments.count >= transferAndMulticallHeadWords,
              let tokens = arrayArgument(call.arguments, at: 0),
              let amounts = arrayArgument(call.arguments, at: 1)
        else {
            throw refusal("approval proxy call")
        }
        guard tokens.count == 1, amounts.count == 1,
              PerpsDepositCalldata.address(word: tokens[0]) == PerpsDepositCalldata.normalizedAddress(token),
              let transferred = BigUInt(amounts[0], radix: 16),
              fitsBudget(transferred, budget: budget, maxShortfallBps: routerMaxShortfallBps),
              allowance.map({ $0 >= transferred }) ?? true
        else {
            throw refusal("approval proxy transfer")
        }
        return transferred
    }

    private static func arrayArgument(_ words: [String], at index: Int) -> [String]? {
        guard let offset = BigUInt(words[index], radix: 16), offset % wordBytes == 0,
              let lengthIndex = Int(exactly: offset / wordBytes), lengthIndex < words.count,
              let length = BigUInt(words[lengthIndex], radix: 16).flatMap({ Int(exactly: $0) }),
              length <= words.count - lengthIndex - 1
        else { return nil }
        return Array(words[(lengthIndex + 1) ..< (lengthIndex + 1 + length)])
    }

    private static func refusal(_ field: String) -> PerpsDepositQuoteError {
        Log.perps.w("Deposit from an EVM chain or Tron refused: \(field)")
        return .unexpectedChainPayment(field)
    }
}
