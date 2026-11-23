@preconcurrency import BigInt
@preconcurrency import ChainKit
@testable import KeeperCore
import TonSwift
import XCTest

/// The coin's method of a TRON USDT or TON jetton send, paid as chain-kit's operation while operation
/// transfers are on: which sends get one, how it is listed and offered, and the TON a jetton's operation
/// leaves the wallet to hold beside its fee.
final class MultichainOperationPaidMethodTests: XCTestCase {
    private typealias Controller = MultichainTransactionConfirmationController
    private typealias Option = TransactionConfirmationModel.ExtraOption

    private static let tonRecipient = "EQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM9c"
    private static let usdt = JettonInfo(
        isTransferable: true,
        hasCustomPayload: false,
        address: try! TonSwift.Address.parse("0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe"),
        fractionDigits: 6,
        name: "Tether USD",
        symbol: "USD₮",
        verification: .whitelist,
        imageURL: nil
    )

    /// TRX pays TRON USDT and TON a jetton the engine knows to carry no payload of its own: a mintless
    /// jetton's claim, which chain-kit never attaches, keeps the engine, and so does an engine not known yet.
    func test_TRXPaysTronUSDTAndTONAJettonWithoutAPayloadOfItsOwn() {
        XCTAssertEqual(Controller.operationPaidMethod(for: .tronUSDT(tronAddress: "T"), jettonCarriesCustomPayload: nil), .trx)
        XCTAssertEqual(Controller.operationPaidMethod(for: .tonJetton(master: "0:aa"), jettonCarriesCustomPayload: false), .ton)
        XCTAssertNil(Controller.operationPaidMethod(for: .tonJetton(master: "0:aa"), jettonCarriesCustomPayload: true))
        XCTAssertNil(Controller.operationPaidMethod(for: .tonJetton(master: "0:aa"), jettonCarriesCustomPayload: nil))
        for engine: MultichainFeeEngineResolver.Engine in [.tonCoin, .chainKit, .evm(chain: .eth)] {
            XCTAssertNil(Controller.operationPaidMethod(for: engine, jettonCarriesCustomPayload: false), "\(engine)")
        }
    }

    /// The coin's option is listed at chain-kit's fee, and left out when chain-kit priced no operation for
    /// it; the relayer's options stay as the engine priced them.
    func test_theCoinsOptionIsListedAtChainKitsFeeOrLeftOut() throws {
        let options = [
            Option(type: .battery, value: .battery(charges: 10, excess: nil)),
            Option(type: .default, value: .default(amount: 70_000_000)),
            Option(type: .gasless(token: Self.usdt), value: .gasless(token: Self.usdt, amount: 1)),
        ]

        let priced = try OperationPaidMethod.ton.pricing(options, as: emulation(fee: 500_000, operation: tonOperation(attaching: 80_000_001)))
        let unpriced = OperationPaidMethod.ton.pricing(options, as: nil)

        XCTAssertEqual(priced.map(\.type), options.map(\.type))
        guard case let .default(fee) = priced[1].value, case let .battery(charges, _) = priced[0].value else {
            return XCTFail("expected TON at chain-kit's fee beside the charges, got \(priced)")
        }
        XCTAssertEqual(fee, 500_000)
        XCTAssertEqual(charges, 10)
        XCTAssertEqual(unpriced.map(\.type), [.battery, .gasless(token: Self.usdt)])

        let trx = TronUSDTFeeOptionsResolver.trxFeeToken
        let trxPriced = try OperationPaidMethod.trx.pricing(
            [Option(type: .gasless(token: trx), value: .gasless(token: trx, amount: 9_000_000)), Option(type: .battery, value: .battery(charges: 3, excess: nil))],
            as: emulation(fee: 21000, operation: tonOperation(attaching: 0))
        )
        guard case let .gasless(_, trxFee) = trxPriced[0].value else {
            return XCTFail("expected TRX at chain-kit's fee, got \(trxPriced)")
        }
        XCTAssertEqual(trxFee, 21000)
        XCTAssertEqual(trxPriced.count, 2)
    }

    /// The coin's method is offered only while chain-kit priced an operation for it to sign; the relayer's
    /// methods are offered either way.
    func test_theCoinsMethodIsOfferedOnlyWithAnOperationToSign() throws {
        let trx = TronUSDTFeeOptionsResolver.trxFeeToken
        let tonTypes: [TransactionConfirmationModel.ExtraType] = [.default, .battery, .gasless(token: Self.usdt)]
        let tronTypes: [TransactionConfirmationModel.ExtraType] = [.battery, .gasless(token: trx)]

        let priced = try OperationPaidMethod.ton.available(tonTypes, as: emulation(fee: 500_000, operation: tonOperation(attaching: 80_000_001)))
        let unpriced = OperationPaidMethod.ton.available(tonTypes, as: nil)
        let sdkPriced = MultichainTransactionEmulationResult(
            fee: 500_000,
            asset: MultichainAssetDetails(assetId: "ton/mainnet/coin", name: "Toncoin", symbol: "TON", decimals: 9, image: "")
        )
        let operationless = OperationPaidMethod.ton.available(tonTypes, as: sdkPriced)

        XCTAssertEqual(priced, tonTypes)
        XCTAssertEqual(unpriced, [.battery, .gasless(token: Self.usdt)])
        XCTAssertEqual(operationless, [.battery, .gasless(token: Self.usdt)])
        XCTAssertEqual(OperationPaidMethod.trx.available(tronTypes, as: nil), [.battery])
    }

    /// A send left without the coin's method tries the methods the wallet can pay with first, and the ones
    /// it cannot pay with only after them, so that one that fails to price passes the send on to the next.
    func test_aSendWithoutTheCoinsMethodMovesToOneTheWalletCanPayWith() {
        let short = Option(type: .battery, value: .battery(charges: 10, excess: nil), isInsufficient: true)
        let payable = Option(type: .gasless(token: Self.usdt), value: .gasless(token: Self.usdt, amount: 1))
        let trx = TronUSDTFeeOptionsResolver.trxFeeToken
        let alsoPayable = Option(type: .gasless(token: trx), value: .gasless(token: trx, amount: 1))

        XCTAssertEqual(Controller.fallbackFeeMethods(in: [short, payable]), [.gasless(token: Self.usdt), .battery])
        XCTAssertEqual(Controller.fallbackFeeMethods(in: [payable, short]), [.gasless(token: Self.usdt), .battery])
        XCTAssertEqual(
            Controller.fallbackFeeMethods(in: [short, alsoPayable, payable]),
            [.gasless(token: trx), .gasless(token: Self.usdt), .battery]
        )
        XCTAssertEqual(Controller.fallbackFeeMethods(in: [short]), [.battery])
        XCTAssertEqual(Controller.fallbackFeeMethods(in: []), [])
    }

    /// A jetton's operation attaches its TON to the sender's jetton wallet, which the wallet must hold
    /// beside the fee; an operation that sends no TON attaches nothing known.
    func test_aJettonsOperationLeavesTheWalletToHoldTheTONItAttaches() throws {
        XCTAssertEqual(try tonOperation(attaching: 80_000_001).attachedTON, 80_000_001)
        XCTAssertNil(try operation(payloads: []).attachedTON)
    }

    /// A wallet that holds the fee but not the TON the operation attaches cannot pay with TON: the action
    /// would fail and the wallet pay the fee for nothing.
    func test_aWalletShortOfTheAttachedTONCannotPayWithTON() {
        let selection = MultichainFeeSelection(engine: .tonJetton(master: "0:aa"), transferAmount: 1)
        let options = [Option(type: .default, value: .default(amount: 500_000))]

        let short = selection.annotatingInsufficiency(options, balances: balances(ton: 60_000_000, attaching: 80_000_001))
        let enough = selection.annotatingInsufficiency(options, balances: balances(ton: 80_500_001, attaching: 80_000_001))

        XCTAssertEqual(short.map(\.isInsufficient), [true])
        XCTAssertEqual(enough.map(\.isInsufficient), [false])
    }
}

private extension MultichainOperationPaidMethodTests {
    func balances(ton: BigUInt, attaching attached: BigUInt) -> MultichainFeeBalances {
        MultichainFeeBalances(batteryCharges: .unknown, ton: ton, trx: nil, jettonForwardAmount: attached)
    }

    func emulation(fee: BigUInt, operation: PricedOperation) -> MultichainTransactionEmulationResult {
        MultichainTransactionEmulationResult(
            fee: fee,
            asset: MultichainAssetDetails(assetId: "ton/mainnet/coin", name: "Toncoin", symbol: "TON", decimals: 9, image: ""),
            adjustedAmount: nil,
            isMaxAmount: false,
            isInsufficientBalance: false,
            review: nil,
            operation: operation
        )
    }

    /// A TON `main` attaching `value` to the sender's jetton wallet, as chain-kit's jetton transfer does.
    func tonOperation(attaching value: Int64) throws -> PricedOperation {
        let ton = MultichainChain.ton.asChainKitChain
        let wallet = try XCTUnwrap(ChainKit.Address.Companion.shared.from(value: Self.tonRecipient, chain: ton, type: .default_))
        let meta = PayloadMetaTonMain(
            to: wallet,
            value: BignumBigInteger(long: value),
            body: nil,
            bounce: nil,
            mode: nil,
            stateInit: nil,
            expireAt: nil,
            comment: nil,
            token: nil
        )
        return try operation(payloads: [
            ChainKit.Payload(id: "main", type: .main, chain: ton, version: ChainKit.Payload.Companion.shared.VERSION, fee: nil, meta: meta),
        ])
    }

    func operation(payloads: [ChainKit.Payload]) throws -> PricedOperation {
        let ton = MultichainChain.ton.asChainKitChain
        let account = try ChainKit.Account(
            address: XCTUnwrap(ChainKit.Address.Companion.shared.from(value: Self.tonRecipient, chain: ton, type: .default_)),
            asset: ton.toAsset(),
            derivation: DerivationDefaultPath.shared,
            publicKey: nil
        )
        return PricedOperation(
            signable: SignableOperation(
                operation: ChainKit.Operation.Companion.shared.build(id: "transfer", payloads: payloads),
                account: account,
                intent: .dapp,
                fidelity: .exact
            ),
            fee: FeeNone(asset: ton.toAsset())
        )
    }
}
