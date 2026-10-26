@testable import App
import BigInt
import Foundation
@testable import KeeperCore
import TonSwift
import TonTransport
import XCTest

final class LedgerKnownJettonResolverTests: XCTestCase {
    private let usdtWallet = try! Address.parse(raw: "0:" + String(repeating: "1a", count: 32))
    private let otherWallet = try! Address.parse(raw: "0:" + String(repeating: "2b", count: 32))
    private let unknownMaster = JettonMasterAddress.HMSTR

    func testResolvesJettonIdFromTheWalletsJettonBalances() {
        let balances = [
            makeBalance(master: unknownMaster, walletAddress: otherWallet),
            makeBalance(master: JettonMasterAddress.tonUSDT, walletAddress: usdtWallet),
        ]

        let known = LedgerKnownJettonResolver.knownJetton(
            for: makeTransaction(destination: usdtWallet, jettonTransfer: true),
            jettonBalances: balances,
            ownerWorkchain: 0
        )

        XCTAssertEqual(known, KnownJetton(jettonId: 0, workchain: 0))
    }

    func testUnknownMasterIsNotResolved() {
        let known = LedgerKnownJettonResolver.knownJetton(
            for: makeTransaction(destination: otherWallet, jettonTransfer: true),
            jettonBalances: [makeBalance(master: unknownMaster, walletAddress: otherWallet)],
            ownerWorkchain: 0
        )

        XCTAssertNil(known)
    }

    func testDestinationOutsideTheBalancesIsNotResolved() {
        let known = LedgerKnownJettonResolver.knownJetton(
            for: makeTransaction(destination: otherWallet, jettonTransfer: true),
            jettonBalances: [
                makeBalance(master: JettonMasterAddress.tonUSDT, walletAddress: usdtWallet),
                makeBalance(master: JettonMasterAddress.tonUSDT, walletAddress: nil),
            ],
            ownerWorkchain: 0
        )

        XCTAssertNil(known)
    }

    func testNonJettonPayloadToAJettonWalletIsNotResolved() {
        let known = LedgerKnownJettonResolver.knownJetton(
            for: makeTransaction(destination: usdtWallet, jettonTransfer: false),
            jettonBalances: [makeBalance(master: JettonMasterAddress.tonUSDT, walletAddress: usdtWallet)],
            ownerWorkchain: 0
        )

        XCTAssertNil(known)
    }

    private func makeBalance(master: Address, walletAddress: Address?) -> JettonBalance {
        JettonBalance(
            item: JettonItem(
                jettonInfo: JettonInfo(
                    isTransferable: true,
                    hasCustomPayload: false,
                    address: master,
                    fractionDigits: 6,
                    name: "Jetton",
                    symbol: "JET",
                    verification: .whitelist,
                    imageURL: nil
                ),
                walletAddress: walletAddress
            ),
            quantity: 1,
            rates: [:]
        )
    }

    private func makeTransaction(destination: Address, jettonTransfer: Bool) -> Transaction {
        let payload: TonPayloadFormat = jettonTransfer
            ? .jettonTransfer(TonPayloadFormat.JettonTransfer(
                queryId: nil,
                coins: Coins(rawValue: 1)!,
                receiverAddress: otherWallet,
                excessesAddress: otherWallet,
                customPayload: nil,
                forwardAmount: Coins(rawValue: 0)!,
                forwardPayload: nil
            ))
            : .comment("hi")
        return Transaction(
            destination: destination,
            sendMode: .walletDefault(),
            seqno: 1,
            timeout: 1_700_000_000,
            bounceable: true,
            coins: Coins(rawValue: 0)!,
            stateInit: nil,
            payload: payload
        )
    }
}
