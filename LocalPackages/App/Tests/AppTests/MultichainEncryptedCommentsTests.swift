@testable import App
import AppUI
@testable import KeeperCore
import TKLocalize
import TKTestSupport
import TKUIKit
import TonSwift
import XCTest

@MainActor
final class MultichainEncryptedCommentsTests: XCTestCase {
    private let sender = "0:27bafbc6d4a559505c397864e9e2a68c69ffbea37c61f34b54d114231d3906f3"
    /// 80 bytes, as the backend sends a comment of about 16 characters.
    private let cipherText = String(repeating: "ab", count: 80)

    func test_anEncryptedComment_showsNowhereWithoutTheWayToDecryptIt() {
        let activity = makeActivity()

        let item = makeMapper(encryptedComments: nil).makeItem(activity: activity)

        XCTAssertNil(item.comment)
        XCTAssertNil(item.encryptedComment)
        XCTAssertEqual(item.transactionMessages, [])
        XCTAssertNil(commentRow(in: makeDetailsBuilder(encryptedComments: nil).build(activity: activity)))
    }

    func test_anEncryptedComment_showsAsASpoilerThatAsksToDecryptIt() throws {
        var decryptions = [(payload: EncryptedCommentPayload, eventId: String)]()
        let comments = makeComments { payload, eventId, _ in decryptions.append((payload: payload, eventId: eventId)) }
        let activity = makeActivity()

        let item = makeMapper(encryptedComments: comments).makeItem(activity: activity)
        let row = commentRow(in: makeDetailsBuilder(encryptedComments: comments).build(activity: activity))

        XCTAssertNil(item.comment)
        XCTAssertEqual(item.encryptedComment, activity.encryptedComment)
        XCTAssertNil(item.decryptedComment)
        XCTAssertEqual(item.transactionMessages, spoiler)
        guard case let .encryptedComment(title, length, decrypt) = row else {
            return XCTFail("expected an encrypted comment row, got \(String(describing: row))")
        }
        XCTAssertEqual(title, TKLocales.EventDetails.comment)
        XCTAssertEqual(length, 16)

        decrypt()

        let decryption = try XCTUnwrap(decryptions.first)
        XCTAssertEqual(decryptions.count, 1)
        XCTAssertEqual(decryption.eventId, "a8ad8820", "TON history keys an event by its bare hash")
        XCTAssertEqual(decryption.payload.encryptedComment.cipherText, cipherText)
        XCTAssertEqual(decryption.payload.senderAddress.toRaw(), sender)
    }

    func test_aDecryptedComment_showsItsTextAndRebuildsTheDetails() async throws {
        let store = DecryptedCommentStore()
        let wallet = makeWallet()
        let comments = MultichainEncryptedComments(wallet: wallet, decryptedCommentStore: store) { _, _, _ in }
        let activity = makeActivity()
        let shownItem = MultichainActivityDetailsItem(activity: activity, decryptedComment: comments.decryptedComment(of: activity))
        let payload = try XCTUnwrap(activity.encryptedComment?.payload)

        await store.setDecryptedComment(" Thanks! ", wallet: wallet, payload: payload, eventId: "a8ad8820")
        await waitUntil(comments) { comments.revision == 1 }

        let item = makeMapper(encryptedComments: comments).makeItem(activity: activity)
        let row = commentRow(in: makeDetailsBuilder(encryptedComments: comments).build(activity: activity))
        XCTAssertNil(item.comment)
        XCTAssertEqual(item.decryptedComment, " Thanks! ")
        XCTAssertEqual(item.transactionMessages, [TransactionCellContent.Message(id: "comment", text: "Thanks!")])
        guard case let .comment(_, value) = row else {
            return XCTFail("expected a comment row, got \(String(describing: row))")
        }
        XCTAssertEqual(value, "Thanks!")
        XCTAssertNotEqual(
            MultichainActivityDetailsItem(activity: activity, decryptedComment: comments.decryptedComment(of: activity)),
            shownItem,
            "the sheet swaps its content only for a new item"
        )
    }

    func test_secureMode_hidesADecryptedCommentBehindTheSpoiler() async throws {
        let store = DecryptedCommentStore()
        let wallet = makeWallet()
        let comments = MultichainEncryptedComments(wallet: wallet, decryptedCommentStore: store) { _, _, _ in }
        let activity = makeActivity()
        let payload = try XCTUnwrap(activity.encryptedComment?.payload)
        await store.setDecryptedComment("Thanks!", wallet: wallet, payload: payload, eventId: "a8ad8820")
        await waitUntil(comments) { comments.revision == 1 }

        let secureItem = makeMapper(encryptedComments: comments, hidesAmounts: true).makeItem(activity: activity)
        let item = makeMapper(encryptedComments: comments).makeItem(activity: activity)
        let row = commentRow(in: makeDetailsBuilder(encryptedComments: comments, hidesAmounts: true).build(activity: activity))

        XCTAssertNil(secureItem.decryptedComment)
        XCTAssertEqual(secureItem.transactionMessages, spoiler)
        XCTAssertEqual(item.maskingAmounts().transactionMessages, spoiler, "the asset screen masks its rows this way")
        guard case .encryptedComment = row else {
            return XCTFail("expected an encrypted comment row, got \(String(describing: row))")
        }
    }

    func test_aTapWhileTheCommentDecrypts_isIgnored() {
        var decryptionCount = 0
        var onDecrypting: (@MainActor (Bool) -> Void)?
        let comments = makeComments { _, _, decrypting in
            decryptionCount += 1
            onDecrypting = decrypting
        }
        let activity = makeActivity()

        comments.decrypt(activity)
        onDecrypting?(true)
        comments.decrypt(activity)
        XCTAssertEqual(decryptionCount, 1)

        onDecrypting?(false)
        comments.decrypt(activity)
        XCTAssertEqual(decryptionCount, 2)
    }

    func test_aLedger_isNotAskedForThePasscode() {
        var decryptionCount = 0
        let comments = makeComments(wallet: makeLedgerWallet()) { _, _, _ in decryptionCount += 1 }

        comments.decrypt(makeActivity())

        XCTAssertEqual(decryptionCount, 0)
    }

    func test_aSpamActivity_showsNoEncryptedComment() {
        let comments = makeComments { _, _, _ in }
        let activity = makeActivity(isSpam: true)

        XCTAssertEqual(makeMapper(encryptedComments: comments).makeItem(activity: activity).transactionMessages, [])
        XCTAssertNil(commentRow(in: makeDetailsBuilder(encryptedComments: comments).build(activity: activity)))
    }

    func test_aDnsRenewal_showsNoEncryptedComment() {
        let comments = makeComments { _, _, _ in }
        let nft = MultichainActivityNFT(id: "nft", name: "wallet.ton", collectionName: "TON DNS", imageURL: nil, isVerified: true)

        let item = makeMapper(encryptedComments: comments, nft: nft).makeItem(activity: makeActivity(activityType: .dnsRenew))

        XCTAssertNil(item.encryptedComment)
        XCTAssertEqual(item.transactionMessages, [])
    }

    func test_aBlankPlainComment_leavesTheEncryptedOneToShow() {
        let comments = makeComments { _, _, _ in }
        let activity = makeActivity(comment: " ")

        let item = makeMapper(encryptedComments: comments).makeItem(activity: activity)

        XCTAssertNil(item.comment)
        XCTAssertEqual(item.encryptedComment, activity.encryptedComment)
        guard case .encryptedComment = commentRow(in: makeDetailsBuilder(encryptedComments: comments).build(activity: activity)) else {
            return XCTFail("expected an encrypted comment row")
        }
    }

    func test_aPlainComment_winsOverAnEncryptedOne() {
        let comments = makeComments { _, _, _ in }
        let activity = makeActivity(comment: "Hello")

        let item = makeMapper(encryptedComments: comments).makeItem(activity: activity)

        XCTAssertEqual(item.comment, "Hello")
        XCTAssertNil(item.encryptedComment)
        guard case .comment = commentRow(in: makeDetailsBuilder(encryptedComments: comments).build(activity: activity)) else {
            return XCTFail("expected a comment row")
        }
    }
}

private extension MultichainEncryptedCommentsTests {
    var spoiler: [TransactionCellContent.Message] {
        [
            TransactionCellContent.Message(
                id: "encrypted_comment",
                text: TKLocales.History.Event.Comment.encrypted,
                encryptedLength: 16
            ),
        ]
    }

    func makeComments(
        wallet: Wallet? = nil,
        onDecrypt: @escaping MultichainEncryptedComments.Decrypt
    ) -> MultichainEncryptedComments {
        MultichainEncryptedComments(
            wallet: wallet ?? makeWallet(),
            decryptedCommentStore: DecryptedCommentStore(),
            onDecrypt: onDecrypt
        )
    }

    func makeMapper(
        encryptedComments: MultichainEncryptedComments?,
        hidesAmounts: Bool = false,
        nft: MultichainActivityNFT? = nil
    ) -> MultichainHistoryActivityItemMapper {
        MultichainHistoryActivityItemMapper(
            amountFormatter: AmountFormatter(configuration: AmountFormatter.Configuration()),
            dateFormatter: DateFormatter(),
            hidesAmounts: { hidesAmounts },
            nftProvider: { _ in nft },
            encryptedComments: encryptedComments
        )
    }

    func makeDetailsBuilder(
        encryptedComments: MultichainEncryptedComments?,
        hidesAmounts: Bool = false
    ) -> MultichainTransactionDetailsModelBuilder {
        MultichainTransactionDetailsModelBuilder(
            amountFormatter: AmountFormatter(configuration: AmountFormatter.Configuration()),
            dateFormatter: DateFormatter(),
            transactionButtonProvider: { _ in nil },
            hidesAmounts: { hidesAmounts },
            decryptedComment: { encryptedComments?.decryptedComment(of: $0) },
            decryptComment: encryptedComments.map { encryptedComments in { encryptedComments.decrypt($0) } }
        )
    }

    func commentRow(in model: MultichainTransactionDetailsModel) -> MultichainTransactionDetailsCellContent? {
        model.rows.first {
            switch $0 {
            case .comment, .encryptedComment:
                true
            default:
                false
            }
        }
    }

    func makeActivity(
        activityType: MultichainActivityType = .receive,
        comment: String? = nil,
        isSpam: Bool = false
    ) -> MultichainActivity {
        let gram = MultichainAssetDetails(
            assetId: "ton/mainnet/coin",
            name: "GRAM",
            symbol: "GRAM",
            decimals: 9,
            image: ""
        )
        return MultichainActivity(
            activityType: activityType,
            status: .confirmed,
            blockTime: Date(timeIntervalSince1970: 1_777_440_000),
            blockNumber: nil,
            fromChain: .ton,
            toChain: .ton,
            walletAddress: "0:wallet",
            direction: .incoming,
            fromAddress: sender,
            toAddress: "0:wallet",
            outToken: gram,
            outAmount: "500000000",
            outAmountUsd: nil,
            inToken: gram,
            inAmount: "500000000",
            inAmountUsd: nil,
            feeToken: nil,
            feeAmount: nil,
            feeAmountUsd: nil,
            protocolName: nil,
            txIds: ["ton:a8ad8820"],
            isRead: nil,
            isSpam: isSpam,
            comment: comment,
            encryptedComment: MultichainActivityEncryptedComment(cipherText: cipherText, senderAddress: sender)
        )
    }

    func makeWallet() -> Wallet {
        Wallet(
            id: "wallet",
            identity: WalletIdentity(network: .mainnet, kind: .Regular(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v5R1)),
            metaData: WalletMetaData(label: "Wallet", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(walletId: "wallet", addresses: [MultichainWalletAddress(chain: .ton, address: "0:wallet")])
            )
        )
    }

    func makeLedgerWallet() -> Wallet {
        let device = Wallet.LedgerDevice(deviceId: "device", deviceModel: "Ledger Stax", accountIndex: 0)
        return Wallet(
            id: "ledger",
            identity: WalletIdentity(network: .mainnet, kind: .Ledger(TonSwift.PublicKey(data: Data(repeating: 1, count: 32)), .v4R2, device)),
            metaData: WalletMetaData(label: "Ledger", tintColor: .defaultColor, icon: .icon(.wallet)),
            setupSettings: WalletSetupSettings(isSetupFinished: true),
            batterySettings: BatterySettings(),
            multichain: .multichain(
                MultichainWalletState(walletId: "ledger", addresses: [MultichainWalletAddress(chain: .ton, address: "0:wallet")])
            )
        )
    }
}
