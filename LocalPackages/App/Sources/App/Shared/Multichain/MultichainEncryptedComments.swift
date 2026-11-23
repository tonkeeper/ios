import Combine
import KeeperCore
import TKCoordinator
import TKCore
import TKLocalize
import TKUIKit
import UIKit

/// The TON comments a wallet's multichain activities carry encrypted to it: what each decrypted to, and the
/// way to decrypt one.
@MainActor
final class MultichainEncryptedComments: ObservableObject {
    /// Moves on whenever the wallet decrypts a comment.
    @Published private(set) var revision = 0

    typealias Decrypt = (
        _ payload: EncryptedCommentPayload,
        _ eventId: String,
        _ onDecrypting: @escaping @MainActor (_ isDecrypting: Bool) -> Void
    ) -> Void

    private let wallet: Wallet
    private let decryptedCommentStore: DecryptedCommentStore
    private let onDecrypt: Decrypt
    /// Events whose comment decrypts: the passcode screen has closed, but the spoiler is still on screen.
    private var decrypting = Set<String>()

    init(
        wallet: Wallet,
        decryptedCommentStore: DecryptedCommentStore,
        onDecrypt: @escaping Decrypt
    ) {
        self.wallet = wallet
        self.decryptedCommentStore = decryptedCommentStore
        self.onDecrypt = onDecrypt
        decryptedCommentStore.addObserver(self) { observer, event in
            guard case let .didDecryptComment(_, wallet) = event else { return }
            Task { @MainActor in
                guard wallet == observer.wallet else { return }
                observer.revision += 1
            }
        }
    }

    /// The comment the activity carries encrypted, as the wallet decrypted it; `nil` until then.
    func decryptedComment(of activity: MultichainActivity) -> String? {
        guard let decryption = Decryption(activity: activity) else { return nil }
        return decryptedCommentStore.getDecryptedComment(
            wallet: wallet,
            payload: decryption.payload,
            eventId: decryption.eventId
        )
    }

    func decrypt(_ activity: MultichainActivity) {
        guard let decryption = Decryption(activity: activity), !decrypting.contains(decryption.eventId) else { return }
        // Only the wallet's phrase holds the TON key the comment is encrypted to: a Ledger keeps it on the device.
        guard wallet.hasMultichainMnemonic else {
            if wallet.isLedger {
                ToastPresenter.showToast(configuration: .init(title: TKLocales.History.Event.Comment.encryptedLedger))
            }
            return
        }
        let eventId = decryption.eventId
        onDecrypt(decryption.payload, eventId) { [weak self] isDecrypting in
            if isDecrypting {
                self?.decrypting.insert(eventId)
            } else {
                self?.decrypting.remove(eventId)
            }
        }
    }
}

extension MultichainEncryptedComments {
    /// Decrypts with the passcode, asked for over `presenter`.
    convenience init(
        wallet: Wallet,
        coordinator: Coordinator,
        presenter: UIViewController,
        keeperCoreAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly
    ) {
        self.init(
            wallet: wallet,
            decryptedCommentStore: keeperCoreAssembly.storesAssembly.decryptedCommentStore
        ) { [weak coordinator, weak presenter] payload, eventId, onDecrypting in
            guard let coordinator, let presenter else { return }
            DecryptCommentHandler.decryptComment(
                wallet: wallet,
                payload: payload,
                eventId: eventId,
                parentCoordinator: coordinator,
                parentRouter: ViewControllerRouter(rootViewController: presenter),
                keeperCoreAssembly: keeperCoreAssembly,
                coreAssembly: coreAssembly,
                onDecrypting: onDecrypting
            )
        }
    }
}

private struct Decryption {
    let payload: EncryptedCommentPayload
    let eventId: String

    init?(activity: MultichainActivity) {
        guard let comment = activity.encryptedComment, let payload = comment.payload else { return nil }
        self.payload = payload
        // The store keys a decrypted comment by its event too. TON history's event id is a bare hash, which the
        // multichain backend prefixes with the chain ("ton:<hash>"): without the prefix, the two can match.
        let transactionId = activity.txIds.first.map { id in
            id.firstIndex(of: ":").map { String(id[id.index(after: $0)...]) } ?? id
        }
        eventId = transactionId ?? comment.cipherText
    }
}

extension MultichainActivityEncryptedComment {
    /// About how many characters the comment has: its cipher text is hex and adds 64 bytes to it.
    var approximateLength: Int {
        max(cipherText.count / 2 - 64, 1)
    }
}

/// The activity a details sheet shows, with its comment as decrypted so far: the sheet rebuilds its content
/// only for a new item.
struct MultichainActivityDetailsItem: Hashable {
    let activity: MultichainActivity
    let decryptedComment: String?
}
