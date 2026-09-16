@testable import App
import BigInt
@testable import KeeperCore
import XCTest

final class MultichainScannedTransferTests: XCTestCase {
    private let evmAddress = "0x000000000000000000000000000000000000dead"
    private let tonAddress = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"

    func test_multichainSendTransfer_carriesCandidatesWithoutAmountAndComment() {
        let candidates = MultichainRecipientCandidates(address: evmAddress, chains: [.eth, .base])

        let scanned = MultichainScannedTransfer(
            deeplink: .transfer(.multichainSendTransfer(candidates))
        )

        XCTAssertEqual(scanned?.candidates, candidates)
        XCTAssertNil(scanned?.amount)
        XCTAssertNil(scanned?.comment)
    }

    func test_sendTransfer_detectsCandidatesAndPreservesAmountAndComment() {
        let scanned = MultichainScannedTransfer(
            deeplink: .transfer(
                .sendTransfer(makeTransferData(recipient: tonAddress, amount: 42, comment: "memo"))
            )
        )

        XCTAssertEqual(
            scanned?.candidates,
            MultichainRecipientCandidates(address: tonAddress, chains: [.ton])
        )
        XCTAssertEqual(scanned?.amount, 42)
        XCTAssertEqual(scanned?.comment, "memo")
    }

    /// The send screen switches to the pinned asset and then applies this recipient unchanged, so
    /// the candidates must already be narrowed to the asset's chain.
    func test_sendTransfer_pinnedAssetNarrowsCandidatesToItsChain() {
        let scanned = MultichainScannedTransfer(
            deeplink: .transfer(
                .sendTransfer(
                    makeTransferData(
                        recipient: evmAddress,
                        amount: 7,
                        comment: nil,
                        assetId: "base/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7"
                    )
                )
            )
        )

        XCTAssertEqual(
            scanned?.candidates,
            MultichainRecipientCandidates(address: evmAddress, chains: [.base])
        )
        XCTAssertEqual(scanned?.assetId, "base/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7")
        XCTAssertEqual(scanned?.amount, 7)
    }

    func test_sendTransfer_pinnedAssetOnRecipientChain_keepsCandidates() {
        let scanned = MultichainScannedTransfer(
            deeplink: .transfer(
                .sendTransfer(
                    makeTransferData(
                        recipient: tonAddress,
                        amount: 42,
                        comment: "memo",
                        assetId: "ton/mainnet/coin"
                    )
                )
            )
        )

        XCTAssertEqual(
            scanned?.candidates,
            MultichainRecipientCandidates(address: tonAddress, chains: [.ton])
        )
        XCTAssertEqual(scanned?.assetId, "ton/mainnet/coin")
        XCTAssertEqual(scanned?.amount, 42)
        XCTAssertEqual(scanned?.comment, "memo")
    }

    /// An asset the address cannot receive is dropped, and the amount goes with it — it was
    /// denominated in that asset, not in whatever the send screen has selected.
    func test_sendTransfer_pinnedAssetOnForeignChain_dropsAssetAndAmount() {
        let scanned = MultichainScannedTransfer(
            deeplink: .transfer(
                .sendTransfer(
                    makeTransferData(
                        recipient: tonAddress,
                        amount: 42,
                        comment: "memo",
                        assetId: "base/mainnet/coin"
                    )
                )
            )
        )

        XCTAssertEqual(
            scanned?.candidates,
            MultichainRecipientCandidates(address: tonAddress, chains: [.ton])
        )
        XCTAssertNil(scanned?.assetId)
        XCTAssertNil(scanned?.amount)
        XCTAssertEqual(scanned?.comment, "memo")
    }

    func test_sendTransfer_malformedAssetId_dropsAssetAndAmount() {
        let scanned = MultichainScannedTransfer(
            deeplink: .transfer(
                .sendTransfer(
                    makeTransferData(
                        recipient: tonAddress,
                        amount: 42,
                        comment: nil,
                        assetId: "definitely-not-an-asset"
                    )
                )
            )
        )

        XCTAssertNil(scanned?.assetId)
        XCTAssertNil(scanned?.amount)
    }

    func test_sendTransfer_undetectableRecipient_returnsNil() {
        let scanned = MultichainScannedTransfer(
            deeplink: .transfer(
                .sendTransfer(makeTransferData(recipient: "not-an-address", amount: nil, comment: nil))
            )
        )

        XCTAssertNil(scanned)
    }

    func test_evmSendTransfer_pinnedChain_narrowsCandidatesAndPinsAsset() {
        let scanned = MultichainScannedTransfer(
            deeplink: .transfer(
                .evmSendTransfer(
                    Deeplink.EvmTransferData(
                        recipient: evmAddress,
                        asset: .erc20(contract: "0xDAC17F958D2ee523a2206206994597C13D831ec7"),
                        chain: .base,
                        amount: 7
                    )
                )
            )
        )

        XCTAssertEqual(
            scanned?.candidates,
            MultichainRecipientCandidates(address: evmAddress, chains: [.base])
        )
        XCTAssertEqual(scanned?.amount, 7)
        XCTAssertEqual(scanned?.assetId, "base/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7")
    }

    func test_evmSendTransfer_pinnedNativeChain_pinsCoinAsset() {
        let scanned = MultichainScannedTransfer(
            deeplink: .transfer(
                .evmSendTransfer(
                    Deeplink.EvmTransferData(
                        recipient: evmAddress,
                        asset: .native,
                        chain: .eth,
                        amount: 9
                    )
                )
            )
        )

        XCTAssertEqual(scanned?.assetId, "eth/mainnet/coin")
        XCTAssertEqual(scanned?.amount, 9)
    }

    /// Without a chain the token behind the contract is unknown, so the amount must not be applied
    /// to whatever asset the send screen happens to have selected.
    func test_evmSendTransfer_withoutChain_dropsAmountAndAsset() {
        let scanned = MultichainScannedTransfer(
            deeplink: .transfer(
                .evmSendTransfer(
                    Deeplink.EvmTransferData(
                        recipient: evmAddress,
                        asset: .erc20(contract: "0xdac17f958d2ee523a2206206994597c13d831ec7"),
                        chain: nil,
                        amount: 7
                    )
                )
            )
        )

        XCTAssertNil(scanned?.amount)
        XCTAssertNil(scanned?.assetId)
        XCTAssertEqual(scanned?.candidates.address, evmAddress)
    }

    func test_evmSendTransfer_undetectableRecipient_returnsNil() {
        let scanned = MultichainScannedTransfer(
            deeplink: .transfer(
                .evmSendTransfer(
                    Deeplink.EvmTransferData(
                        recipient: "not-an-address",
                        asset: .native,
                        chain: .eth,
                        amount: nil
                    )
                )
            )
        )

        XCTAssertNil(scanned)
    }

    func test_signRawTransfer_returnsNil() {
        let scanned = MultichainScannedTransfer(
            deeplink: .transfer(
                .signRawTransfer(
                    Deeplink.RawTransferData(
                        recipient: tonAddress,
                        amount: nil,
                        jettonAddress: nil,
                        bin: nil,
                        stateInit: nil,
                        expirationTimestamp: nil
                    )
                )
            )
        )

        XCTAssertNil(scanned)
    }

    func test_nonTransferDeeplink_returnsNil() {
        XCTAssertNil(MultichainScannedTransfer(deeplink: .staking))
    }
}

private extension MultichainScannedTransferTests {
    func makeTransferData(
        recipient: String,
        amount: BigUInt?,
        comment: String?,
        assetId: String? = nil
    ) -> Deeplink.TransferData {
        Deeplink.TransferData(
            recipient: recipient,
            amount: amount,
            comment: comment,
            jettonAddress: nil,
            assetId: assetId,
            expirationTimestamp: nil,
            successReturn: nil
        )
    }
}
