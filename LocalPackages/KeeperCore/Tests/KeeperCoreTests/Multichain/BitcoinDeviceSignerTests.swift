@testable import KeeperCore
import WalletCore
import WalletCoreSwiftProtobuf
import XCTest

final class BitcoinDeviceSignerTests: XCTestCase {
    private let key = WalletCore.PrivateKey(data: Data(repeating: 0x55, count: 32))!

    private var publicKey: Data {
        key.getPublicKeySecp256k1(compressed: true).data
    }

    /// BIP-143's native P2WPKH example: its second input.
    func testSighashMatchesBIP143() throws {
        let unsigned = try XCTUnwrap(BitcoinRawTransaction(parsing: XCTUnwrap(Data(hexString: "0100000002fff7f7881a8099afa6940d42d1e7f6362bec38171ea3edf433541db4e4ad969f0000000000eeffffffef51e1b804cc89d182d279655c3aa89e815b1b309fe287d9b2b55d57b90ec68a0100000000ffffffff02202cb206000000001976a9148280b37df378db99f66f85c95a783a76ac7a6d5988ac9093510d000000001976a9143bde42dbee7e4dbe6a21b2d50ce2f0167faa815988ac11000000"))))

        let sighash = try unsigned.witnessV0Sighash(input: 1, amount: 600_000_000, publicKey: XCTUnwrap(Data(hexString: "025476c2e83188368da1ff3e292e7acafcdb3566bb0ad253f62fc70f07aeee6357")))

        XCTAssertEqual(sighash.hexString, "c37af31116d1b27caf68aae9e3ac82f1477929014d5b917657d0eb49478cb670")
    }

    func testATransactionParsesBackToItself() {
        let transaction = BitcoinRawTransaction(
            version: 2,
            inputs: [BitcoinRawTransaction.Input(previousTxid: Data(repeating: 1, count: 32), previousIndex: 3, script: Data(), sequence: 0xFFFF_FFFF, witness: [Data(repeating: 2, count: 71), publicKey])],
            outputs: [BitcoinRawTransaction.Output(amount: 12345, script: BitcoinRawTransaction.witnessV0Script(publicKey: publicKey))],
            lockTime: 0
        )

        XCTAssertEqual(BitcoinRawTransaction(parsing: transaction.serialized()), transaction)
        XCTAssertEqual(BitcoinRawTransaction(parsing: transaction.serialized(withWitness: false))?.txid, transaction.txid)
        XCTAssertNil(BitcoinRawTransaction(parsing: transaction.serialized() + Data([0x00])))
    }

    func testTheSpendIsWhatThePlanSaysSignedOnTheDevice() async throws {
        let signed = try await DeviceTransactionSigner.signBitcoin(input: planInput(), receiveKey: publicKey, accountXpub: "xpub", previousTransactions: [:]) { [key] request in
            XCTAssertEqual(request.outputs.map(\.isChange), [false, true])
            return Self.sighashes(of: request).map { key.signAsDER(digest: $0)! }
        }

        let output = try BitcoinSigningOutput(serializedBytes: signed)
        let transaction = try XCTUnwrap(BitcoinRawTransaction(parsing: output.encoded))
        XCTAssertEqual(transaction.outputs.map(\.amount), [60000, 39000])
        XCTAssertEqual(transaction.inputs.first?.witness.last, publicKey)
        XCTAssertEqual(output.transactionID, Data(transaction.txid.reversed()).hexString)
    }

    func testASignatureByAnotherKeyIsRefused() async throws {
        let other = try XCTUnwrap(WalletCore.PrivateKey(data: Data(repeating: 0x66, count: 32)))

        do {
            _ = try await DeviceTransactionSigner.signBitcoin(input: planInput(), receiveKey: publicKey, accountXpub: "xpub", previousTransactions: [:]) { request in
                Self.sighashes(of: request).map { other.signAsDER(digest: $0)! }
            }
            XCTFail("A signature that does not verify must not be sent")
        } catch let failure as MultichainTransactionFailure {
            guard case .failedToSign = failure else {
                return XCTFail("\(failure)")
            }
        }
    }

    func testAnInputFromAnotherAddressIsRefused() async throws {
        var input = planInput()
        input.plan.utxos[0].script = BitcoinRawTransaction.witnessV0Script(publicKey: Data(repeating: 0x03, count: 33))

        do {
            _ = try await DeviceTransactionSigner.signBitcoin(input: input, receiveKey: publicKey, accountXpub: "xpub", previousTransactions: [:]) { _ in
                XCTFail("Nothing outside the wallet goes to the device")
                return []
            }
            XCTFail("An input the wallet does not own must not be signed")
        } catch let failure as MultichainTransactionFailure {
            guard case .failedToSign = failure else {
                return XCTFail("\(failure)")
            }
        }
    }

    func testExtendedKeysConvertBetweenVersions() throws {
        let xpub = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8"

        let zpub = try XCTUnwrap(BitcoinExtendedKey.converted(xpub, to: BitcoinExtendedKey.zpubVersion))

        XCTAssertEqual(zpub, "zpub6jftahH18ngZxUuv6oSniLNrBCSSE1B4EEU59bwTCEt8x6aS6b2mdfLxbS4QS53g85SWWP6wexqeer516433gYpZQoJie2tcMYdJ1SYYYAL")
        XCTAssertEqual(BitcoinExtendedKey.converted(zpub, to: BitcoinExtendedKey.xpubVersion), xpub)
    }

    private func planInput() -> BitcoinSigningInput {
        BitcoinSigningInput.with {
            $0.toAddress = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
            $0.changeAddress = CoinType.bitcoin.deriveAddressFromPublicKey(publicKey: key.getPublicKeySecp256k1(compressed: true))
            $0.hashType = 1
            $0.plan = BitcoinTransactionPlan.with { [publicKey] plan in
                plan.amount = 60000
                plan.change = 39000
                plan.fee = 1000
                plan.utxos = [BitcoinUnspentTransaction.with {
                    $0.outPoint = BitcoinOutPoint.with { $0.hash = Data(repeating: 9, count: 32)
                        $0.index = 1
                    }
                    $0.amount = 100_000
                    $0.script = BitcoinRawTransaction.witnessV0Script(publicKey: publicKey)
                }]
            }
        }
    }

    /// What the device signs for each input of `request`.
    private static func sighashes(of request: BitcoinDeviceSignRequest) -> [Data] {
        let transaction = BitcoinRawTransaction(
            version: request.version,
            inputs: request.inputs.map { BitcoinRawTransaction.Input(previousTxid: $0.previousTxid, previousIndex: $0.previousIndex, script: Data(), sequence: $0.sequence, witness: []) },
            outputs: request.outputs.map { BitcoinRawTransaction.Output(amount: $0.amount, script: $0.script) },
            lockTime: request.lockTime
        )
        return request.inputs.indices.map { transaction.witnessV0Sighash(input: $0, amount: request.inputs[$0].amount, publicKey: request.publicKey) }
    }
}
