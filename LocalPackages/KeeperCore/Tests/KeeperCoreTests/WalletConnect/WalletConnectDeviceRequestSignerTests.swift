@preconcurrency import AnyCodable
import ChainKit
import CryptoKit
@testable import KeeperCore
@testable import KeeperCoreComponents
import KeeperCoreSensitive
import TonSwift
import WalletCore
import WalletCoreSwiftProtobuf
import XCTest

final class WalletConnectDeviceRequestSignerTests: XCTestCase {
    private static let evmKey = WalletCore.PrivateKey(data: Data(repeating: 0x11, count: 32))!
    private static let tronKey = WalletCore.PrivateKey(data: Data(repeating: 0x12, count: 32))!
    private static let solanaKey = WalletCore.PrivateKey(data: Data(repeating: 0x13, count: 32))!

    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    func testExpiryWhileTheDeviceIsSigningDiscardsItsSignature() async {
        await assertDeviceInterrupted(expire: true)
    }

    func testCancellationWhileTheDeviceIsSigningDiscardsAStillPendingSignature() async {
        await assertDeviceInterrupted(expire: false)
    }

    func testAnExpiredSolanaBatchDoesNotAskTheDeviceForTheNextSignature() async {
        let pending = PendingRequest()
        let recorder = Recorder(onSign: { await pending.end() })
        let solanaKey = Self.solanaKey.getPublicKeyEd25519().data
        let message = Data([1, 0, 1, 2]) + solanaKey + Data(repeating: 0xCC, count: 32) + Data(repeating: 0x01, count: 32) + Data([0])
        let wire = (Data([1]) + Data(count: 64) + message).base64EncodedString()

        do {
            _ = try await sign(
                .solanaSignAllTransactions, chain: .sol,
                payload: .solanaTransactionBatch(.init(pubkey: Self.solanaAddress, transactions: [wire, wire])),
                recorder: recorder, isPending: { await pending.isPending }
            )
            XCTFail("an expired batch must not return any signed transactions")
        } catch {
            XCTAssertEqual(error, .canceled)
        }
        let messages = await recorder.solanaMessages
        XCTAssertEqual(messages.count, 1)
    }

    func testAPersonalMessageInHexIsSignedAsItsBytes() async throws {
        let recorder = Recorder()

        let response = try await sign(.personalSign, payload: .signMessage(.init(address: Self.evmAddress, message: "0x48656c6c6f", kind: .personal)), recorder: recorder)

        let messages = await recorder.messages
        XCTAssertEqual(messages, [Data("Hello".utf8)])
        guard case let .string(signature) = response else {
            return XCTFail("\(response)")
        }
        XCTAssertTrue(EthereumMessageSigner.verifyMessage(pubKey: Self.evmKey.getPublicKeySecp256k1(compressed: false), message: "0x48656c6c6f", signature: signature))
    }

    func testAPersonalMessageInTextIsSignedAsItsUTF8() async throws {
        let recorder = Recorder()

        _ = try await sign(.personalSign, payload: .signMessage(.init(address: Self.evmAddress, message: "Sign in to Earn", kind: .personal)), recorder: recorder)

        let messages = await recorder.messages
        XCTAssertEqual(messages, [Data("Sign in to Earn".utf8)])
    }

    func testAMessageSignedByAnotherSeedIsRefused() async throws {
        let other = try XCTUnwrap(WalletCore.PrivateKey(data: Data(repeating: 0x21, count: 32)))

        do {
            _ = try await sign(.personalSign, payload: .signMessage(.init(address: Self.evmAddress, message: "Hello", kind: .personal)), recorder: Recorder(evmKey: other))
            XCTFail("A signature by another key must not reach the dApp")
        } catch {
            guard case .failedToSign = error else {
                return XCTFail("\(error)")
            }
        }
    }

    func testTypedDataGoesToTheDeviceAsItsTwoHashes() async throws {
        let recorder = Recorder()
        let json = """
        {"domain":{"chainId":1,"name":"Ether Mail","verifyingContract":"0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC","version":"1"},\
        "message":{"contents":"Hello, Bob!","from":{"name":"Cow","wallet":"0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"},\
        "to":{"name":"Bob","wallet":"0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"}},"primaryType":"Mail",\
        "types":{"EIP712Domain":[{"name":"name","type":"string"},{"name":"version","type":"string"},{"name":"chainId","type":"uint256"},\
        {"name":"verifyingContract","type":"address"}],"Mail":[{"name":"from","type":"Person"},{"name":"to","type":"Person"},\
        {"name":"contents","type":"string"}],"Person":[{"name":"name","type":"string"},{"name":"wallet","type":"address"}]}}
        """

        let response = try await sign(.ethSignTypedDataV4, payload: .signMessage(.init(address: Self.evmAddress, message: json, kind: .typedDataV4)), recorder: recorder)

        let hashes = await recorder.typedDataHashes
        XCTAssertEqual(hashes.map { hex($0.0) + hex($0.1) }, [
            "f2cee375fa42b42143804025fc449deafd50cc031ca257e0b194a650a912090f" + "c52c0ee5d84264471806290a3f2c4cecfc5490626bf912d01f240d7a274b371e",
        ])
        guard case let .string(signature) = response else {
            return XCTFail("\(response)")
        }
        XCTAssertEqual(signature, "0x" + hex(Self.messageSignature(Self.evmKey, digest: EthereumAbi.encodeTyped(messageJson: json))))
    }

    func testATronMessageIsSignedAsItsUTF8WithAMessageV() async throws {
        let recorder = Recorder()

        let response = try await sign(.tronSignMessage, chain: .tron, payload: .signMessage(.init(address: Self.tronAddress, message: "hello", kind: .tron)), recorder: recorder)

        let messages = await recorder.tronMessages
        XCTAssertEqual(messages, [Data("hello".utf8)])
        guard case let .object(object) = response, let signature = object["signature"] else {
            return XCTFail("\(response)")
        }
        XCTAssertTrue(["1b", "1c"].contains(String(signature.suffix(2))))
    }

    func testATronTransactionIsAnsweredWithItsIdAndSignature() async throws {
        let rawData = Data([0x0A, 0x02, 0x01, 0x02])
        let transaction = WalletConnectTronTransaction(
            address: Self.tronAddress,
            transactionJSON: AnyCodable(["raw_data_hex": hex(rawData)]),
            rawDataHex: hex(rawData),
            txID: nil
        )

        let response = try await sign(.tronSignTransaction, chain: .tron, payload: .tronTransaction(transaction), recorder: Recorder())

        guard case let .json(json) = response, let object = json.value as? [String: Any] else {
            return XCTFail("\(response)")
        }
        XCTAssertEqual(object["txID"] as? String, hex(Data(SHA256.hash(data: rawData))))
        let signature = try XCTUnwrap((object["signature"] as? [String])?.first)
        XCTAssertTrue(["1b", "1c"].contains(String(signature.suffix(2))))
    }

    func testAnEVMTransactionIsAnsweredAsTheRawTransactionTheDeviceSigned() async throws {
        let transaction = WalletConnectEVMTransaction(
            from: Self.evmAddress,
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            data: "0x",
            value: "0x1",
            nonce: "0x5",
            gas: nil,
            gasPrice: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil
        )

        let response = try await sign(
            .ethSignTransaction,
            payload: .evmTransaction(transaction, send: false),
            recorder: Recorder(),
            evmFee: WalletConnectEVMFee(amount: 21000 * 7, limit: 21000, price: .gas(price: 7))
        )

        var input = EthereumSigningInput()
        input.chainID = Data([0x01])
        input.nonce = Data([0x05])
        input.txMode = .legacy
        input.gasPrice = Data([0x07])
        input.gasLimit = Data([0x52, 0x08])
        input.toAddress = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
        input.transaction.transfer.amount = Data([0x01])
        input.privateKey = Self.evmKey.data
        let expected: EthereumSigningOutput = AnySigner.sign(input: input, coin: .ethereum)
        XCTAssertEqual(response, .string("0x" + hex(expected.encoded)))
    }

    func testASolanaTransactionComesBackWithTheSignatureInItsSlot() async throws {
        let solanaKey = Self.solanaKey.getPublicKeyEd25519().data
        let message = Data([1, 0, 1, 2]) + solanaKey + Data(repeating: 0xCC, count: 32) + Data(repeating: 0x01, count: 32) + Data([0])
        let wire = Data([1]) + Data(count: 64) + message
        let recorder = Recorder()

        let response = try await sign(
            .solanaSignTransaction,
            chain: .sol,
            payload: .solanaTransaction(.init(pubkey: Self.solanaAddress, transaction: wire.base64EncodedString()), send: false),
            recorder: recorder
        )

        let messages = await recorder.solanaMessages
        XCTAssertEqual(messages, [message])
        let signature = try XCTUnwrap(Self.solanaKey.sign(digest: message, curve: .ed25519))
        guard case let .object(object) = response else {
            return XCTFail("\(response)")
        }
        XCTAssertEqual(object["signature"], Base58.encodeNoCheck(data: signature))
        XCTAssertEqual(object["transaction"], (Data([1]) + signature + message).base64EncodedString())
    }

    func testASolanaMessageIsNotSignedOnTheDevice() async {
        do {
            _ = try await sign(.solanaSignMessage, chain: .sol, payload: .signMessage(.init(address: Self.solanaAddress, message: "3yZe7d", kind: .solana)), recorder: Recorder())
            XCTFail("A Ledger does not sign Solana messages")
        } catch {
            guard case .notImplemented = error else {
                return XCTFail("\(error)")
            }
        }
    }
}

private extension WalletConnectDeviceRequestSignerTests {
    actor Pause {
        private var continuation: CheckedContinuation<Void, Never>?
        private var released = false

        func wait() async {
            guard !released else { return }
            await withCheckedContinuation { continuation = $0 }
        }

        func release() {
            released = true
            continuation?.resume()
            continuation = nil
        }
    }

    actor PendingRequest {
        private(set) var isPending = true
        func end() {
            isPending = false
        }
    }

    func assertDeviceInterrupted(expire: Bool) async {
        let pending = PendingRequest()
        let pause = Pause()
        let entered = expectation(description: "device signing requested")
        let recorder = Recorder(onSign: {
            entered.fulfill()
            await pause.wait()
        })
        let work = Task { () -> WalletConnectSigningError? in
            do throws(WalletConnectSigningError) {
                _ = try await sign(
                    .personalSign, payload: .signMessage(.init(address: Self.evmAddress, message: "Hello", kind: .personal)),
                    recorder: recorder, isPending: { await pending.isPending }
                )
                return nil
            } catch {
                return error
            }
        }
        defer { work.cancel() }
        await fulfillment(of: [entered], timeout: 3)
        if expire { await pending.end() } else { work.cancel() }
        await pause.release()

        let error = await work.value
        let messages = await recorder.messages
        XCTAssertEqual(error, .canceled)
        XCTAssertEqual(messages, [Data("Hello".utf8)])
    }

    static var evmAddress: String {
        CoinType.ethereum.deriveAddressFromPublicKey(publicKey: evmKey.getPublicKeySecp256k1(compressed: false))
    }

    static var tronAddress: String {
        CoinType.tron.deriveAddressFromPublicKey(publicKey: tronKey.getPublicKeySecp256k1(compressed: false))
    }

    static var solanaAddress: String {
        CoinType.solana.deriveAddressFromPublicKey(publicKey: solanaKey.getPublicKeyEd25519())
    }

    /// `r ‖ s ‖ v` with `v` 27 or 28, as the Ledger apps answer a message.
    static func messageSignature(_ key: WalletCore.PrivateKey, digest: Data) -> Data {
        let signature = key.sign(digest: digest, curve: .secp256k1)!
        return signature.prefix(64) + [signature[64] + 27]
    }

    actor Recorder {
        private(set) var messages: [Data] = []
        private(set) var typedDataHashes: [(Data, Data)] = []
        private(set) var tronMessages: [Data] = []
        private(set) var solanaMessages: [Data] = []
        let evmKey: WalletCore.PrivateKey
        let onSign: @Sendable () async -> Void

        init(
            evmKey: WalletCore.PrivateKey = WalletConnectDeviceRequestSignerTests.evmKey,
            onSign: @escaping @Sendable () async -> Void = {}
        ) {
            self.evmKey = evmKey
            self.onSign = onSign
        }

        var device: DeviceTransferSigner {
            DeviceTransferSigner(
                evm: { [evmKey] request in
                    evmKey.sign(digest: Hash.keccak256(data: request.transaction), curve: .secp256k1)!
                },
                tron: { rawData in
                    tronKey.sign(digest: Data(SHA256.hash(data: rawData)), curve: .secp256k1)!
                },
                solana: { [self] message in
                    await record(solana: message)
                    await onSign()
                    return solanaKey.sign(digest: message, curve: .ed25519)!
                },
                bitcoin: { _ in throw CancellationError() },
                ton: { _ in throw CancellationError() },
                evmMessage: { [self] message in
                    await record(message: message)
                    await onSign()
                    let digest = Hash.keccak256(data: Data("\u{19}Ethereum Signed Message:\n\(message.count)".utf8) + message)
                    return messageSignature(evmKey, digest: digest)
                },
                evmTypedData: { [self] domainSeparator, messageHash in
                    await record(typedData: (domainSeparator, messageHash))
                    return messageSignature(evmKey, digest: Hash.keccak256(data: Data([0x19, 0x01]) + domainSeparator + messageHash))
                },
                tronMessage: { [self] message in
                    await record(tron: message)
                    return messageSignature(tronKey, digest: Hash.keccak256(data: Data("\u{19}TRON Signed Message:\n\(message.count)".utf8) + message))
                }
            )
        }

        func record(message: Data) {
            messages.append(message)
        }

        func record(typedData: (Data, Data)) {
            typedDataHashes.append(typedData)
        }

        func record(tron: Data) {
            tronMessages.append(tron)
        }

        func record(solana: Data) {
            solanaMessages.append(solana)
        }
    }

    func sign(
        _ method: KeeperCore.WalletConnectMethod,
        chain: WalletConnectChain = .eth,
        payload: WalletConnectRequestPayload,
        recorder: Recorder,
        evmFee: WalletConnectEVMFee? = nil,
        isPending: @escaping @Sendable () async -> Bool = { true }
    ) async throws(WalletConnectSigningError) -> WalletConnectResponseValue {
        let request: WalletConnectSessionRequest
        do {
            request = try WalletConnectRequestFactory.makeRequest(
                id: "1",
                topic: "topic",
                method: method,
                chain: chain,
                payload: payload,
                dapp: WalletConnectDapp(name: "dApp", url: "https://example.com", description: "", iconURL: nil),
                source: nil,
                walletId: "ledger"
            )
        } catch {
            throw .invalidPayload(reason: "\(error)")
        }
        let context = WalletConnectSigningContext(
            signer: await .device(recorder.device),
            wallet: Self.ledgerWallet(),
            mnemonicAccess: Self.mnemonicAccess(),
            client: client,
            pendingTransactionsService: IgnoredPendingTransactions(),
            evmFee: evmFee,
            isPending: isPending
        )
        return try await WalletConnectRequestSigner().sign(request: request, context: context)
    }

    static func ledgerWallet() -> KeeperCore.Wallet {
        func key(_ data: Data) -> MultichainPublicKey {
            MultichainPublicKey(defaultHex: "0x" + hex(data), segWit: "")
        }
        let device = KeeperCore.Wallet.LedgerDevice(deviceId: UUID().uuidString, deviceModel: "Ledger Stax", accountIndex: 0)
        return KeeperCore.Wallet(
            id: "ledger",
            identity: WalletIdentity(network: .mainnet, kind: .Ledger(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2, device)),
            metaData: WalletMetaData(label: "Ledger", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(MultichainWalletState(
                walletId: "ledger",
                addresses: [
                    MultichainWalletAddress(chain: .eth, address: evmAddress, publicKey: key(evmKey.getPublicKeySecp256k1(compressed: false).data)),
                    MultichainWalletAddress(chain: .tron, address: tronAddress, publicKey: key(tronKey.getPublicKeySecp256k1(compressed: false).data)),
                    MultichainWalletAddress(chain: .sol, address: solanaAddress, publicKey: key(solanaKey.getPublicKeyEd25519().data)),
                ],
                syncState: .synced
            ))
        )
    }

    static func mnemonicAccess() -> MnemonicAccess {
        .inMemory(seed: "wallet-connect-device")
    }
}

private struct IgnoredPendingTransactions: PendingTransactionsService {
    func report(_: MultichainPendingTransaction) async {}

    func flushRetained() async {}
}

private func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}
