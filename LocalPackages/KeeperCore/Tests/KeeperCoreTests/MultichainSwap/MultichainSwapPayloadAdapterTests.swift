import BigInt
import ChainKit
import Foundation
@testable import KeeperCore
import TonSwift
import XCTest

final class MultichainSwapPayloadAdapterTests: XCTestCase {
    private let adapter = MultichainSwapPayloadAdapter()

    func test_evmPayload_parsesJsonTextAndProviderGasFee() throws {
        let normalized = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x2a","data":"0xabcd","gas":"0x64","gasPrice":"0x2"}"#
            )
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "42")
        XCTAssertEqual(try normalized.transaction.to.display, "0x1111111111111111111111111111111111111111")
        XCTAssertEqual(try normalized.transaction.data, "0xabcd")
        XCTAssertFalse(try normalized.transaction.isMax)
        let fee = try XCTUnwrap(normalized.fee as? FeeGas)
        XCTAssertEqual(fee.limit.description, "100")
        XCTAssertEqual(fee.price.description, "2")
        XCTAssertEqual(fee.amount.description, "200")
    }

    func test_evmPayload_withoutGasKeepsFeeNil() throws {
        let normalized = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x1","data":"0x"}"#
            )
        )

        XCTAssertNil(normalized.fee)
    }

    func test_evmApprovalPayload_extractsApprovalDataAndProviderFee() throws {
        let normalized = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "approval",
                payloadType: "evm_approval_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x0","data":"0x095ea7b3","gas":"0x64","gasPrice":"0x2"}"#
            )
        )

        XCTAssertNil(try normalized.transaction.data)
        XCTAssertEqual(normalized.approvalData, "0x095ea7b3")
        let fee = try XCTUnwrap(normalized.fee as? FeeGas)
        XCTAssertEqual(fee.limit.description, "100")
        XCTAssertEqual(fee.amount.description, "200")
    }

    /// A swaps.xyz EVM leg goes out as a deposit transfer — no route calldata — priced with the
    /// gas the provider quoted.
    func test_evmPayload_swapXyz_buildsDepositTransferWithProviderGasFee() throws {
        let normalized = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"5039792842855559","data":"0x","gas":"0x64","gasPrice":"0x2"}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "eth/mainnet/coin",
                    spendAmount: "5039792842855559",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: "0x1111111111111111111111111111111111111111"
                )
            ),
            provider: .swapXyz
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "5039792842855559")
        XCTAssertNil(try normalized.transaction.data)
        let fee = try XCTUnwrap(normalized.fee as? FeeGas)
        XCTAssertEqual(fee.limit.description, "100")
        XCTAssertEqual(fee.price.description, "2")
    }

    /// Route calldata carries the sell amount, so it cannot ride a `flex` payload whose amount may
    /// still be trimmed: the swap is refused instead of going out with the calldata dropped.
    func test_evmPayload_withRouteCalldata_isRejectedAsAFlexSwap() {
        XCTAssertThrowsError(
            try normalize(
                sourceChain: .eth,
                payload: makePayload(
                    kind: "main",
                    payloadType: "evm_tx",
                    payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x2a","data":"0xabcd"}"#,
                    calldataPayloadType: .flex
                )
            )
        ) { error in
            guard case .invalidPayload = error as? MultichainSwapExecutionFailure else {
                return XCTFail("Expected invalidPayload, got \(error)")
            }
        }
    }

    /// An Ethereum route with calldata is relayable as the call it is: the router, the coin sent
    /// along with it, the calldata.
    func test_evmPayload_withRouteCalldata_isRelayableAsTheRoutesCall() throws {
        let normalized = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x2a","data":"0xabcd"}"#
            )
        )

        guard case let .evm(relay)? = normalized.batteryPayload else {
            return XCTFail("expected a relayable evm payload, got \(String(describing: normalized.batteryPayload))")
        }
        XCTAssertEqual(relay.chain, .eth)
        XCTAssertEqual(relay.call.kind, .swap)
        XCTAssertEqual(relay.call.chainId, "eth/mainnet")
        XCTAssertEqual(relay.call.sender, address(for: .eth))
        XCTAssertEqual(relay.call.to, "0x1111111111111111111111111111111111111111")
        XCTAssertEqual(relay.call.value, 42)
        XCTAssertEqual(relay.call.data, "0xabcd")
    }

    /// A sold token leaves the wallet inside the calldata: the call carries no coin, and the relay
    /// does not guess at the amount — what the route says it spends is weighed by the fee engine.
    func test_evmTokenPayload_withRouteCalldata_isRelayedAsTheCallAlone() throws {
        let usdt = MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: "eth/mainnet/erc20/0xdac17f958d2ee523a2206206994597c13d831ec7",
                name: "Tether",
                symbol: "USDT",
                decimals: 6,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
            balance: 0
        )

        let normalized = try normalize(
            sourceChain: .eth,
            sourceAsset: usdt,
            payload: makePayload(
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x7a250d5630b4cf539739df2c5dacb4c659f2488d","value":"0x0","data":"0x38ed1739"}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: usdt.asset.assetId,
                    spendAmount: "1000000",
                    receiveAsset: "eth/mainnet/coin"
                )
            )
        )

        guard case let .evm(relay)? = normalized.batteryPayload else {
            return XCTFail("expected a relayable evm payload, got \(String(describing: normalized.batteryPayload))")
        }
        XCTAssertEqual(relay.call.value, 0)
        XCTAssertEqual(relay.call.data, "0x38ed1739")
    }

    /// A swaps.xyz deposit has no calldata: the relayer carries it as the transfer it is.
    func test_evmPayload_swapXyz_depositIsRelayableAsATransfer() throws {
        let normalized = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"5039792842855559","data":"0x"}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "eth/mainnet/coin",
                    spendAmount: "5039792842855559",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: "0x1111111111111111111111111111111111111111"
                )
            ),
            provider: .swapXyz
        )

        guard case let .evm(relay)? = normalized.batteryPayload else {
            return XCTFail("expected a relayable evm payload, got \(String(describing: normalized.batteryPayload))")
        }
        XCTAssertEqual(relay.call.kind, .swap)
        XCTAssertEqual(relay.call.to, "0x1111111111111111111111111111111111111111")
        XCTAssertEqual(relay.call.value, BigUInt("5039792842855559"))
        XCTAssertEqual(relay.call.data, "0x")
    }

    func test_evmApprovalPayload_isNotRelayable() throws {
        let normalized = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "approval",
                payloadType: "evm_approval_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x0","data":"0x095ea7b3","gas":"0x64","gasPrice":"0x2"}"#
            )
        )

        XCTAssertNil(normalized.batteryPayload)
    }

    /// Whether the relayer serves a chain is the fee engine's question: every EVM route keeps its
    /// relayable form.
    func test_bscPayload_isRelayableLikeAnyEVMChain() throws {
        let normalized = try normalize(
            sourceChain: .bsc,
            payload: makePayload(
                sourceChain: .bsc,
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x2a","data":"0xabcd"}"#
            )
        )

        guard case let .evm(relay)? = normalized.batteryPayload else {
            return XCTFail("Expected an EVM relay, got \(String(describing: normalized.batteryPayload))")
        }
        XCTAssertEqual(relay.chain, .bsc)
        XCTAssertEqual(relay.call.kind, .swap)
        XCTAssertEqual(relay.call.chainId, "bsc/mainnet")
        XCTAssertEqual(relay.call.to, "0x1111111111111111111111111111111111111111")
        XCTAssertEqual(relay.call.value, 42)
        XCTAssertEqual(relay.call.data, "0xabcd")
    }

    func test_approvalPayload_withMainType_isRejectedBeforeParsing() {
        XCTAssertThrowsError(
            try normalize(
                sourceChain: .eth,
                payload: makePayload(
                    kind: "approval",
                    payloadType: "evm_tx",
                    payload: "{}"
                )
            )
        ) { error in
            guard case .invalidPayload = error as? MultichainSwapExecutionFailure else {
                return XCTFail("Expected invalidPayload, got \(error)")
            }
        }
    }

    func test_mainPayload_withApprovalType_isRejectedBeforeParsing() {
        XCTAssertThrowsError(
            try normalize(
                sourceChain: .eth,
                payload: makePayload(
                    kind: "main",
                    payloadType: "evm_approval_tx",
                    payload: "{}"
                )
            )
        ) { error in
            guard case .invalidPayload = error as? MultichainSwapExecutionFailure else {
                return XCTFail("Expected invalidPayload, got \(error)")
            }
        }
    }

    func test_swapXyzApprovalPayload_extractsApprovalDataAndProviderFee() throws {
        let usdc = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
        let approveCalldata = "0x095ea7b3"
            + "0000000000000000000000001b6257cae4192e62b629efca21771be3d759183d"
            + "00000000000000000000000000000000000000000000000000000000003d0900"
        let normalized = try normalize(
            sourceChain: .eth,
            sourceAsset: MultichainAsset(
                asset: MultichainAssetDetails(
                    assetId: "eth/mainnet/erc20/\(usdc)",
                    name: "USDC",
                    symbol: "USDC",
                    decimals: 6,
                    image: ""
                ),
                price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
                balance: 0
            ),
            payload: makePayload(
                kind: "approval",
                payloadType: "evm_approval_tx",
                payload: #"{"to":"\#(usdc)","value":"0","data":"\#(approveCalldata)","gas":"73254","gasPrice":"314078930"}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "eth/mainnet/erc20/\(usdc)",
                    spendAmount: "4000000",
                    receiveAsset: "eth/mainnet/coin"
                ),
                calldataPayloadType: .exact
            ),
            provider: .swapXyz
        )

        XCTAssertEqual(normalized.approvalData, approveCalldata)
        XCTAssertNil(try normalized.transaction.data)
        XCTAssertEqual(try normalized.transaction.to.display.lowercased(), usdc)
        XCTAssertTrue(normalized.isExactCalldata)
        let fee = try XCTUnwrap(normalized.fee as? FeeGas)
        XCTAssertEqual(fee.limit.description, "73254")
        XCTAssertEqual(fee.price.description, "314078930")
    }

    func test_unknownPayloadKind_isRejectedBeforeParsing() {
        XCTAssertThrowsError(
            try normalize(
                sourceChain: .eth,
                payload: makePayload(
                    kind: "custom",
                    payloadType: "evm_tx",
                    payload: "{}"
                )
            )
        ) { error in
            guard case .invalidPayload = error as? MultichainSwapExecutionFailure else {
                return XCTFail("Expected invalidPayload, got \(error)")
            }
        }
    }

    func test_tonPayload_swapXyz_readsToValueKeysAndKeepsPayload() throws {
        let tonAddress = address(for: .ton)
        let normalized = try normalize(
            sourceChain: .ton,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "ton_boc",
                payload: #"[{"to":"\#(tonAddress)","value":"700000000","payload":"ton-payload"}]"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "ton/mainnet/coin",
                    spendAmount: "1000000000",
                    receiveAsset: "eth/mainnet/coin",
                    depositAddress: nil
                )
            ),
            provider: .swapXyz
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "700000000")
        XCTAssertEqual(try normalized.transaction.to.display, tonAddress)
        XCTAssertEqual(try normalized.transaction.data, "ton-payload")
        XCTAssertNil(try normalized.transaction.initData)
        XCTAssertEqual(
            normalized.batteryPayload,
            .ton([TonSwapMessage(to: tonAddress, amount: 700_000_000, payload: "ton-payload", stateInit: nil)])
        )
    }

    /// swaps.xyz names the TON message fields `address`/`amount`. A parser that reads only
    /// `to`/`value` falls back to the deposit address — which a TON route no longer asks for — and
    /// the swap cannot be signed at all.
    func test_tonPayload_swapXyz_readsAddressAmountKeys() throws {
        let tonAddress = address(for: .ton)
        let normalized = try normalize(
            sourceChain: .ton,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "ton_boc",
                payload: #"[{"address":"\#(tonAddress)","amount":"580000000","payload":"ton-payload"}]"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "ton/mainnet/coin",
                    spendAmount: "300000000",
                    receiveAsset: "ton/mainnet/jetton/0:abc",
                    depositAddress: nil
                )
            ),
            provider: .swapXyz
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "580000000")
        XCTAssertEqual(try normalized.transaction.to.display, tonAddress)
        XCTAssertEqual(try normalized.transaction.data, "ton-payload")
    }

    func test_tonPayload_carryingAnythingItCannotReproduce_isNotRelayable() throws {
        let tonAddress = address(for: .ton)
        for key in ["stateInit", "state_init", "init", "mode", "sendMode", "bounce"] {
            let normalized = try normalize(
                sourceChain: .ton,
                payload: makePayload(
                    sourceChain: .ton,
                    payloadType: "ton_boc",
                    payload: #"[{"to":"\#(tonAddress)","value":"700000000","payload":"ton-payload","\#(key)":"te6ccgEBAQEAAgAAAA=="}]"#,
                    humanSummary: makeHumanSummary(
                        spendAsset: "ton/mainnet/coin",
                        spendAmount: "1000000000",
                        receiveAsset: "eth/mainnet/coin",
                        depositAddress: nil
                    )
                ),
                provider: .swapXyz
            )

            XCTAssertNil(normalized.batteryPayload, "\(key) must keep the swap off the relayer")
            XCTAssertNotNil(MultichainSwapPayloadAdapter.tonRelayObstacle(
                #"[{"to":"a","value":"1","\#(key)":"x"}]"#
            ))
        }
    }

    func test_tonPayloadWithSeveralMessages_keepsEveryMessageInOrder() throws {
        let tonAddress = address(for: .ton)
        let normalized = try normalize(
            sourceChain: .ton,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "ton_boc",
                payload: splitEnvelope(to: tonAddress),
                humanSummary: makeHumanSummary(
                    spendAsset: "ton/mainnet/coin",
                    spendAmount: "3000000000",
                    receiveAsset: "eth/mainnet/coin",
                    depositAddress: nil
                ),
                calldataPayloadType: .exact
            ),
            provider: .swapXyz
        )

        XCTAssertEqual(normalized.transactions.map(\.amount.description), ["185000000", "330000000", "260000000"])
        XCTAssertEqual(normalized.transactions.map(\.to.display), [tonAddress, tonAddress, tonAddress])
        XCTAssertEqual(normalized.transactions.map(\.data), ["first", "second", "third"])
        XCTAssertNil(normalized.fee)
        XCTAssertEqual(normalized.gasReservePolicy, .drainorerror)
        XCTAssertEqual(
            normalized.batteryPayload,
            .ton([
                TonSwapMessage(to: tonAddress, amount: 185_000_000, payload: "first", stateInit: nil),
                TonSwapMessage(to: tonAddress, amount: 330_000_000, payload: "second", stateInit: nil),
                TonSwapMessage(to: tonAddress, amount: 260_000_000, payload: "third", stateInit: nil),
            ])
        )
    }

    func test_splitTonRoute_isNeverResizedToFitTheFee() throws {
        let normalized = try normalize(
            sourceChain: .ton,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "ton_boc",
                payload: splitEnvelope(to: address(for: .ton)),
                calldataPayloadType: .flex
            ),
            provider: .swapXyz
        )
        let reserve = GasReserveResult(
            amount: BignumBigInteger.Companion.shared.fromInt(int: 7),
            isAmountAdjusted: true,
            error: nil
        )

        let adjusted = SwapTransactionAdjuster.adjustedTransactions(
            normalized.transactions,
            gasReserve: reserve,
            calldataType: normalized.calldataType
        )

        XCTAssertEqual(normalized.gasReservePolicy, .drainorerror)
        XCTAssertEqual(adjusted.map(\.amount.description), ["185000000", "330000000", "260000000"])
        XCTAssertFalse(adjusted.contains(where: \.isMax))
    }

    /// The deposit address and the spend amount describe the whole route: a part that falls back
    /// to them would send the whole amount, or send it somewhere the quote never named.
    func test_splitTonRoute_partWithoutItsOwnAmountOrRecipient_isRejected() {
        let tonAddress = address(for: .ton)
        let envelopes = [
            #"[{"address":"\#(tonAddress)","amount":"185000000","payload":"first"},{"address":"\#(tonAddress)","payload":"second"}]"#,
            #"[{"address":"\#(tonAddress)","amount":"185000000","payload":"first"},{"amount":"330000000","payload":"second"}]"#,
        ]
        for envelope in envelopes {
            XCTAssertThrowsError(
                try normalize(
                    sourceChain: .ton,
                    payload: makePayload(
                        sourceChain: .ton,
                        payloadType: "ton_boc",
                        payload: envelope,
                        humanSummary: makeHumanSummary(
                            spendAsset: "ton/mainnet/coin",
                            spendAmount: "3000000000",
                            receiveAsset: "eth/mainnet/coin",
                            depositAddress: tonAddress
                        )
                    ),
                    provider: .swapXyz
                )
            ) { error in
                guard case .invalidPayload(payloadId: "payload-ton_boc", _) = error as? MultichainSwapExecutionFailure else {
                    return XCTFail("Unexpected failure \(error)")
                }
            }
        }
    }

    func test_tonJettonSwapMessages_attachTheTonTheyCarry() throws {
        let tonAddress = address(for: .ton)
        let jettonSwap = try normalize(
            sourceChain: .ton,
            sourceAsset: makeJettonAsset(),
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "ton_boc",
                payload: splitEnvelope(to: tonAddress)
            ),
            provider: .swapXyz
        )
        XCTAssertEqual(jettonSwap.attachedEnergy.description, "775000000")

        let tonSwap = try normalize(
            sourceChain: .ton,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "ton_boc",
                payload: splitEnvelope(to: tonAddress)
            ),
            provider: .swapXyz
        )
        XCTAssertEqual(tonSwap.attachedEnergy.description, "0")

        let jettonDeposit = try normalize(
            sourceChain: .ton,
            sourceAsset: makeJettonAsset(),
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "alt_vm_deposit",
                payload: #"[{"to":"\#(tonAddress)","value":"100000000"}]"#
            ),
            provider: .swapXyz
        )
        XCTAssertEqual(jettonDeposit.attachedEnergy.description, "0")
    }

    func test_tonRelayObstacle_acceptsOnlyWhatTheRelayCarries() {
        XCTAssertNil(
            MultichainSwapPayloadAdapter.tonRelayObstacle(#"[{"address":"a","amount":"1","payload":"b"}]"#)
        )
        XCTAssertNil(
            MultichainSwapPayloadAdapter.tonRelayObstacle(#"[{"to":"a","value":"1","data":"b"}]"#)
        )
        XCTAssertNil(
            MultichainSwapPayloadAdapter.tonRelayObstacle(
                #"[{"address":"a","amount":"1","payload":"b"},{"to":"c","value":"2","data":"d"}]"#
            )
        )
        XCTAssertEqual(
            MultichainSwapPayloadAdapter.tonRelayObstacle(
                #"[{"address":"a","amount":"1"},{"address":"c","amount":"2","stateInit":"x"}]"#
            ),
            "message carries stateInit"
        )
        XCTAssertNotNil(MultichainSwapPayloadAdapter.tonRelayObstacle("not json"))
        XCTAssertNotNil(MultichainSwapPayloadAdapter.tonRelayObstacle(#"{"to":"a","value":"1"}"#))
        XCTAssertNotNil(MultichainSwapPayloadAdapter.tonRelayObstacle("[]"))
    }

    func test_tronPayload_swapXyz_buildsPlainTransferWithoutData() throws {
        let tronAddress = address(for: .tron)
        let normalized = try normalize(
            sourceChain: .tron,
            payload: makePayload(
                sourceChain: .tron,
                payloadType: "tron_tx",
                payload: #"{"to":"","value":""}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "tron/mainnet/coin",
                    spendAmount: "700",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: tronAddress
                )
            ),
            provider: .swapXyz
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "700")
        XCTAssertEqual(try normalized.transaction.to.display, tronAddress)
        XCTAssertEqual(
            normalized.batteryPayload,
            .tron(TronSwapTransfer(to: tronAddress, amount: 700))
        )
        XCTAssertNil(try normalized.transaction.data)
    }

    func test_btcPayload_swapXyz_buildsPlainTransferWithoutData() throws {
        let btcAddress = address(for: .btc)
        let normalized = try normalize(
            sourceChain: .btc,
            payload: makePayload(
                sourceChain: .btc,
                payloadType: "utxo_psbt",
                payload: #"{"to":"","value":""}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "btc/mainnet/coin",
                    spendAmount: "2500",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: btcAddress
                )
            ),
            provider: .swapXyz
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "2500")
        XCTAssertEqual(try normalized.transaction.to.display, btcAddress)
        XCTAssertNil(try normalized.transaction.data)
    }

    func test_tonSource_sendsFromTheWalletContractVersion() throws {
        let normalized = try normalize(
            sourceChain: .ton,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "alt_vm_deposit",
                payload: #"[{"to":"\#(address(for: .ton))","toExtra":null,"value":"1000000000","chainId":999000337,"chainKey":"ton"}]"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "ton/mainnet/coin",
                    spendAmount: "1000000000",
                    receiveAsset: "eth/mainnet/coin",
                    depositAddress: nil
                )
            ),
            provider: .swapXyz
        )

        XCTAssertEqual(try normalized.transaction.account.address.type, .tonv4r2)
    }

    func test_btcSource_keepsAnUntypedSenderAddress() throws {
        let normalized = try normalize(
            sourceChain: .btc,
            payload: makePayload(
                sourceChain: .btc,
                payloadType: "utxo_psbt",
                payload: #"{"to":"","value":""}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "btc/mainnet/coin",
                    spendAmount: "2500",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: address(for: .btc)
                )
            ),
            provider: .swapXyz
        )

        XCTAssertEqual(try normalized.transaction.account.address.type, .default_)
    }

    func test_tonAltVmDepositPayload_swapXyz_buildsPlainTransfer() throws {
        let tonAddress = address(for: .ton)
        let normalized = try normalize(
            sourceChain: .ton,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "alt_vm_deposit",
                payload: #"[{"to":"\#(tonAddress)","toExtra":null,"value":"9223291577","chainId":999000337,"chainKey":"ton"}]"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "ton/mainnet/coin",
                    spendAmount: "9223291577",
                    receiveAsset: "eth/mainnet/coin",
                    depositAddress: nil
                )
            ),
            provider: .swapXyz
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "9223291577")
        XCTAssertEqual(try normalized.transaction.to.display, tonAddress)
        XCTAssertNil(try normalized.transaction.data)
        XCTAssertNil(try normalized.transaction.initData)
        // A deposit is not the BOC the relayer knows how to take over.
        XCTAssertNil(normalized.batteryPayload)
    }

    func test_tonJettonAltVmDepositPayload_swapXyz_buildsBatteryJettonDeposit() throws {
        let tonAddress = address(for: .ton)
        let sourceAsset = makeJettonAsset()
        let normalized = try normalize(
            sourceChain: .ton,
            sourceAsset: sourceAsset,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "alt_vm_deposit",
                payload: #"[{"to":"\#(tonAddress)","toExtra":null,"value":"100000000","chainId":999000337,"chainKey":"ton"}]"#,
                humanSummary: makeHumanSummary(
                    spendAsset: sourceAsset.asset.assetId,
                    spendAmount: "100000000",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: nil
                )
            ),
            provider: .swapXyz
        )

        XCTAssertEqual(
            normalized.batteryPayload,
            .tonJettonDeposit(TonJettonSwapDeposit(recipient: tonAddress, amount: 100_000_000))
        )
    }

    func test_tonJettonAltVmDeposit_withCalldata_isNotRelayable() throws {
        let tonAddress = address(for: .ton)
        let sourceAsset = makeJettonAsset()
        let normalized = try normalize(
            sourceChain: .ton,
            sourceAsset: sourceAsset,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "alt_vm_deposit",
                payload: #"[{"to":"\#(tonAddress)","toExtra":null,"value":"100000000","payload":"te6ccg"}]"#,
                humanSummary: makeHumanSummary(
                    spendAsset: sourceAsset.asset.assetId,
                    spendAmount: "100000000",
                    receiveAsset: "ton/mainnet/coin"
                )
            ),
            provider: .swapXyz
        )

        XCTAssertNil(normalized.batteryPayload)
    }

    /// No path attaches a memo — `Transaction.Swap` has no field for one — so refusing the relayer
    /// over one would only take away the fee choice while the native path sent the same message.
    func test_tonJettonAltVmDeposit_withMemo_staysRelayable() throws {
        let tonAddress = address(for: .ton)
        let sourceAsset = makeJettonAsset()
        for (toExtra, memo) in [(#""memo""#, nil), ("null", "memo")] {
            let normalized = try normalize(
                sourceChain: .ton,
                sourceAsset: sourceAsset,
                payload: makePayload(
                    sourceChain: .ton,
                    payloadType: "alt_vm_deposit",
                    payload: #"[{"to":"\#(tonAddress)","toExtra":\#(toExtra),"value":"100000000"}]"#,
                    humanSummary: makeHumanSummary(
                        spendAsset: sourceAsset.asset.assetId,
                        spendAmount: "100000000",
                        receiveAsset: "ton/mainnet/coin",
                        memo: memo
                    )
                ),
                provider: .swapXyz
            )

            XCTAssertEqual(
                normalized.batteryPayload,
                .tonJettonDeposit(TonJettonSwapDeposit(recipient: tonAddress, amount: 100_000_000))
            )
        }
    }

    func test_tonJettonAltVmDeposit_withMalformedSourceAsset_isNotRelayable() throws {
        let tonAddress = address(for: .ton)
        let sourceAsset = makeJettonAsset(address: "not-an-address")
        let normalized = try normalize(
            sourceChain: .ton,
            sourceAsset: sourceAsset,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "alt_vm_deposit",
                payload: #"[{"to":"\#(tonAddress)","toExtra":null,"value":"100000000"}]"#,
                humanSummary: makeHumanSummary(
                    spendAsset: sourceAsset.asset.assetId,
                    spendAmount: "100000000",
                    receiveAsset: "ton/mainnet/coin"
                )
            ),
            provider: .swapXyz
        )

        XCTAssertNil(normalized.batteryPayload)
    }

    /// SwapKit answers a TON deposit with the message itself rather than an envelope of messages,
    /// which is the shape the live route carries; nothing about the swap works until it parses.
    func test_tonJettonAltVmDeposit_swapKitMessageObject_buildsBatteryJettonDeposit() throws {
        let tonAddress = address(for: .ton)
        let sourceAsset = makeJettonAsset()
        let normalized = try normalize(
            sourceChain: .ton,
            sourceAsset: sourceAsset,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "alt_vm_deposit",
                payload: #"{"amount":"50000000","to":"\#(tonAddress)"}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: sourceAsset.asset.assetId,
                    spendAmount: "50000000",
                    receiveAsset: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
                    depositAddress: tonAddress
                ),
                calldataPayloadType: .flex
            ),
            provider: .swapKit
        )

        XCTAssertEqual(try normalized.transaction.to.display, tonAddress)
        XCTAssertEqual(try normalized.transaction.amount.description, "50000000")
        XCTAssertEqual(
            normalized.batteryPayload,
            .tonJettonDeposit(TonJettonSwapDeposit(recipient: tonAddress, amount: 50_000_000))
        )
    }

    func test_tonJettonAltVmDeposit_messageObjectWithCalldata_isNotRelayable() throws {
        let tonAddress = address(for: .ton)
        let sourceAsset = makeJettonAsset()
        let normalized = try normalize(
            sourceChain: .ton,
            sourceAsset: sourceAsset,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "alt_vm_deposit",
                payload: #"{"amount":"50000000","to":"\#(tonAddress)","payload":"te6ccg"}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: sourceAsset.asset.assetId,
                    spendAmount: "50000000",
                    receiveAsset: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
                ),
                calldataPayloadType: .flex
            ),
            provider: .swapKit
        )

        XCTAssertNil(normalized.batteryPayload)
    }

    /// Wrapping must not promote an envelope the relay cannot reproduce: `tonRelayObstacle` reads the
    /// payload as the backend sent it, so a `ton_boc` object parses but still pays its own way.
    /// SwapKit prices an EVM deposit the same way it prices a TON one, and the EVM parser reads the
    /// amount under `value`, so the descriptor is unusable until the two names meet.
    func test_evmAltVmDeposit_swapKitMessageObject_buildsPlainTransfer() throws {
        let deposit = "0xF90Fcfc48e36d1214B1854Ce91EE1E5D06Eb6e9B"
        let normalized = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                sourceChain: .eth,
                payloadType: "alt_vm_deposit",
                payload: #"{"amount":"50000000","to":"\#(deposit)"}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "eth/mainnet/coin",
                    spendAmount: "50000000",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: deposit
                ),
                calldataPayloadType: .flex
            ),
            provider: .swapKit
        )

        XCTAssertEqual(try normalized.transaction.to.display, deposit)
        XCTAssertEqual(try normalized.transaction.amount.description, "50000000")
        XCTAssertNil(try normalized.transaction.data)
    }

    /// The translation is scoped to the descriptor: a payload whose shape the schema fixes reaches
    /// the parser as the backend sent it, so a broken contract stays visible instead of being
    /// quietly repaired here.
    func test_fixedShapePayloadTypes_areNotTranslated() {
        XCTAssertThrowsError(
            try normalize(
                sourceChain: .ton,
                payload: makePayload(
                    sourceChain: .ton,
                    payloadType: "ton_boc",
                    payload: #"{"address":"\#(address(for: .ton))","amount":"1000000000"}"#,
                    humanSummary: makeHumanSummary(
                        spendAsset: "ton/mainnet/coin",
                        spendAmount: "1000000000",
                        receiveAsset: "eth/mainnet/coin"
                    )
                )
            )
        ) { error in
            guard case .invalidPayload = error as? MultichainSwapExecutionFailure else {
                return XCTFail("Expected invalidPayload, got \(error)")
            }
        }
    }

    func test_parsableDepositDescriptor_translatesOnlyWhatItsParserCannotRead() throws {
        let message = #"{"amount":"1","to":"UQ"}"#
        XCTAssertEqual(
            MultichainSwapPayloadAdapter.parsableDepositDescriptor(message, chain: .ton),
            "[\(message)]"
        )

        let envelope = #"[{"amount":"1","to":"UQ"}]"#
        XCTAssertEqual(MultichainSwapPayloadAdapter.parsableDepositDescriptor(envelope, chain: .ton), envelope)

        let base64 = "te6ccgEBAQEAAgAAAA=="
        XCTAssertEqual(MultichainSwapPayloadAdapter.parsableDepositDescriptor(base64, chain: .ton), base64)

        for chain in MultichainChain.allCases where chain.isEVM {
            let translated = MultichainSwapPayloadAdapter.parsableDepositDescriptor(
                #"{"amount":"42","to":"0x1"}"#,
                chain: chain
            )
            let fields = try XCTUnwrap(
                JSONSerialization.jsonObject(with: XCTUnwrap(translated.data(using: .utf8))) as? [String: String]
            )
            XCTAssertEqual(fields["value"], "42")
            XCTAssertEqual(fields["to"], "0x1")

            let priced = #"{"value":"42","amount":"7","to":"0x1"}"#
            XCTAssertEqual(MultichainSwapPayloadAdapter.parsableDepositDescriptor(priced, chain: chain), priced)
        }

        for chain in MultichainChain.allCases where !chain.isEVM && chain != .ton {
            XCTAssertEqual(MultichainSwapPayloadAdapter.parsableDepositDescriptor(message, chain: chain), message)
        }
    }

    func test_tronAltVmDepositPayload_swapXyz_buildsPlainTransfer() throws {
        let tronAddress = address(for: .tron)
        let normalized = try normalize(
            sourceChain: .tron,
            payload: makePayload(
                sourceChain: .tron,
                payloadType: "alt_vm_deposit",
                payload: #"{"to":"\#(tronAddress)","toExtra":null,"value":"9191671","chainId":728126428,"chainKey":"trx"}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
                    spendAmount: "9191671",
                    receiveAsset: "eth/mainnet/coin",
                    depositAddress: nil
                )
            ),
            provider: .swapXyz
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "9191671")
        XCTAssertEqual(try normalized.transaction.to.display, tronAddress)
        XCTAssertNil(try normalized.transaction.data)
        // A deposit is the one TRON shape a relayer can rebuild, whatever the payload is labelled.
        XCTAssertEqual(
            normalized.batteryPayload,
            .tron(TronSwapTransfer(to: tronAddress, amount: 9_191_671))
        )
    }

    /// The quote from TK-3029: a USDT TRC-20 swap arrives as an alt-vm deposit whose payload names the
    /// aggregator's address and carries no call data, which is the shape a relayer can rebuild.
    func test_tronUsdtDepositFromReportedQuote_isRelayable() throws {
        let normalized = try normalize(
            sourceChain: .tron,
            payload: makePayload(
                sourceChain: .tron,
                payloadType: "alt_vm_deposit",
                payload: #"{"to":"TCaxmZvD5kysgFNSqovSpxKKkZdD818cvr","toExtra":null,"value":"13125976","chainId":728126428,"chainKey":"trx"}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
                    spendAmount: "13125976",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: nil
                )
            ),
            provider: .swapXyz
        )

        XCTAssertNil(try normalized.transaction.data)
        XCTAssertEqual(
            normalized.batteryPayload,
            .tron(TronSwapTransfer(to: "TCaxmZvD5kysgFNSqovSpxKKkZdD818cvr", amount: 13_125_976))
        )
    }

    func test_tonPayload_usesJsonArrayAndHumanSummaryFallback() throws {
        let tonAddress = address(for: .ton)
        let normalized = try normalize(
            sourceChain: .ton,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "ton_boc",
                payload: #"[{"payload":"ton-payload"}]"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "ton/mainnet/coin",
                    spendAmount: "1000000000",
                    receiveAsset: "eth/mainnet/coin",
                    depositAddress: tonAddress
                )
            )
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "1000000000")
        XCTAssertEqual(try normalized.transaction.to.display, tonAddress)
        XCTAssertEqual(try normalized.transaction.data, "ton-payload")
    }

    func test_btcPayload_parsesQuotedPsbtAndHumanSummary() throws {
        let btcAddress = address(for: .btc)
        let normalized = try normalize(
            sourceChain: .btc,
            payload: makePayload(
                sourceChain: .btc,
                payloadType: "utxo_psbt",
                payload: #""psbt-value""#,
                humanSummary: makeHumanSummary(
                    spendAsset: "btc/mainnet/coin",
                    spendAmount: "2500",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: btcAddress
                )
            )
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "2500")
        XCTAssertEqual(try normalized.transaction.to.display, btcAddress)
        XCTAssertEqual(try normalized.transaction.data, "psbt-value")
    }

    func test_btcPayload_hasNoLocalFee() throws {
        let psbt = [
            "cHNidP8BAKQCAAAAAzVu5olODXnGR+3wMJDUID70IUI22DfX1ja8MlvqlNSkAQAAAAD/////",
            "YDlCpBvpMciegDoQdizBNF7kkZDAkjP+pBpHfSowauAAAAAAAP////9+Xlamr3J0XwoZiEmEjHhbYvPvIqoC0anpsPbz4vl7ZQEAAAAA/////",
            "wFxUwAAAAAAABYAFJ1BtZLU0Mu1E54Dn0COPpQYhdM1AAAAAAABAR/FIQAAAAAAABYAFB3NVOCXq+iW4p/24oqrkBi8XybqAAEBH7IhAAAAAAAAFgAUHc1U4Jer6Jbin/biiquQGLxfJuoAAQEf5hEAAAAAAAAWABQdzVTgl6voluKf9uKKq5AYvF8m6gAA",
        ].joined()
        let btcAddress = address(for: .btc)
        let normalized = try normalize(
            sourceChain: .btc,
            payload: makePayload(
                sourceChain: .btc,
                payloadType: "utxo_psbt",
                payload: "\"\(psbt)\"",
                humanSummary: makeHumanSummary(
                    spendAsset: "btc/mainnet/coin",
                    spendAmount: "21853",
                    receiveAsset: "eth/mainnet/coin",
                    depositAddress: btcAddress
                )
            )
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "21853")
        XCTAssertEqual(try normalized.transaction.data, psbt)
        XCTAssertNil(normalized.fee)
    }

    func test_btcPayload_acceptsUnquotedPsbtAndHumanSummary() throws {
        let btcAddress = address(for: .btc)
        let normalized = try normalize(
            sourceChain: .btc,
            payload: makePayload(
                sourceChain: .btc,
                payloadType: "utxo_psbt",
                payload: "psbt-value",
                humanSummary: makeHumanSummary(
                    spendAsset: "btc/mainnet/coin",
                    spendAmount: "2500",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: btcAddress
                )
            )
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "2500")
        XCTAssertEqual(try normalized.transaction.to.display, btcAddress)
        XCTAssertEqual(try normalized.transaction.data, "psbt-value")
    }

    func test_tronPayload_passesRawJsonAndHumanSummary() throws {
        let tronAddress = address(for: .tron)
        let rawPayload = #"{"txID":"abc","raw_data":{}}"#
        let normalized = try normalize(
            sourceChain: .tron,
            payload: makePayload(
                sourceChain: .tron,
                payloadType: "tron_tx",
                payload: rawPayload,
                humanSummary: makeHumanSummary(
                    spendAsset: "tron/mainnet/coin",
                    spendAmount: "700",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: tronAddress
                )
            )
        )

        XCTAssertEqual(try normalized.transaction.amount.description, "700")
        XCTAssertEqual(try normalized.transaction.to.display, tronAddress)
        XCTAssertEqual(try normalized.transaction.data, rawPayload)
    }

    func test_adjustedSwapTransaction_appliesShrunkAmountAndMarksMax() throws {
        let normalized = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x2a","data":"0x"}"#
            )
        )
        let reserve = GasReserveResult(
            amount: BignumBigInteger.Companion.shared.fromInt(int: 7),
            isAmountAdjusted: true,
            error: nil
        )

        let adjusted = try XCTUnwrap(
            SwapTransactionAdjuster.adjustedTransactions(
                normalized.transactions,
                gasReserve: reserve,
                calldataType: .flex
            ).first
        )

        XCTAssertEqual(adjusted.amount.description, "7")
        XCTAssertTrue(adjusted.isMax)
        XCTAssertEqual(adjusted.to.display, try normalized.transaction.to.display)
        XCTAssertEqual(adjusted.data, try normalized.transaction.data)
        XCTAssertEqual(adjusted.account, try normalized.transaction.account)
        XCTAssertEqual(adjusted.destination, try normalized.transaction.destination)
    }

    func test_adjustedSwapTransaction_keepsTransactionWhenNotAdjusted() throws {
        let normalized = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x2a","data":"0x"}"#
            )
        )
        let reserve = GasReserveResult(
            amount: BignumBigInteger.Companion.shared.fromInt(int: 7),
            isAmountAdjusted: false,
            error: nil
        )

        let adjusted = try XCTUnwrap(
            SwapTransactionAdjuster.adjustedTransactions(
                normalized.transactions,
                gasReserve: reserve,
                calldataType: .flex
            ).first
        )

        XCTAssertEqual(adjusted.amount.description, "42")
        XCTAssertFalse(adjusted.isMax)
    }

    /// `exact` calldata carries the sell amount inside it, so a reserve that would trim the
    /// amount is ignored: the transaction leaves with the quoted amount or not at all.
    func test_adjustedSwapTransaction_neverTrimsExactCalldata() throws {
        let normalized = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x2a","data":"0xabcd"}"#,
                calldataPayloadType: .exact
            )
        )
        let reserve = GasReserveResult(
            amount: BignumBigInteger.Companion.shared.fromInt(int: 7),
            isAmountAdjusted: true,
            error: nil
        )

        let adjusted = try XCTUnwrap(
            SwapTransactionAdjuster.adjustedTransactions(
                normalized.transactions,
                gasReserve: reserve,
                calldataType: normalized.calldataType
            ).first
        )

        XCTAssertEqual(adjusted.amount.description, "42")
        XCTAssertFalse(adjusted.isMax)
    }

    func test_calldataType_isTakenFromTheBackend() throws {
        // ChainKit parses swap calldata only for an `exact` payload; a `flex` one is a
        // deposit-style transfer it rebuilds itself, so it must not carry calldata.
        let exactJSON = #"{"to":"0x1111111111111111111111111111111111111111","value":"0x2a","data":"0xabcd"}"#
        let flexJSON = #"{"to":"0x1111111111111111111111111111111111111111","value":"0x2a","data":"0x"}"#

        let exact = try normalize(
            sourceChain: .eth,
            payload: makePayload(kind: "main", payloadType: "evm_tx", payload: exactJSON, calldataPayloadType: .exact)
        )
        XCTAssertEqual(exact.calldataType, .exact)
        XCTAssertTrue(exact.isExactCalldata)
        XCTAssertEqual(exact.gasReservePolicy, .drainorerror)

        let flex = try normalize(
            sourceChain: .eth,
            payload: makePayload(kind: "main", payloadType: "evm_tx", payload: flexJSON, calldataPayloadType: .flex)
        )
        XCTAssertEqual(flex.calldataType, .flex)
        XCTAssertFalse(flex.isExactCalldata)
        XCTAssertEqual(flex.gasReservePolicy, .shrinktofit)
    }

    func test_calldataType_withoutBackendValue_signsASolanaTransactionAsBuilt() throws {
        let transaction = "AQ=="
        for provider in [MultichainSwapProvider.swapKit, .swapXyz] {
            let normalized = try normalize(
                sourceChain: .sol,
                payload: makePayload(
                    sourceChain: .sol,
                    payloadType: "solana_tx",
                    payload: provider == .swapXyz ? #"{"base64Tx":"\#(transaction)"}"# : transaction,
                    humanSummary: makeHumanSummary(
                        spendAsset: "sol/mainnet/coin",
                        spendAmount: "1000",
                        receiveAsset: "ton/mainnet/coin",
                        depositAddress: address(for: .sol)
                    )
                ),
                provider: provider
            )
            XCTAssertEqual(normalized.calldataType, .exact, "\(provider)")
            XCTAssertEqual(try normalized.transaction.data, transaction, "\(provider)")
        }
    }

    /// Without `calldata_payload_type` only a payload this path builds itself may be assumed
    /// flexible. Assuming it for one that carries its own transaction is destructive: the EVM leg is
    /// refused outright, and the BTC and TRON ones lose their payload to a plain deposit transfer.
    func test_calldataType_withoutBackendValue_isFlexOnlyForAWalletBuiltTransfer() throws {
        let evmCalldata = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x2a","data":"0xabcd"}"#
            )
        )
        XCTAssertEqual(evmCalldata.calldataType, .exact)
        XCTAssertEqual(try evmCalldata.transaction.data, "0xabcd")

        let btcPsbt = try normalize(
            sourceChain: .btc,
            payload: makePayload(
                sourceChain: .btc,
                payloadType: "utxo_psbt",
                payload: #""psbt-value""#,
                humanSummary: makeHumanSummary(
                    spendAsset: "btc/mainnet/coin",
                    spendAmount: "2500",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: address(for: .btc)
                )
            )
        )
        XCTAssertEqual(btcPsbt.calldataType, .exact)
        XCTAssertEqual(try btcPsbt.transaction.data, "psbt-value")

        let swapXyzDeposit = try normalize(
            sourceChain: .btc,
            payload: makePayload(
                sourceChain: .btc,
                payloadType: "utxo_psbt",
                payload: #"{"to":"","value":""}"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "btc/mainnet/coin",
                    spendAmount: "2500",
                    receiveAsset: "ton/mainnet/coin",
                    depositAddress: address(for: .btc)
                )
            ),
            provider: .swapXyz
        )
        XCTAssertEqual(swapXyzDeposit.calldataType, .flex)

        let evmTransfer = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x2a","data":"0x"}"#
            )
        )
        XCTAssertEqual(evmTransfer.calldataType, .flex)
        XCTAssertEqual(evmTransfer.gasReservePolicy, .shrinktofit)

        let evmApproval = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "approval",
                payloadType: "evm_approval_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x0","data":"0x095ea7b3"}"#
            )
        )
        XCTAssertEqual(evmApproval.calldataType, .exact)

        let tonMain = try normalize(
            sourceChain: .ton,
            payload: makePayload(
                sourceChain: .ton,
                payloadType: "ton_boc",
                payload: #"[{"payload":"ton-payload"}]"#,
                humanSummary: makeHumanSummary(
                    spendAsset: "ton/mainnet/coin",
                    spendAmount: "1000000000",
                    receiveAsset: "eth/mainnet/coin",
                    depositAddress: address(for: .ton)
                )
            )
        )
        XCTAssertEqual(tonMain.calldataType, .exact)
        XCTAssertEqual(tonMain.gasReservePolicy, .drainorerror)
    }

    func test_adjustedTransfer_appliesShrunkAmountAndMarksMax() throws {
        let normalized = try normalize(
            sourceChain: .eth,
            payload: makePayload(
                kind: "main",
                payloadType: "evm_tx",
                payload: #"{"to":"0x1111111111111111111111111111111111111111","value":"0x2a","data":"0x"}"#
            )
        )
        let transfer = try TransactionTransfer(
            account: normalized.transaction.account,
            amount: BignumBigInteger.Companion.shared.fromInt(int: 42),
            isMax: false,
            to: normalized.transaction.to,
            memo: "memo",
            payload: nil
        )
        let reserve = GasReserveResult(
            amount: BignumBigInteger.Companion.shared.fromInt(int: 30),
            isAmountAdjusted: true,
            error: nil
        )

        let adjusted = ChainKitServiceImplementation.adjustedTransfer(transfer, gasReserve: reserve)

        XCTAssertEqual(adjusted.amount.description, "30")
        XCTAssertTrue(adjusted.isMax)
        XCTAssertEqual(adjusted.to.display, transfer.to.display)
        XCTAssertEqual(adjusted.memo, "memo")
    }

    func test_unknownPayloadType_isRejected() {
        XCTAssertThrowsError(
            try normalize(
                sourceChain: .eth,
                payload: makePayload(payloadType: "unknown", payload: "{}")
            )
        ) { error in
            XCTAssertEqual(error as? MultichainSwapExecutionFailure, .unsupportedPayloadType("unknown"))
        }
    }
}

private extension MultichainSwapPayloadAdapter.Normalized {
    var transaction: TransactionSwap {
        get throws {
            XCTAssertEqual(transactions.count, 1)
            return try XCTUnwrap(transactions.first)
        }
    }
}

private extension MultichainSwapPayloadAdapterTests {
    func splitEnvelope(to address: String) -> String {
        let messages = [
            #"{"address":"\#(address)","amount":"185000000","payload":"first"}"#,
            #"{"address":"\#(address)","amount":"330000000","payload":"second"}"#,
            #"{"address":"\#(address)","amount":"260000000","payload":"third"}"#,
        ]
        return "[\(messages.joined(separator: ","))]"
    }

    func normalize(
        sourceChain: MultichainChain,
        sourceAsset: MultichainAsset? = nil,
        payload: MultichainSwapPreparedPayload,
        provider: MultichainSwapProvider = .swapKit
    ) throws -> MultichainSwapPayloadAdapter.Normalized {
        try adapter.normalize(
            swapWallet: makeSwapWallet(),
            sourceAsset: sourceAsset ?? makeAsset(chain: sourceChain),
            destinationAsset: makeAsset(chain: .ton),
            payload: payload,
            provider: provider
        )
    }

    func makePayload(
        sourceChain: MultichainChain = .eth,
        kind: String = "main",
        payloadType: String = "evm_tx",
        payload: String,
        humanSummary: MultichainSwapHumanSummary? = nil,
        calldataPayloadType: MultichainSwapCalldataPayloadType? = nil
    ) -> MultichainSwapPreparedPayload {
        MultichainSwapPreparedPayload(
            payloadId: "payload-\(payloadType)",
            kind: kind,
            chainId: sourceChain.crossSwapChainId,
            chainFamily: sourceChain.rawValue,
            payloadType: payloadType,
            payload: payload,
            humanSummary: humanSummary ?? makeHumanSummary(
                spendAsset: makeAsset(chain: sourceChain).asset.assetId,
                spendAmount: "1",
                receiveAsset: "ton/mainnet/coin"
            ),
            validationStatus: "validated",
            dateExpire: Date(timeIntervalSince1970: 1000),
            calldataPayloadType: calldataPayloadType
        )
    }

    func makeHumanSummary(
        spendAsset: String,
        spendAmount: String,
        receiveAsset: String,
        depositAddress: String? = nil,
        memo: String? = nil
    ) -> MultichainSwapHumanSummary {
        MultichainSwapHumanSummary(
            action: "swap",
            spendAsset: spendAsset,
            spendAmount: spendAmount,
            receiveAsset: receiveAsset,
            depositAddress: depositAddress,
            memo: memo
        )
    }

    func makeSwapWallet() -> MultichainSwapWallet {
        let publicKey = PublicKey(data: Data(repeating: 1, count: 32))
        let state = MultichainWalletState(
            walletId: "wallet",
            addresses: MultichainChain.allCases.map {
                MultichainWalletAddress(
                    chain: $0,
                    address: address(for: $0),
                    type: walletAddressType(for: $0)
                )
            }
        )
        let wallet = Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(publicKey, .v4R2)),
            metaData: WalletMetaData(label: "wallet", tintColor: .SteelGray, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(),
            batterySettings: BatterySettings(),
            multichain: .multichain(state)
        )
        return MultichainSwapWallet(wallet: wallet, registeredState: state)
    }

    func makeAsset(chain: MultichainChain) -> MultichainAsset {
        let assetId = "\(chain.crossSwapChainId)/coin"
        return MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: assetId,
                name: chain.rawValue.uppercased(),
                symbol: chain.rawValue.uppercased(),
                decimals: chain == .btc ? 8 : 18,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
            balance: 0
        )
    }

    func makeJettonAsset(address: String = "0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe") -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(
                assetId: "ton/mainnet/jetton/\(address)",
                name: "USDT",
                symbol: "USD₮",
                decimals: 6,
                image: ""
            ),
            price: MultichainAssetPrice(prices: [:], diff24h: [:], diff7d: [:]),
            balance: 0
        )
    }

    func address(for chain: MultichainChain) -> String {
        chainKitWallet.getAddress(
            chain: chain.asChainKitChain,
            type: chainKitAddressType(for: chain)
        ).display
    }

    func chainKitAddressType(for chain: MultichainChain) -> ChainKit.Address.Type_ {
        switch chain {
        case .ton:
            return .tonv4r2
        case .btc:
            return .btcsegwit
        case .eth, .base, .tron, .arb, .bsc, .sol, .polygon, .avax, .robinhood:
            return .default_
        }
    }

    func walletAddressType(for chain: MultichainChain) -> MultichainWalletAddressType? {
        switch chain {
        case .ton:
            return .tonV4R2
        case .btc:
            return .btcP2WPKH
        case .eth, .base, .tron, .arb, .bsc, .sol, .polygon, .avax, .robinhood:
            return nil
        }
    }

    var chainKitWallet: CryptoWallet {
        try! CryptoWallet.Companion.shared.fromMnemonic(
            mnemonic_: "circle inch grow apart leaf cool crop tomato confirm teach example curtain"
        )
    }
}

private extension MultichainChain {
    var crossSwapChainId: String {
        switch self {
        case .ton:
            return "ton/mainnet"
        case .tron:
            return "tron/mainnet"
        case .btc:
            return "btc/mainnet"
        case .eth:
            return "eth/mainnet"
        case .base:
            return "base/mainnet"
        case .arb:
            return "arb/mainnet"
        case .bsc:
            return "bsc/mainnet"
        case .sol:
            return "sol/mainnet"
        case .polygon:
            return "polygon/mainnet"
        case .avax:
            return "avax/mainnet"
        case .robinhood:
            return "robinhood/mainnet"
        }
    }
}
