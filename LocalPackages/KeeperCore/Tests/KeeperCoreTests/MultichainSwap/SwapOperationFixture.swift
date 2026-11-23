@preconcurrency import ChainKit
import Foundation
import HTTPTypes
@testable import KeeperCore
import OpenAPIRuntime
import SwapAPI
import XCTest

/// The swap backend as the app reaches it, answering every request with what a test hands it and
/// keeping what it was asked.
actor SwapBackend: ClientTransport {
    private var answers: [(status: HTTPResponse.Status, body: Data)]
    private(set) var paths = [String]()
    /// The last request and its body.
    private(set) var request: HTTPRequest?
    private(set) var body: Data?

    /// One answer per request, in their order: the last one answers every later request.
    init(answers: [(status: HTTPResponse.Status, body: Data)]) {
        self.answers = answers
    }

    init(answering bodies: Data...) {
        self.init(answers: bodies.map { (.ok, $0) })
    }

    nonisolated var api: MultichainSwapAPI {
        MultichainSwapAPIImplementation(
            swapAPIClient: SwapAPI.Client(serverURL: URL(string: "https://swap.tonkeeper.com")!, transport: self),
            firebaseUserIdProvider: { nil }
        )
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL _: URL,
        operationID _: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        paths.append(request.path ?? "")
        self.request = request
        self.body = nil
        if let body {
            self.body = try await Data(collecting: body, upTo: .max)
        }
        guard let answer = answers.first else {
            throw SwapBackendError.unanswered(request.path ?? "")
        }
        if answers.count > 1 {
            answers.removeFirst()
        }
        return (HTTPResponse(status: answer.status, headerFields: [.contentType: "application/json"]), HTTPBody(answer.body))
    }
}

enum SwapBackendError: Error {
    case unanswered(String)
}

/// Android #860's recorded `/v3` responses, kept in `responses` as `confirm_v3_{prepare,quote}_<swap>`.
enum SwapFixture {
    static func data(_ name: String) throws -> Data {
        try Data(XCTUnwrap(responses[name], "no recorded answer \(name)").utf8)
    }

    /// The recorded prepare of `swap`, edited in place from the inside out: its last payload's meta,
    /// that payload, the operation, the human summary and the response itself.
    static func prepare(
        _ swap: String,
        root: (inout [String: Any]) -> Void = { _ in },
        summary: (inout [String: Any]) -> Void = { _ in },
        operation: (inout [String: Any]) -> Void = { _ in },
        payload: (inout [String: Any]) -> Void = { _ in },
        meta: (inout [String: Any]) -> Void = { _ in }
    ) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data("confirm_v3_prepare_\(swap)")) as? [String: Any])
        var recorded = try XCTUnwrap(json["operation"] as? [String: Any])
        var payloads = try XCTUnwrap(recorded["payloads"] as? [[String: Any]])
        var last = try XCTUnwrap(payloads.last)
        var lastMeta = try XCTUnwrap(last["meta"] as? [String: Any])
        meta(&lastMeta)
        last["meta"] = lastMeta
        payload(&last)
        payloads[payloads.count - 1] = last
        recorded["payloads"] = payloads
        operation(&recorded)
        json["operation"] = recorded
        var humanSummary = try XCTUnwrap(json["human_summary"] as? [String: Any])
        summary(&humanSummary)
        json["human_summary"] = humanSummary
        root(&json)
        return try JSONSerialization.data(withJSONObject: json)
    }
}

/// chain-kit, the keychain and the chain as a swap `/v3` prepared reaches them: answered here, and
/// kept in the order they were reached.
actor RecordedSwapOperationSteps: MultichainSwapOperationSteps {
    enum Step: Equatable {
        case price(payload: String, address: String, asset: String)
        case defaultPrice(payload: String, address: String, asset: String)
        case cover(amount: String, fee: String, address: String, asset: String)
        case unlock
        /// The operation's id and its payloads, the address, asset and key of the account it is signed
        /// from, the fees, each the very one priced, and the deadline it is sent by.
        case send(operation: String, payloads: [String], address: String, asset: String, key: String?, fees: [ObjectIdentifier], expiresAt: Date)
    }

    static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    private(set) var steps = [Step]()
    /// What each payload was priced at, by its id.
    private(set) var priced = [String: ObjectIdentifier]()
    private let price: @Sendable (Payload, ChainKit.Account) throws(MultichainSwapExecutionFailure) -> any Fee
    private let defaultPrice: @Sendable (Payload, ChainKit.Account) throws(MultichainSwapExecutionFailure) -> any Fee
    private let coinCovers: Bool
    private let sendFailure: MultichainSwapExecutionFailure?
    private let onUnlock: @Sendable () async -> Void

    /// The backend's fee where a payload states one, else 21000 units of the chain's coin; 180850818600000
    /// units at the chain's default.
    init(
        price: @escaping @Sendable (Payload, ChainKit.Account) throws(MultichainSwapExecutionFailure) -> any Fee = { payload, account in
            payload.fee ?? FeeValue(asset: account.chain.toAsset(), amount: BignumBigInteger(long: 21000))
        },
        defaultPrice: @escaping @Sendable (Payload, ChainKit.Account) throws(MultichainSwapExecutionFailure) -> any Fee = { _, account in
            FeeValue(asset: account.chain.toAsset(), amount: BignumBigInteger(long: 180_850_818_600_000))
        },
        coinCovers: Bool = true,
        sendFailure: MultichainSwapExecutionFailure? = nil,
        onUnlock: @escaping @Sendable () async -> Void = {}
    ) {
        self.price = price
        self.defaultPrice = defaultPrice
        self.coinCovers = coinCovers
        self.sendFailure = sendFailure
        self.onUnlock = onUnlock
    }

    nonisolated static func unlocked() throws -> MnemonicWallet {
        try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: mnemonic)
    }

    func fee(of payload: Payload, account: ChainKit.Account) async throws(MultichainSwapExecutionFailure) -> any Fee {
        steps.append(.price(payload: payload.id, address: account.addressDisplay.lowercased(), asset: account.asset.id))
        return try keep(price(payload, account), for: payload)
    }

    func defaultFee(of payload: Payload, account: ChainKit.Account) async throws(MultichainSwapExecutionFailure) -> any Fee {
        steps.append(.defaultPrice(payload: payload.id, address: account.addressDisplay.lowercased(), asset: account.asset.id))
        return try keep(defaultPrice(payload, account), for: payload)
    }

    func covers(_ amount: BignumBigInteger, and fee: any Fee, from account: ChainKit.Account) async throws(MultichainSwapExecutionFailure) -> Bool {
        steps.append(.cover(amount: amount.description, fee: fee.amount.description, address: account.addressDisplay.lowercased(), asset: account.asset.id))
        return coinCovers
    }

    func details(of asset: any ChainKit.Asset, wallet _: Wallet) async -> MultichainAssetDetails {
        MultichainAssetDetails(assetId: asset.id, name: asset.name, symbol: asset.symbol, decimals: Int(asset.decimals.value), image: "")
    }

    func unlock(
        passcodeProvider: @escaping () async -> String?,
        swapWallet _: MultichainSwapWallet
    ) async throws(MultichainSwapExecutionFailure) -> MnemonicWallet {
        guard await passcodeProvider() != nil else {
            throw .canceled
        }
        steps.append(.unlock)
        await onUnlock()
        do {
            return try Self.unlocked()
        } catch {
            throw .internal(reason: "the test mnemonic does not derive a wallet: \(error)")
        }
    }

    func send(
        _ operation: ChainKit.Operation,
        account: ChainKit.Account,
        wallet _: MnemonicWallet,
        expiresAt: Date,
        fees: [any Fee]
    ) async throws(MultichainSwapExecutionFailure) -> [String] {
        // As the sender's deadline check before each payload: a swap the screen's closing cancelled sends nothing.
        guard !Task.isCancelled else {
            throw .canceled
        }
        steps.append(.send(
            operation: operation.id,
            payloads: operation.payloads.map(\.id),
            address: account.addressDisplay.lowercased(),
            asset: account.asset.id,
            key: account.publicKey?.defaultHex,
            fees: fees.map { ObjectIdentifier($0 as AnyObject) },
            expiresAt: expiresAt
        ))
        if let sendFailure {
            throw sendFailure
        }
        return operation.payloads.map { "0x\($0.id)" }
    }

    private func keep(_ fee: any Fee, for payload: Payload) -> any Fee {
        priced[payload.id] = ObjectIdentifier(fee as AnyObject)
        return fee
    }
}
