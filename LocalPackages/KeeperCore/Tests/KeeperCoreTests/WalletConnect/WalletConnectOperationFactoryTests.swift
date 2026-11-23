@preconcurrency import AnyCodable
import ChainKit
@testable import KeeperCore
import TonSwift
import XCTest

/// What the gate reads a dApp's request as: the very call, message or transaction its signer signs,
/// under the request's id and from the account of the address that signs it.
final class WalletConnectOperationFactoryTests: XCTestCase {
    private static let evmAddress = "0x9858effd232b4033e47d90003d41ec34ecaeda94"
    private static let recipient = "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    private static let callData = "0xa9059cbb000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb0000000000000000000000000000000000000000000000000000000000000001"
    private static let tronAddress = "TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t"
    private static let solanaAddress = "9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM"
    private static let evmKey = MultichainPublicKey(defaultHex: "0x0237b0bb7a8288d38ed49a524b5dc98cff3eb5ca824c9f9dc0dfdb3d9cd600f299", segWit: "")
    /// The hash of the `raw_data_hex` `0a02`.
    private static let tronTxID = "ad406961a6518e07ac4e40031f9e4e0486f443208da45ef02e336c3d4a0a50bb"

    func test_anEVMTransactionIsReviewedAsTheCallItIsSignedAs() throws {
        let utilities = WalletConnectEVMTransactionSigningUtilities()
        for (method, send) in [(KeeperCore.WalletConnectMethod.ethSendTransaction, true), (.ethSignTransaction, false)] {
            for data in ["", "0x", "  ", " 0x", "0x\n", Self.callData, " \(Self.callData)\n"] {
                let transaction = evmTransaction(data: data)
                let request = request(method, chain: .eth, payload: .evmTransaction(transaction, send: send))

                let signable = try XCTUnwrap(WalletConnectOperationFactory.signables(of: request, wallet: wallet()).first)

                let label = "\(method.rawValue) data \(data.debugDescription)"
                let payload = try XCTUnwrap(signable.operation.payloads.first, label)
                XCTAssertEqual(payload.type, Payload.Type_.main, label)
                let main = try XCTUnwrap(payload.meta as? PayloadMetaEvmMain, label)
                XCTAssertEqual(main.to.display.lowercased(), Self.recipient, label)
                XCTAssertEqual(main.value.description, "1000", label)
                XCTAssertNil(main.gas, label)
                XCTAssertNil(main.authorization, label)
                let signed = try utilities.chainKitTransaction(account: signable.account, chain: .eth, payload: transaction)
                XCTAssertEqual(main.data, (signed as? TransactionCall)?.data, label)
                XCTAssertEqual(main.data == nil, signed is TransactionTransfer, label)
            }
        }
    }

    func test_everyRequestIsReadFromTheCoinAccountOfTheAddressThatSignsIt() throws {
        let requests: [(WalletConnectSessionRequest, address: String)] = [
            (request(.ethSendTransaction, chain: .eth, payload: .evmTransaction(evmTransaction(data: "0x"), send: true)), Self.evmAddress),
            (request(.personalSign, chain: .eth, payload: .signMessage(.init(address: nil, message: "Hello", kind: .personal))), Self.evmAddress),
            (request(.tronSignMessage, chain: .tron, payload: .signMessage(.init(address: nil, message: "hello", kind: .tron))), Self.tronAddress),
            (request(.solanaSignMessage, chain: .sol, payload: .signMessage(.init(address: nil, message: "3yZe7d", kind: .solana))), Self.solanaAddress),
            (request(.solanaSignTransaction, chain: .sol, payload: .solanaTransaction(.init(pubkey: nil, transaction: "AQID"), send: false)), Self.solanaAddress),
        ]
        for (request, address) in requests {
            let signables = try WalletConnectOperationFactory.signables(of: request, wallet: wallet())

            let signable = try XCTUnwrap(signables.first, request.method.rawValue)
            XCTAssertEqual(signables.count, 1, request.method.rawValue)
            XCTAssertEqual(signable.operation.id, request.id, request.method.rawValue)
            XCTAssertEqual(signable.fidelity, .exactWrap, request.method.rawValue)
            XCTAssertEqual(signable.intent, .dapp, request.method.rawValue)
            XCTAssertEqual(signable.account.addressDisplay.lowercased(), address.lowercased(), request.method.rawValue)
            XCTAssertEqual(signable.account.asset.id, request.chain.multichainChain.asChainKitChain.toAsset().id, request.method.rawValue)
        }
        let evm = try XCTUnwrap(WalletConnectOperationFactory.signables(of: requests[0].0, wallet: wallet()).first)
        XCTAssertEqual(evm.account.publicKey?.defaultHex, Self.evmKey.defaultHex)
    }

    func test_aMessageIsReviewedAsWhatItsSignerSigns() throws {
        let typedData = try WalletConnectEthSignTypedDataV4Parser().canonicalTypedData(
            #"{"types":{"EIP712Domain":[{"name":"name","type":"string"}],"Mail":[{"name":"body","type":"string"}]},"primaryType":"Mail","domain":{"name":"dApp"},"message":{"body":"hi"}}"#,
            chain: .eth
        )

        let typed = try meta(of: request(.ethSignTypedDataV4, chain: .eth, payload: .signMessage(.init(address: nil, message: typedData, kind: .typedDataV4))))
        let tron = try meta(of: request(.tronSignMessage, chain: .tron, payload: .signMessage(.init(address: nil, message: "hello", kind: .tron))))
        let solana = try meta(of: request(.solanaSignMessage, chain: .sol, payload: .signMessage(.init(address: nil, message: "3yZe7d", kind: .solana))))

        XCTAssertEqual(typed.type, Payload.Type_.messageeip712)
        XCTAssertEqual((typed.meta as? PayloadMetaEvmTypedMessage)?.typedData, typedData)
        XCTAssertEqual((typed.meta as? PayloadMetaEvmTypedMessage)?.eip155, false)
        XCTAssertEqual(tron.type, Payload.Type_.messageplain)
        XCTAssertEqual((tron.meta as? PayloadMetaTronPlainMessage)?.message, "hello")
        XCTAssertEqual(solana.type, Payload.Type_.messageplain)
        XCTAssertEqual((solana.meta as? PayloadMetaSolanaPlainMessage)?.message, "3yZe7d")
    }

    /// WalletCore drops every leading `0x` and signs hex as the bytes it spells, anything else as its
    /// UTF-8, while chain-kit reads only `0x` hex as bytes: each spelling is reviewed as `0x` hex of
    /// what WalletCore signs.
    func test_aPersonalMessageIsReviewedAsTheBytesItsSignersSign() async throws {
        let wallet = try CryptoWallet.Companion.shared.fromMnemonic(
            mnemonic_: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        )
        let hash = String(repeating: "ab", count: 32)
        let spellings = [
            ("Hello", "0x48656c6c6f"),
            ("deadbeef", "0xdeadbeef"),
            ("0x48656c6c6f", "0x48656c6c6f"),
            ("48656c6c6f", "0x48656c6c6f"),
            ("0x48656C6C6F", "0x48656c6c6f"),
            ("0x0x48656c6c6f", "0x48656c6c6f"),
            ("0x0x\(hash)", "0x\(hash)"),
            ("0x0xHello", "0x3078307848656c6c6f"),
        ]
        for (spelling, reviewedMessage) in spellings {
            let payload = try meta(of: request(.personalSign, chain: .eth, payload: .signMessage(.init(address: nil, message: spelling, kind: .personal))))

            let plain = try XCTUnwrap(payload.meta as? PayloadMetaEvmPlainMessage, spelling)
            XCTAssertEqual(payload.type, Payload.Type_.messageplain, spelling)
            XCTAssertEqual(plain.message, reviewedMessage, spelling)
            XCTAssertFalse(plain.eip155, spelling)
            let signed = try await personalSignature(of: spelling, by: wallet)
            let reviewed = try await personalSignature(of: plain.message, by: wallet)
            XCTAssertEqual(signed, reviewed, spelling)
        }
    }

    func test_eachSolanaTransactionIsAPrebuildOfTheRequest() throws {
        let transactions = ["AQID", "BAUG", "BwgJ"]
        let single = try XCTUnwrap(WalletConnectOperationFactory.signables(
            of: request(.solanaSignAndSendTransaction, chain: .sol, payload: .solanaTransaction(.init(pubkey: nil, transaction: "AQID"), send: true)),
            wallet: wallet()
        ).first)
        let batch = try WalletConnectOperationFactory.signables(
            of: request(.solanaSignAllTransactions, chain: .sol, payload: .solanaTransactionBatch(.init(pubkey: nil, transactions: transactions))),
            wallet: wallet()
        )

        XCTAssertEqual(single.operation.payloads.map(\.type), [Payload.Type_.prebuild])
        XCTAssertEqual(single.operation.payloads.compactMap { ($0.meta as? PayloadMetaSolanaPrebuild)?.data }, ["AQID"])
        let all = try XCTUnwrap(batch.first)
        XCTAssertEqual(batch.count, 1)
        XCTAssertEqual(all.operation.id, "request")
        XCTAssertEqual(all.operation.payloads.map(\.type), Array(repeating: Payload.Type_.prebuild, count: 3))
        XCTAssertEqual(all.operation.payloads.compactMap { ($0.meta as? PayloadMetaSolanaPrebuild)?.data }, transactions)
        XCTAssertEqual(all.operation.payloads.map(\.id), ["request/0", "request/1", "request/2"])
    }

    func test_aTronTransactionIsAPrebuildUnderTheHashOfItsBytes() throws {
        let cases = [
            #"{"address":"\#(Self.tronAddress)","transaction":{"visible":false,"raw_data":{"timestamp":1756201512720},"raw_data_hex":"0a02"}}"#,
            #"{"transaction":{"transaction":{"raw_data_hex":"0a02","txID":"\#(Self.tronTxID.uppercased())"}}}"#,
        ]
        for params in cases {
            let parsed = try WalletConnectMethodParser().parse(method: "tron_signTransaction", chain: WalletConnectChain.tron.caip2, paramsJSON: params)

            let signable = try XCTUnwrap(WalletConnectOperationFactory.signables(
                of: request(parsed.method, chain: parsed.chain, payload: parsed.payload),
                wallet: wallet()
            ).first)

            XCTAssertEqual(signable.operation.id, Self.tronTxID, params)
            XCTAssertEqual(signable.fidelity, .exactWrap, params)
            XCTAssertEqual(signable.intent, .dapp, params)
            XCTAssertEqual(signable.account.addressDisplay, Self.tronAddress, params)
            let prebuild = try XCTUnwrap(signable.operation.payloads.first?.meta as? PayloadMetaTronPrebuild, params)
            let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(prebuild.data.utf8)) as? [String: Any], params)
            XCTAssertEqual(document["txID"] as? String, Self.tronTxID, params)
            XCTAssertEqual(document["raw_data_hex"] as? String, "0a02", params)
        }
    }

    /// The review id reads the operation's JSON, so the same request has to write the same JSON.
    func test_theSameRequestIsTheSameOperation() throws {
        let request = request(.ethSendTransaction, chain: .eth, payload: .evmTransaction(evmTransaction(data: Self.callData), send: true))

        let first = try XCTUnwrap(WalletConnectOperationFactory.signables(of: request, wallet: wallet()).first)
        let second = try XCTUnwrap(WalletConnectOperationFactory.signables(of: request, wallet: wallet()).first)

        XCTAssertEqual(first.operation.id, second.operation.id)
        XCTAssertEqual(first.operation.meta, second.operation.meta)
    }

    func test_aRequestThatCannotBeReadIsAnErrorNotACrash() {
        let malformed: [WalletConnectSessionRequest] = [
            request(.ethSendTransaction, chain: .eth, payload: .evmTransaction(evmTransaction(data: "0x", to: nil), send: true)),
            request(.ethSendTransaction, chain: .eth, payload: .evmTransaction(evmTransaction(data: "0x", to: "0xnot-an-address"), send: true)),
            request(.ethSendTransaction, chain: .eth, payload: .evmTransaction(evmTransaction(data: "0x", value: "1000"), send: true)),
            request(.tronSignTransaction, chain: .tron, payload: .tronTransaction(.init(address: nil, transactionJSON: AnyCodable("0a02"), rawDataHex: "0a02", txID: nil))),
            request(.tronSignTransaction, chain: .tron, payload: .tronTransaction(.init(address: nil, transactionJSON: AnyCodable(["visible": false]), rawDataHex: nil, txID: nil))),
            request(.tronSignTransaction, chain: .tron, payload: .tronTransaction(.init(address: nil, transactionJSON: AnyCodable(["raw_data_hex": "0a0"]), rawDataHex: "0a0", txID: nil))),
            request(.tronSignTransaction, chain: .tron, payload: .tronTransaction(.init(address: nil, transactionJSON: AnyCodable(["raw_data": Date()]), rawDataHex: "0a02", txID: nil))),
            request(.solanaSignMessage, chain: .sol, payload: .signMessage(.init(address: nil, message: " ", kind: .solana))),
            request(.solanaSignTransaction, chain: .sol, payload: .solanaTransaction(.init(pubkey: nil, transaction: ""), send: false)),
        ]
        for request in malformed {
            XCTAssertThrowsError(try WalletConnectOperationFactory.signables(of: request, wallet: wallet()), "\(request.payload)")
        }
    }

    func test_aRequestNoSignerSignsHasNothingToReview() throws {
        let unsigned: [(WalletConnectSessionRequest, KeeperCore.Wallet)] = [
            (request(.tonSendMessage, chain: .ton, payload: .tonSendMessage(.init(from: nil, messagesCount: 1, rawParamsJSON: "{}"))), wallet()),
            (request(.tonSignData, chain: .ton, payload: .tonSignData(.init(address: nil, payload: .text("hi"), rawParamsJSON: "{}"))), wallet()),
            (request(.solanaSignMessage, chain: .sol, payload: .signMessage(.init(address: nil, message: "3yZe7d", kind: .solana))), ledgerWallet()),
            (request(.walletSwitchEthereumChain, chain: .eth, payload: .switchEthereumChain(.base)), wallet()),
            (request(.solanaGetAccounts, chain: .sol, payload: .solanaAccounts), wallet()),
        ]
        for (request, wallet) in unsigned {
            XCTAssertEqual(try WalletConnectOperationFactory.signables(of: request, wallet: wallet).count, 0, request.method.rawValue)
        }
        let ledgerTransaction = request(.solanaSignTransaction, chain: .sol, payload: .solanaTransaction(.init(pubkey: nil, transaction: "AQID"), send: false))
        XCTAssertEqual(try WalletConnectOperationFactory.signables(of: ledgerTransaction, wallet: ledgerWallet()).count, 1)
    }
}

private extension WalletConnectOperationFactoryTests {
    func personalSignature(of message: String, by wallet: MnemonicWallet) async throws -> String {
        let client = CryptoKitClient(
            netModule: ModuleNetModule(
                netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
            )
        )
        return try await WalletConnectChainKitMessageSigningUtilities().sign(client: client, chain: .eth, cryptoWallet: wallet, message: message, kind: .personal)
    }

    func meta(of request: WalletConnectSessionRequest) throws -> Payload {
        let signable = try XCTUnwrap(WalletConnectOperationFactory.signables(of: request, wallet: wallet()).first, request.method.rawValue)
        return try XCTUnwrap(signable.operation.payloads.first, request.method.rawValue)
    }

    func request(
        _ method: KeeperCore.WalletConnectMethod,
        chain: WalletConnectChain,
        payload: WalletConnectRequestPayload
    ) -> WalletConnectSessionRequest {
        WalletConnectSessionRequest(
            id: "request",
            topic: "topic",
            chain: chain,
            method: method,
            dapp: WalletConnectDapp(name: "dApp", url: "https://example.com", description: "", iconURL: nil),
            payload: payload,
            source: nil,
            walletId: "wallet"
        )
    }

    func evmTransaction(data: String, to: String? = WalletConnectOperationFactoryTests.recipient, value: String = "0x3e8") -> WalletConnectEVMTransaction {
        WalletConnectEVMTransaction(
            from: Self.evmAddress,
            to: to,
            data: data,
            value: value,
            nonce: "0x0",
            gas: "0x5208",
            gasPrice: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil
        )
    }

    func wallet() -> KeeperCore.Wallet {
        makeWallet(kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1))
    }

    func ledgerWallet() -> KeeperCore.Wallet {
        makeWallet(kind: .Ledger(
            TonSwift.PublicKey(data: Data(repeating: 1, count: 32)),
            .v4R2,
            KeeperCore.Wallet.LedgerDevice(deviceId: "device", deviceModel: "Ledger Stax", accountIndex: 0)
        ))
    }

    func makeWallet(kind: KeeperCore.WalletKind) -> KeeperCore.Wallet {
        KeeperCore.Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: kind),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(
                walletId: "wallet",
                addresses: [
                    MultichainWalletAddress(chain: .eth, address: Self.evmAddress, publicKey: Self.evmKey),
                    MultichainWalletAddress(chain: .tron, address: Self.tronAddress),
                    MultichainWalletAddress(chain: .sol, address: Self.solanaAddress),
                ],
                syncState: .synced
            ))
        )
    }
}
