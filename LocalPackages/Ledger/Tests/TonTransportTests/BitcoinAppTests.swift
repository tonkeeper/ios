import CryptoKit
@testable import LedgerKit
import XCTest

/// Vectors from Ledger's reference client, as Android's tests use them.
final class BitcoinAppTests: XCTestCase {
    private let elements = (1 ... 7).map { Data(repeating: UInt8($0), count: $0) }

    func testMerkleRootsMatchTheReference() {
        let expected = [
            "b413f47d13ee2fe6c845b2ee141af81de858df4ec549a58b7970bb96645bc8d2",
            "84fc9d22ba3729c733e692ea298171290f8bb06b942888d79638599cb719c7e3",
            "50ab465bb10ae8e2c17800cd6533a3311c0e2afd837585ff73f8c83dbf944f0b",
            "50e5a68865c866510164abc1fc4426ac7551b62e1ecdc39e296d8758d132e9bd",
            "ca54caf4d4545fd8ee07d8b55d729b05fd1a0fd89a20178c119bd0297b6dc2d3",
            "de8800092d1b2bed3aec153f4dd4fdf017fb0632471582921b62e7e83a6778fb",
            "36f2e0e463744b7b60a4c8d90823b85ced6ed1056b153a32b8c68839e3e435b6",
        ]

        XCTAssertEqual((1 ... 7).map { hex(BitcoinMerkle.root(of: Array(elements.prefix($0)))) }, expected)
        XCTAssertEqual(hex(BitcoinMerkle.root(of: [])), String(repeating: "0", count: 64))
    }

    func testMerkleProofListsSiblingsFromTheLeafUp() {
        let proof = BitcoinMerkle.proof(of: 5, in: elements.map(BitcoinMerkle.leaf))

        XCTAssertEqual(proof.map(hex), [
            "2851ddf061ccde8675d83f08d671c6890d60a3176214a75b1778d7ce4fb3942f",
            "5a359a4dedf8493727ab85565ce2a92e4c67ab04ecba5b122815e1c5c3c7389c",
            "50e5a68865c866510164abc1fc4426ac7551b62e1ecdc39e296d8758d132e9bd",
        ])
    }

    func testPolicySerializationAndIdMatchTheReference() {
        let policy = BitcoinApp.Policy(keyInfo: "[f5acc2fd/84'/1'/0']tpubDCtKfsNyRhULjZ9XMS4VKKtVcPdVDi8MKUbcSD9MJDyjRu1A2ND5MiipozyyspBT9bg8upEp7a8EAgFxNxXn1d7QkdbL52Ty5jiSLcxPt1P")

        XCTAssertEqual(
            hex(policy.serialized),
            "02000bc8974a0d8bdd29024b2ddb7a7fe8df1d9801b270f4e6c1e7e1011ae39e7c9b000144006386daf887e322e999231f37ba1dcc1863357a4bc21a78a623d7d2863f02"
        )
        XCTAssertEqual(hex(policy.id), "74e9dad05d709eb46f8cce7378ebafb45a75c7e83e0d2a63e02f492c8adc7293")
    }

    func testMapCommitmentSortsItsKeys() {
        let map: [Data: Data] = [
            Data([0x02]): Data([2, 0, 0, 0]),
            Data([0x04]): Data([0x01]),
            Data([0x05]): Data([0x02]),
            Data([0x03]): Data([0, 0, 0, 0]),
            Data([0xFB]): Data([2, 0, 0, 0]),
        ]

        XCTAssertEqual(
            hex(BitcoinMerkle.commitment(map)),
            "05519b38dae74447b72151f354cb138ca3591a5ff8ac813289b18a004e3132162086d8d9498a323006ec5982eeb4ea7c41d27020d57985512ab59ff8f40d501507"
        )
    }

    func testALongPreimageStreamsItsTailThroughMoreElements() throws {
        let preimage = Data((0 ..< 256).map { UInt8($0) } + (0 ..< 44).map { UInt8($0) })
        let client = BitcoinClient(knowledge: BitcoinClient.Knowledge(lists: [], preimages: [preimage]))

        let (first, next) = try client.answering(Data([0x40, 0x00]) + Data(SHA256.hash(data: preimage)))
        let (more, _) = try next.answering(Data([0xA0]))

        XCTAssertEqual(hex(first.prefix(4)), "fd2c01fb")
        XCTAssertEqual(first.dropFirst(4), preimage.prefix(251))
        XCTAssertEqual(hex(more), "3101fbfcfdfeff000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b")
    }

    func testMerkleLeafProofAndIndexMatchTheReference() throws {
        let list = (1 ... 200).map { Data(repeating: UInt8($0 % 256), count: 1 + $0 % 5) }
        let client = BitcoinClient(knowledge: BitcoinClient.Knowledge(lists: [list], preimages: []))
        let root = BitcoinMerkle.root(of: list)

        let (proof, next) = try client.answering(Data([0x41]) + root + compactSize(200) + compactSize(0x57))
        let (more, _) = try next.answering(Data([0xA0]))

        XCTAssertEqual(hex(root), "263642970093e0d94cc709f79c849e243c73e129820f46c7a8657b9a4d495c0b")
        XCTAssertEqual(hex(proof), "f8c18151ea133c2fc453adb926f3a8d78563337497aac6699b1ff02d3aee5a1108069215ababade5896ffb52c95a39ee115d9b2dff2725aa5f155938980fd01fc87534c0441015cbc7bfd7a3a384aa85c7e1d78dbc2e443a23aceae82d7be29ab0b0a33a37397a152fc3cdef775cde61997467c9e3878aae2c1c43e66f46a32dcd07838de88c90387b398ed72e92da5073db7652e9e3b6789dab64dd6616e9195da3d32cd083b8d61d1ec794659a0e91a4ef80313ea31c10716d69405cf5f50231b6b5826667e750abf8cde2c4bb1b1f8437230dbc8f23b0bd91d94b8e06155f5cb4")
        XCTAssertEqual(hex(more), "02201c9736a1a234a770563f82bd0a7979015d23055fda90d0fd50b0c2ba8b485bcbf380924de96bd19abad7744cb2bb8a2ca5dded080e2853a72eed4c8a077d773c")
        XCTAssertEqual(try hex(client.answering(Data([0x42]) + root + BitcoinMerkle.leaf(list[7])).answer), "0107")
        XCTAssertEqual(try hex(client.answering(Data([0x42]) + root + Data(count: 32)).answer), "0000")
    }

    func testYieldedSignaturesAreCollected() throws {
        let yielded = Data([0x01, 0x21]) + Data(repeating: 0x02, count: 33) + Data(repeating: 0x30, count: 71)

        let (answer, client) = try BitcoinClient().answering(Data([0x10]) + yielded)

        XCTAssertTrue(answer.isEmpty)
        XCTAssertEqual(
            client.yielded.compactMap(BitcoinApp.signature(yielded:)),
            [BitcoinApp.Signature(inputIndex: 1, publicKey: Data(repeating: 0x02, count: 33), signature: Data(repeating: 0x30, count: 71))]
        )
    }

    func testPSBTCarriesTheMapsTheAppReads() {
        let publicKey = Data(repeating: 0x02, count: 33)
        let path = BitcoinApp.accountPath(account: 0) + [0, 0]
        let transaction = BitcoinApp.Transaction(
            version: 2,
            lockTime: 0,
            inputs: [BitcoinApp.Input(previousTxid: Data(repeating: 9, count: 32), previousIndex: 1, amount: 100_000, script: Data([0x00, 0x14]) + Data(count: 20), publicKey: publicKey, path: path, previousTransaction: nil, sequence: 0xFFFF_FFFF)],
            outputs: [BitcoinApp.Output(amount: 60000, script: Data([0x00, 0x14]) + Data(count: 20), change: (publicKey, path))]
        )

        let psbt = BitcoinApp.psbt(transaction, fingerprint: Data([1, 2, 3, 4]))

        XCTAssertEqual(psbt.global.keys.sorted { $0.lexicographicallyPrecedes($1) }.map(hex), ["02", "03", "04", "05", "fb"])
        XCTAssertEqual(psbt.inputs.first?.keys.sorted { $0.lexicographicallyPrecedes($1) }.map(hex), ["01", "06" + hex(publicKey), "0e", "0f", "10"])
        XCTAssertEqual(psbt.inputs.first.map { hex($0[Data([0x06]) + publicKey] ?? Data()) }, "0102030454000080000000800000008000000000" + "00000000")
        XCTAssertEqual(psbt.outputs.first?.keys.sorted { $0.lexicographicallyPrecedes($1) }.map(hex), ["02" + hex(publicKey), "03", "04"])
    }

    func testClientCommandsAreAnsweredUntilTheAppFinishes() async throws {
        let policy = BitcoinApp.Policy(fingerprint: Data([1, 2, 3, 4]), account: 0, accountXpub: "xpub")
        let device = FakeDevice(replies: [
            Data([0x40, 0x00]) + Data(SHA256.hash(data: policy.serialized)) + Data([0xE0, 0x00]),
            Data("bc1qaddress".utf8) + Data([0x90, 0x00]),
        ])

        let address = try await device.link.bitcoinWalletAddress(policy: policy, index: 0, display: false)

        let sent = await device.sent
        XCTAssertEqual(address, "bc1qaddress")
        XCTAssertEqual(sent.first.map { String($0.prefix(8)) }, "e1030001")
        XCTAssertEqual(sent.last.map { String($0.prefix(8)) }, "f8010001")
        XCTAssertTrue(sent.last?.hasSuffix(hex(policy.serialized)) == true)
    }

    func testExtendedKeyRequest() async throws {
        let device = FakeDevice(replies: [Data("xpub6C".utf8) + Data([0x90, 0x00])])

        let xpub = try await device.link.bitcoinExtendedPublicKey(path: BitcoinApp.accountPath(account: 0))

        let sent = await device.sent
        XCTAssertEqual(xpub, "xpub6C")
        XCTAssertEqual(sent, ["e10000010e0003800000548000000080000000"])
    }
}

private func hex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}
