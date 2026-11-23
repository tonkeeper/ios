@testable import KeeperCore
import TronSwift
import WalletCore
import WalletCoreSwiftProtobuf
import XCTest

final class DeviceTransactionSignerTests: XCTestCase {
    private let key = WalletCore.PrivateKey(data: Data(repeating: 0x11, count: 32))!

    private var sender: String {
        CoinType.ethereum.deriveAddressFromPublicKey(publicKey: key.getPublicKeySecp256k1(compressed: false))
    }

    private var tronSender: String {
        CoinType.tron.deriveAddressFromPublicKey(publicKey: key.getPublicKeySecp256k1(compressed: false))
    }

    func testADeviceSignatureCompilesToTheTransactionSignedInTheApp() async throws {
        let input = Self.transferInput()

        let signed = try await DeviceTransactionSigner.signEVM(input: input.serializedBytes(), chainId: 1, sender: sender) { [key] request in
            XCTAssertEqual(request.chainId, 1)
            XCTAssertNil(request.tokenContract)
            return key.sign(digest: Hash.keccak256(data: request.transaction), curve: .secp256k1)!
        }

        var inApp = input
        inApp.privateKey = key.data
        let expected: EthereumSigningOutput = AnySigner.sign(input: inApp, coin: .ethereum)
        XCTAssertEqual(try EthereumSigningOutput(serializedBytes: signed).encoded, expected.encoded)
    }

    func testASignatureByAnotherKeyIsRefused() async throws {
        let other = try XCTUnwrap(WalletCore.PrivateKey(data: Data(repeating: 0x22, count: 32)))

        do {
            _ = try await DeviceTransactionSigner.signEVM(input: Self.transferInput().serializedBytes(), chainId: 1, sender: sender) { request in
                other.sign(digest: Hash.keccak256(data: request.transaction), curve: .secp256k1)!
            }
            XCTFail("A signature that does not recover to the sender must not be sent")
        } catch let failure as MultichainTransactionFailure {
            guard case .failedToSign = failure else {
                return XCTFail("\(failure)")
            }
        }
    }

    func testARefusalOnTheDeviceCancels() async throws {
        do {
            _ = try await DeviceTransactionSigner.signEVM(input: Self.transferInput().serializedBytes(), chainId: 1, sender: sender) { _ in
                throw CancellationError()
            }
            XCTFail("A refusal must cancel")
        } catch let failure as MultichainTransactionFailure {
            guard case .canceled = failure else {
                return XCTFail("\(failure)")
            }
        }
    }

    func testATokenTransferNamesItsContract() {
        var input = Self.transferInput()
        input.toAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
        input.transaction.erc20Transfer.to = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
        input.transaction.erc20Transfer.amount = Data([0x01])

        XCTAssertEqual(DeviceTransactionSigner.tokenContract(of: input), "0xdAC17F958D2ee523a2206206994597C13D831ec7")
        XCTAssertNil(DeviceTransactionSigner.tokenContract(of: Self.transferInput()))
    }

    func testATokenApprovalNamesItsContract() {
        var input = Self.transferInput()
        input.toAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
        input.transaction.erc20Approve.spender = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
        input.transaction.erc20Approve.amount = Data([0x01])

        XCTAssertEqual(DeviceTransactionSigner.tokenContract(of: input), "0xdAC17F958D2ee523a2206206994597C13D831ec7")
    }

    func testATronDeviceSignatureCompilesToTheTransactionSignedInTheApp() async throws {
        let input = Self.tronTransferInput(owner: tronSender)
        let expected = try await signedTron(input) { [key] rawData in
            key.sign(digest: Hash.sha256(data: rawData), curve: .secp256k1)!
        }

        var inApp = input
        inApp.privateKey = key.data
        let inAppOutput: TronSigningOutput = AnySigner.sign(input: inApp, coin: .tron)
        XCTAssertEqual(expected.json, inAppOutput.json)
        XCTAssertEqual(expected.signature, inAppOutput.signature)
    }

    func testATronSignatureWithAnOffsetRecoveryIdCompilesTheSame() async throws {
        let input = Self.tronTransferInput(owner: tronSender)
        let sign = { [key] (rawData: Data) in key.sign(digest: Hash.sha256(data: rawData), curve: .secp256k1)! }

        let offset = try await signedTron(input) { rawData in
            let signature = sign(rawData)
            return signature.prefix(64) + [signature[64] + 27]
        }

        let plain = try await signedTron(input) { sign($0) }
        XCTAssertEqual(offset.json, plain.json)
    }

    func testATronSignatureByAnotherKeyIsRefused() async throws {
        let other = try XCTUnwrap(WalletCore.PrivateKey(data: Data(repeating: 0x22, count: 32)))

        do {
            _ = try await signedTron(Self.tronTransferInput(owner: tronSender)) { rawData in
                other.sign(digest: Hash.sha256(data: rawData), curve: .secp256k1)!
            }
            XCTFail("A signature that does not recover to the sender must not be sent")
        } catch let failure as MultichainTransactionFailure {
            guard case .failedToSign = failure else {
                return XCTFail("\(failure)")
            }
        }
    }

    func testATronTransactionForTheBatteryIsSignedOnTheDeviceAsTheAppSignsIt() async throws {
        let preImage = try DeviceTransactionSigner.preImage(coin: .tron, input: Self.tronTransferInput(owner: tronSender).serializedBytes())
        let transaction = try XCTUnwrap(TronSwift.Transaction(json: [
            "txID": preImage.dataHash.hexString,
            "raw_data_hex": preImage.data.hexString,
            "raw_data": [
                "ref_block_bytes": "7b3b",
                "ref_block_hash": "b21ace8d6ac20e7e",
                "expiration": Int64(1_539_331_479_000),
                "timestamp": Int64(1_539_295_479_000),
            ] as [String: Any],
        ]))

        let signature = try await DeviceTransactionSigner.signTronTransaction(transaction, sender: tronSender) { [key] rawData in
            key.sign(digest: Hash.sha256(data: rawData), curve: .secp256k1)!
        }

        let inApp = try TronSwift.Signer().sign(
            hash: transaction.signingDigest(),
            privateKey: TronSwift.PrivateKey(data: key.data, chainCode: Data())
        )
        XCTAssertEqual(signature, inApp)
    }

    func testATronTransactionForTheBatterySignedByAnotherKeyIsRefused() async throws {
        let other = try XCTUnwrap(WalletCore.PrivateKey(data: Data(repeating: 0x22, count: 32)))
        let preImage = try DeviceTransactionSigner.preImage(coin: .tron, input: Self.tronTransferInput(owner: tronSender).serializedBytes())
        let transaction = try XCTUnwrap(TronSwift.Transaction(json: [
            "txID": preImage.dataHash.hexString,
            "raw_data_hex": preImage.data.hexString,
            "raw_data": [
                "ref_block_bytes": "7b3b",
                "ref_block_hash": "b21ace8d6ac20e7e",
                "expiration": Int64(1_539_331_479_000),
                "timestamp": Int64(1_539_295_479_000),
            ] as [String: Any],
        ]))

        do {
            _ = try await DeviceTransactionSigner.signTronTransaction(transaction, sender: tronSender) { rawData in
                other.sign(digest: Hash.sha256(data: rawData), curve: .secp256k1)!
            }
            XCTFail("A signature that does not recover to the sender must not reach the battery")
        } catch {
            guard case .failedToSign = error else {
                return XCTFail("\(error)")
            }
        }
    }

    func testASolanaDeviceSignatureCompilesToTheTransactionSignedInTheApp() async throws {
        let solanaKey = try XCTUnwrap(WalletCore.PrivateKey(data: Data(repeating: 0x33, count: 32)))
        let sender = CoinType.solana.deriveAddressFromPublicKey(publicKey: solanaKey.getPublicKeyEd25519())
        let input = Self.solanaTransferInput(sender: sender)

        let signed = try await DeviceTransactionSigner.signSolana(input: input.serializedBytes(), sender: sender) { message in
            solanaKey.sign(digest: message, curve: .ed25519)!
        }

        var inApp = input
        inApp.privateKey = solanaKey.data
        let expected: SolanaSigningOutput = AnySigner.sign(input: inApp, coin: .solana)
        XCTAssertEqual(try SolanaSigningOutput(serializedBytes: signed).encoded, expected.encoded)
    }

    func testASolanaSignatureByAnotherKeyIsRefused() async throws {
        let solanaKey = try XCTUnwrap(WalletCore.PrivateKey(data: Data(repeating: 0x33, count: 32)))
        let other = try XCTUnwrap(WalletCore.PrivateKey(data: Data(repeating: 0x44, count: 32)))
        let sender = CoinType.solana.deriveAddressFromPublicKey(publicKey: solanaKey.getPublicKeyEd25519())

        do {
            _ = try await DeviceTransactionSigner.signSolana(input: Self.solanaTransferInput(sender: sender).serializedBytes(), sender: sender) { message in
                other.sign(digest: message, curve: .ed25519)!
            }
            XCTFail("A signature that does not verify with the sender's key must not be sent")
        } catch let failure as MultichainTransactionFailure {
            guard case .failedToSign = failure else {
                return XCTFail("\(failure)")
            }
        }
    }

    private func signedTron(
        _ input: TronSigningInput,
        device: @escaping @Sendable (Data) async throws -> Data
    ) async throws -> TronSigningOutput {
        let signed = try await DeviceTransactionSigner.signTron(input: input.serializedBytes(), sender: tronSender, device: device)
        return try TronSigningOutput(serializedBytes: signed)
    }

    private static func transferInput() -> EthereumSigningInput {
        var input = EthereumSigningInput()
        input.chainID = Data([0x01])
        input.nonce = Data([0x05])
        input.txMode = .enveloped
        input.maxInclusionFeePerGas = Data([0x77, 0x35, 0x94, 0x00])
        input.maxFeePerGas = Data([0x04, 0xA8, 0x17, 0xC8, 0x00])
        input.gasLimit = Data([0x52, 0x08])
        input.toAddress = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
        input.transaction.transfer.amount = Data([0x0D, 0xE0, 0xB6, 0xB3, 0xA7, 0x64, 0x00, 0x00])
        return input
    }

    private static func solanaTransferInput(sender: String) -> SolanaSigningInput {
        var input = SolanaSigningInput()
        input.sender = sender
        input.recentBlockhash = "11111111111111111111111111111111"
        input.transferTransaction.recipient = "EN2sCsJ1WDV8UFqsiTXHcUPUxQ4juE71eCknHYYMifkd"
        input.transferTransaction.value = 42
        return input
    }

    private static func tronTransferInput(owner: String) -> TronSigningInput {
        var input = TronSigningInput()
        input.transaction.timestamp = 1_539_295_479_000
        input.transaction.expiration = 1_539_295_479_000 + 10 * 60 * 60 * 1000
        input.transaction.blockHeader.timestamp = 1_539_295_479_000
        input.transaction.blockHeader.number = 3_111_739
        input.transaction.blockHeader.version = 3
        input.transaction.blockHeader.txTrieRoot = Data(hexString: "64288c2db0641316762a99dbb02ef7c90f968b60f9f2e410835980614332f86d")!
        input.transaction.blockHeader.parentHash = Data(hexString: "00000000002f7b3af4f5f8b9e23a30c530f719f165b742e7358536b280eead2d")!
        input.transaction.blockHeader.witnessAddress = Data(hexString: "415863f6091b8e71766da808b1dd3159790f61de7d")!
        input.transaction.transfer.ownerAddress = owner
        input.transaction.transfer.toAddress = "THTR75o8xXAgCTQqpiot2AFRAjvW1tSbVV"
        input.transaction.transfer.amount = 2_000_000
        return input
    }
}
