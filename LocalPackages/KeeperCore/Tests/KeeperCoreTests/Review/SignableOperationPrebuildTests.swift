import ChainKit
import CryptoKit
@testable import KeeperCore
import KeeperCoreComponents
import TonSwift
import TronSwift
import XCTest

/// The `prebuild` payloads the TON and TRON flows are reviewed as: what chain-kit reads in them has
/// to be the very bytes the wallet signs.
final class SignableOperationPrebuildTests: XCTestCase {
    func test_aTronPrebuildIsTheExtendedTransactionUnderTheHashOfItsBytes() throws {
        let built = try XCTUnwrap(TronSwift.Transaction(json: Fixture.tronTransaction))
        let extended = try built.extendingExpiration(byMilliseconds: 600_000)

        let signable = try SignableOperation.tronPrebuild(extended, account: tronAccount(), intent: Fixture.intent)

        let rawData = try XCTUnwrap(Data(strictHex: extended.rawDataHex))
        XCTAssertEqual(extended.txID, hex(Data(SHA256.hash(data: rawData))))
        XCTAssertNotEqual(extended.txID, built.txID)
        XCTAssertEqual(signable.operation.id, extended.txID)
        XCTAssertEqual(signable.fidelity, .exactWrap)
        let payload = try XCTUnwrap(signable.operation.payloads.first)
        XCTAssertEqual(payload.type, Payload.Type_.prebuild)
        let prebuild = try XCTUnwrap(payload.meta as? PayloadMetaTronPrebuild)
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(prebuild.data.utf8)) as? [String: Any])
        XCTAssertEqual(document["txID"] as? String, extended.txID)
        XCTAssertEqual(document["raw_data_hex"] as? String, extended.rawDataHex)
        XCTAssertEqual((document["raw_data"] as? [String: Any])?["expiration"] as? Int64, Fixture.tronExpiration + 600_000)
    }

    /// The review id reads the operation's JSON, so the same transaction has to write the same JSON.
    func test_theSameTronTransactionIsTheSameOperation() throws {
        let extended = try XCTUnwrap(TronSwift.Transaction(json: Fixture.tronTransaction)).extendingExpiration(byMilliseconds: 600_000)

        let first = try SignableOperation.tronPrebuild(extended, account: tronAccount(), intent: Fixture.intent)
        let second = try SignableOperation.tronPrebuild(extended, account: tronAccount(), intent: Fixture.intent)

        XCTAssertEqual(first.operation.meta, second.operation.meta)
    }

    /// chain-kit tells the two apart by the first 32 bits: a W5 request opens with its signed
    /// prefix, a v4R2 one with its subwallet id.
    func test_aV4R2AndAW5RequestAreBothReadAsTheExtMsgTheyAre() async throws {
        let cases: [(version: WalletContractVersion, messageType: TonSwift.MessageType, name: String, head: UInt64)] = [
            (.v4R2, .ext, "v4r2", 698_983_191),
            (.v5R1, .int, "v5r1", UInt64(OpCodes.SIGNED_INTERNAL)),
        ]
        for (version, messageType, name, head) in cases {
            let wallet = Fixture.tonWallet(version)
            let transfer = try await UnsignedTransferBuilder(transferData: Fixture.tonTransfer(from: wallet, messageType: messageType))
                .createUnsignedWalletTransfer(wallet: wallet)

            let signable = try SignableOperation.ton(
                SignableOperation.TonRequest(signing: transfer),
                of: wallet,
                account: tonAccount(of: wallet, version: version),
                intent: Fixture.intent,
                fidelity: .exactWrap
            )

            let request = try transfer.signingMessage.endCell()
            XCTAssertEqual(signable.operation.id, try hex(request.hash()), name)
            XCTAssertEqual(signable.fidelity, .exactWrap)
            let prebuild = try XCTUnwrap(signable.operation.payloads.first?.meta as? PayloadMetaTonPrebuild, name)
            XCTAssertEqual(prebuild.format, PayloadMetaTonFormat.extmsg, name)
            XCTAssertEqual(prebuild.walletVersion, name)
            let read = try Cell.fromBase64(src: prebuild.data)
            XCTAssertEqual(try read.hash(), try request.hash(), name)
            XCTAssertEqual(try read.beginParse().loadUint(bits: 32), head, name)
        }
    }

    /// The review id reads the operation's JSON: a request written once reads the same every time,
    /// though TonSwift could write a W5 one, whose out list branches, in more than one order.
    func test_theSameTonRequestIsTheSameOperation() async throws {
        let wallet = Fixture.tonWallet(.v5R1)
        let transfer = try await UnsignedTransferBuilder(transferData: Fixture.tonTransfer(from: wallet, messageType: .int))
            .createUnsignedWalletTransfer(wallet: wallet)
        let request = try SignableOperation.TonRequest(signing: transfer)
        let account = try tonAccount(of: wallet, version: .v5R1)

        let first = try SignableOperation.ton(request, of: wallet, account: account, intent: Fixture.intent, fidelity: .exactWrap)
        let second = try SignableOperation.ton(request, of: wallet, account: account, intent: Fixture.intent, fidelity: .exactWrap)

        XCTAssertEqual(first.operation.meta, second.operation.meta)
    }

    /// chain-kit reads the transaction a prebuild wraps from its bytes, a TRC-20 call or a TRX
    /// transfer alike: held to the address it pays, it finds nothing in it, and a send of it to anyone
    /// else is a payment to another address. The trace's USDT transfer pays its owner itself.
    func test_chainKitReadsWhomTheTronTransactionOfAPrebuildPays() async throws {
        let check = ChainKitValidationCheck(client: CryptoKitClient(
            netModule: ModuleNetModule(
                netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
            )
        ))
        let usdt = MultichainAssetDetails(assetId: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t", name: "Tether USD", symbol: "USDT", decimals: 6, image: "")
        let trx = MultichainAssetDetails(assetId: "tron/mainnet/coin", name: "TRON", symbol: "TRX", decimals: 6, image: "")
        let transfers: [(transaction: [String: Any], asset: MultichainAssetDetails, payee: String)] = [
            (Fixture.tronTransaction, usdt, Fixture.tronOwner),
            (Fixture.trxTransaction, trx, Fixture.trxRecipient),
        ]

        for (transaction, asset, payee) in transfers {
            let extended = try XCTUnwrap(TronSwift.Transaction(json: transaction)).extendingExpiration(byMilliseconds: 600_000)
            let account = try ChainKitOperationSender.account(of: MultichainWalletAddress(chain: .tron, address: Fixture.tronOwner), holding: asset)

            let toPayee = try await check.findings(of: SignableOperation.tronPrebuild(
                extended,
                account: account,
                intent: .send(3_000_000, of: asset, to: payee)
            ))
            let toAnother = try await check.findings(of: SignableOperation.tronPrebuild(
                extended,
                account: account,
                intent: .send(3_000_000, of: asset, to: "TCaxmZvD5kysgFNSqovSpxKKkZdD818cvr")
            ))

            XCTAssertEqual(toPayee, [], asset.symbol)
            XCTAssertEqual(toAnother.map(\.kind), ["ChainKitValidationErrorForeignRecipient"], asset.symbol)
            XCTAssertEqual(toAnother.map(\.severity), [.danger], asset.symbol)
        }
    }

    /// chain-kit would read the request of any other wallet as a v4R2 one.
    func test_aWalletChainKitCannotReadIsNotReviewedAsAnother() async throws {
        let wallet = Fixture.tonWallet(.v3R2)
        let transfer = try await UnsignedTransferBuilder(transferData: Fixture.tonTransfer(from: wallet, messageType: .ext))
            .createUnsignedWalletTransfer(wallet: wallet)

        XCTAssertThrowsError(try SignableOperation.ton(
            SignableOperation.TonRequest(signing: transfer),
            of: wallet,
            account: tonAccount(of: wallet, version: .v4R2),
            intent: Fixture.intent,
            fidelity: .converted
        )) { error in
            XCTAssertEqual(error as? ChainKitOperationError, .unsupportedAccount("ton v3R2"))
        }
    }
}

private extension SignableOperationPrebuildTests {
    func hex(_ data: Data) -> String {
        data.map { String(format: "%02hhx", $0) }.joined()
    }

    func tronAccount() throws -> ChainKit.Account {
        let usdt = try XCTUnwrap(AssetCompanion.shared.fromString(
            assetId: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t",
            name: "Tether USD",
            symbol: "USDT",
            decimals: 6
        ))
        return try ChainKitOperationSender.account(
            of: MultichainWalletAddress(chain: .tron, address: "TVdW9qX4kyXb9jFoUwXJswtEqKHdn85AVd"),
            asset: usdt
        )
    }

    func tonAccount(of wallet: Wallet, version: WalletContractVersion) throws -> ChainKit.Account {
        try ChainKitOperationSender.account(
            of: MultichainWalletAddress(
                chain: .ton,
                address: wallet.friendlyAddress.toString(),
                type: version == .v5R1 ? .tonV5R1 : .tonV4R2,
                publicKey: MultichainPublicKey(defaultHex: "0x" + hex(wallet.publicKey.data), segWit: "")
            ),
            asset: nil
        )
    }
}

private enum Fixture {
    static let intent = OperationIntent.wallet(
        spending: [OperationIntent.Spend(assetId: "tron/mainnet/trc20/TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t", symbol: "USDT", decimals: 6, amount: 3_000_000)],
        to: nil
    )

    static let tronExpiration: Int64 = 1_786_060_362_000

    /// The USDT transfer of the TK-2909 trace, as a node answers it: 3 USDT to the sender itself.
    static let tronTransaction: [String: Any] = [
        "txID": "6dc40f865e84d01ffeb4a8648614073e7e5d9bf21dd3748f23ed9ddceb861677",
        "raw_data_hex": "0a02f96c2208f0006781f475a6424090a2f9cbfd335aae01081f12a9010a31747970652e676f6f676c65617069732e636f6d2f70726f746f636f6c2e54726967676572536d617274436f6e747261637412740a15416bda46f57114c4c3a2617c2ad3b1722d81360df4121541a614f803b6fd780986a42c78ec9c7f77e6ded13c2244a9059cbb0000000000000000000000006bda46f57114c4c3a2617c2ad3b1722d81360df400000000000000000000000000000000000000000000000000000000002dc6c070fb88d1cbfd33900180a3c347",
        "raw_data": [
            "ref_block_bytes": "f96c",
            "ref_block_hash": "f0006781f475a642",
            "expiration": tronExpiration,
            "timestamp": Int64(1_786_060_302_331),
            "fee_limit": Int64(150_000_000),
            "contract": [["type": "TriggerSmartContract"]],
        ],
        "visible": false,
    ]

    static let tronOwner = "TKoUnkRBggFPbbsPnXqdnbjfVzRhDfnhoc"
    static let trxRecipient = "TU1r33n75FL5dShBt13xcJfgBLuahLgTZo"

    /// A transfer of 3 TRX from the trace's owner to `trxRecipient`, as a node answers it.
    static let trxTransaction: [String: Any] = [
        "txID": "1778a7c51ca6a465fc74730407e77c24c07ce0548a9ed5c69421cb657344451d",
        "raw_data_hex": "0a02f96c2208f0006781f475a6424090a2f9cbfd335a68080112640a2d747970652e676f6f676c65617069732e636f6d2f70726f746f636f6c2e5472616e73666572436f6e747261637412330a15416bda46f57114c4c3a2617c2ad3b1722d81360df4121541c5f202be12eacb33530e88a6915e7dbb1276704118c08db70170fbcff5cbfd33",
        "raw_data": [
            "ref_block_bytes": "f96c",
            "ref_block_hash": "f0006781f475a642",
            "expiration": tronExpiration,
            "timestamp": Int64(1_786_060_302_331),
            "contract": [["type": "TransferContract"]],
        ],
        "visible": false,
    ]

    static func tonWallet(_ version: WalletContractVersion) -> Wallet {
        Wallet(
            id: "prebuild-\(version.rawValue)",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 7, count: 32)), version)),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings()
        )
    }

    static func tonTransfer(from wallet: Wallet, messageType: TonSwift.MessageType) throws -> TransferData {
        try TransferData(
            transfer: .ton(TransferData.Ton(
                amount: 1_000_000_000,
                isMax: false,
                recipient: Address.parse("0:0000000000000000000000000000000000000000000000000000000000000001"),
                comment: nil
            )),
            wallet: wallet,
            messageType: messageType,
            seqno: 7,
            timeout: 1_790_000_600
        )
    }
}
