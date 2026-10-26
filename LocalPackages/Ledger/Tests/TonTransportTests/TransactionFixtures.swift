import BigInt
import TonSwift
@testable import TonTransport

enum TransactionFixtures {
    static let jettonWallet = try! Address.parse(raw: "0:" + String(repeating: "1a", count: 32))
    static let receiver = try! Address.parse(raw: "0:" + String(repeating: "2b", count: 32))
    static let excesses = try! Address.parse("EQCxE6mUtQJKFnGfaROTKOt1lZbDiiX1kCixRv7Nw2Id_sDs")

    static func jettonTransfer(queryId: BigUInt? = nil, knownJetton: KnownJetton? = nil) -> Transaction {
        Transaction(
            destination: jettonWallet,
            sendMode: .walletDefault(),
            seqno: 7,
            timeout: 1_700_000_000,
            bounceable: true,
            coins: Coins(rawValue: 0)!,
            stateInit: nil,
            payload: .jettonTransfer(TonPayloadFormat.JettonTransfer(
                queryId: queryId,
                coins: Coins(rawValue: 1_000_000)!,
                receiverAddress: receiver,
                excessesAddress: excesses,
                customPayload: nil,
                forwardAmount: Coins(rawValue: 0)!,
                forwardPayload: nil,
                knownJetton: knownJetton
            ))
        )
    }

    static func comment(_ text: String) -> Transaction {
        Transaction(
            destination: receiver,
            sendMode: .walletDefault(),
            seqno: 7,
            timeout: 1_700_000_000,
            bounceable: true,
            coins: Coins(rawValue: 0)!,
            stateInit: nil,
            payload: .comment(text)
        )
    }
}
