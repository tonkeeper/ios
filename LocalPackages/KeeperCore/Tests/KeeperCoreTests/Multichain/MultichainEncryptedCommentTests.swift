@preconcurrency import BigInt
@preconcurrency import ChainKit
@testable import KeeperCore
@testable import KeeperCoreComponents
import KeeperCoreSensitive
import TonSwift
import XCTest

/// A TON coin send's comment encrypted to the recipient's key by chain-kit: what the history decrypts
/// with the keys the app derives, for the recipient and for the sender alike.
final class MultichainEncryptedCommentTests: XCTestCase {
    private static let sender = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let recipient = "legal winner thank year wave sausage worth useful legal winner thank yellow"
    private static let ton = MultichainChain.ton.asChainKitChain

    private lazy var client = CryptoKitClient(
        netModule: ModuleNetModule(
            netConfig: ModuleNetConfig(isLogging: false, logger: nil, userAgent: nil, sessionProvider: nil, nodeManifestHost: nil)
        )
    )

    /// The recipient reads it with its own key, the sender with its own, as the history decrypts an
    /// incoming and an outgoing comment.
    func test_chainKitsEncryptedCommentIsReadByTheRecipientAndTheSender() async throws {
        let unlocked = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: Self.sender)
        let account = try senderAccount(unlocked)
        let recipientKeys = try keyPair(Self.recipient)
        let senderKeys = try keyPair(Self.sender)

        for text in ["deposit 42", "Привет, мир", "gm 👋🏽🚀"] {
            let comment = try XCTUnwrap(MultichainEncryptedComment(text: text, key: recipientKeys.publicKey.data.hexDigits))

            let body = try await comment.encrypted(account: account, wallet: unlocked, client: client)

            let cipherText = try Self.cipherText(of: body)
            let senderAddress = try TonSwift.Address.parse(account.addressDisplay)
            let byRecipient = try CommentDecryptor(
                privateKey: recipientKeys.privateKey,
                publicKey: recipientKeys.publicKey,
                cipherText: cipherText,
                senderAddress: senderAddress
            ).decrypt()
            let bySender = try CommentDecryptor(
                privateKey: senderKeys.privateKey,
                publicKey: senderKeys.publicKey,
                cipherText: cipherText,
                senderAddress: senderAddress
            ).decrypt()
            XCTAssertEqual(byRecipient, text)
            XCTAssertEqual(bySender, text, "the key the app derives for the history is the one chain-kit encrypts with")
        }
    }

    /// The fee is priced for a stand-in exactly the size of what is encrypted in its place.
    func test_theStandInIsTheSizeOfTheEncryptedComment() async throws {
        let unlocked = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: Self.sender)
        let account = try senderAccount(unlocked)
        let key = try keyPair(Self.recipient).publicKey.data.hexDigits

        for text in ["a", "deposit 42", String(repeating: "Ж", count: 200)] {
            let comment = try XCTUnwrap(MultichainEncryptedComment(text: text, key: key))

            let standIn = try await comment.standIn(account: account, client: client)
            let encrypted = try await comment.encrypted(account: account, wallet: unlocked, client: client)

            XCTAssertNotEqual(standIn, encrypted)
            XCTAssertEqual(try Self.bits(of: standIn), try Self.bits(of: encrypted), "\(text.utf8.count) bytes")
        }
    }

    /// Only a comment chain-kit encrypts, one that is not blank, with a key to encrypt it to is encrypted,
    /// and only a TON coin send carries one.
    func test_aCommentIsEncryptedOnlyToAKeyAndOnlyOnATonCoinSend() throws {
        let gram = asset("ton/mainnet/coin", symbol: "TON", decimals: 9)
        let usdt = asset("ton/mainnet/jetton/0:b113a994b5024a16719f69139328eb759596c38a25f59028b146fecdc3621dfe", symbol: "USD₮", decimals: 6)
        let eth = asset("eth/mainnet/coin", symbol: "ETH", decimals: 18)

        XCTAssertNil(try ChainKitServiceImplementation.encryptedComment("hi", to: nil, of: gram))
        XCTAssertNil(try ChainKitServiceImplementation.encryptedComment("hi", to: "", of: gram))
        XCTAssertNil(try ChainKitServiceImplementation.encryptedComment(nil, to: "aa", of: gram))
        XCTAssertNil(try ChainKitServiceImplementation.encryptedComment("", to: "aa", of: gram))
        XCTAssertNil(try ChainKitServiceImplementation.encryptedComment(" \n\t ", to: "aa", of: gram))
        XCTAssertEqual(try ChainKitServiceImplementation.encryptedComment(" hi ", to: "aa", of: gram), MultichainEncryptedComment(text: " hi ", key: "aa"))
        XCTAssertEqual(try ChainKitServiceImplementation.encryptedComment("hi", to: "aa", of: gram), MultichainEncryptedComment(text: "hi", key: "aa"))
        for other in [usdt, eth] {
            XCTAssertThrowsError(try ChainKitServiceImplementation.encryptedComment("hi", to: "aa", of: other), other.asset.symbol)
        }
    }

    /// The SDK's transfer takes the encrypted body as its payload, never alongside its comment.
    func test_theSDKsTransferCarriesTheBodyInPlaceOfTheComment() throws {
        let unlocked = try CryptoWallet.Companion.shared.fromMnemonic(mnemonic_: Self.sender)
        let account = try senderAccount(unlocked)
        let transfer = try TransactionTransfer(
            account: account,
            amount: BignumBigInteger(long: 1_000_000_000),
            isMax: true,
            to: XCTUnwrap(ChainKit.Address.Companion.shared.from(value: account.addressDisplay, chain: Self.ton, type: .default_)),
            memo: "plain",
            payload: nil
        )

        let carried = ChainKitServiceImplementation.carrying(transfer, payload: "te6body")

        XCTAssertNil(carried.memo)
        XCTAssertEqual(carried.payload, "te6body")
        XCTAssertEqual(carried.amount.description, "1000000000")
        XCTAssertTrue(carried.isMax)
        XCTAssertEqual(carried.to.display, transfer.to.display)
        XCTAssertEqual(carried.account.addressDisplay, account.addressDisplay)
    }
}

private extension MultichainEncryptedCommentTests {
    /// The sender's v4R2 account, holding the coin, with the key the address stored.
    func senderAccount(_ unlocked: MnemonicWallet) throws -> ChainKit.Account {
        ChainKit.Account(
            address: unlocked.getAddress(chain: Self.ton, type: .tonv4r2),
            asset: Self.ton.toAsset(),
            derivation: DerivationDefaultPath.shared,
            publicKey: unlocked.getPublicKey(chain: Self.ton)
        )
    }

    /// The keys the app derives from a BIP-39 phrase, as the history decrypts with them.
    func keyPair(_ mnemonic: String) throws -> TonSwift.KeyPair {
        try CoreMnemonic(mnemonicWords: mnemonic.components(separatedBy: " "), type: .bip39).toKeyPair()
    }

    func asset(_ assetId: String, symbol: String, decimals: Int) -> MultichainAsset {
        MultichainAsset(
            asset: MultichainAssetDetails(assetId: assetId, name: symbol, symbol: symbol, decimals: decimals, image: ""),
            price: .init(prices: [:], diff24h: [:], diff7d: [:]),
            balance: 0
        )
    }

    /// The hex the history reads an encrypted comment as, `cipher_text` as tonapi reads it: the bytes that
    /// follow the opcode, down the chain of cells however full each one is.
    static func cipherText(of body: String) throws -> String {
        let slice = try TonSwift.Cell.fromBase64(src: body).beginParse()
        XCTAssertEqual(try slice.loadUint(bits: 32), 0x2167_DA4B, "the encrypted comment's opcode")
        return try bytes(of: slice).hexDigits
    }

    static func bytes(of slice: TonSwift.Slice) throws -> Data {
        var data = try slice.loadBytes(slice.remainingBits / 8)
        if slice.remainingRefs > 0 {
            try data.append(bytes(of: slice.loadRef().beginParse()))
        }
        return data
    }

    /// How many bits the body's cells hold, which is what the fee is charged for.
    static func bits(of body: String) throws -> Int {
        func bits(_ cell: TonSwift.Cell) -> Int {
            cell.bits.length + cell.refs.reduce(0) { $0 + bits($1) }
        }
        return try bits(TonSwift.Cell.fromBase64(src: body))
    }
}

private extension Data {
    var hexDigits: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
