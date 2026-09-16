import Foundation
import KeeperCore
import UIKit

protocol RecipientInputModuleOutput: AnyObject {
    var didResolveRecipient: ((TonRecipient?) -> Void)? { get set }
}

final class RecipientInputViewModel: ObservableObject, RecipientInputModuleOutput {
    // MARK: - RecipientInputModuleOutput

    var didResolveRecipient: ((TonRecipient?) -> Void)?

    // MARK: - State

    private enum State {
        case none
        case resolving
        case failed
        case success(TonRecipient)
    }

    @Published private(set) var text = ""
    @Published private(set) var isValid = true
    @Published private(set) var isResolving = false
    @Published var isFocused = false

    private var resolvingState: State = .none {
        didSet {
            didUpdateResolveState()
            switch resolvingState {
            case let .success(recipient):
                didResolveRecipient?(recipient)
            default:
                didResolveRecipient?(nil)
            }
        }
    }

    private var resolvingTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let wallet: Wallet
    private let recipientResolver: RecipientResolver

    init(
        wallet: Wallet,
        recipientResolver: RecipientResolver
    ) {
        self.wallet = wallet
        self.recipientResolver = recipientResolver
    }

    // MARK: - Actions

    func setText(_ text: String) {
        guard text != self.text else { return }
        self.text = text
        isValid = true
        resolve(text: text)
    }

    func paste() {
        guard let pasteboardString = UIPasteboard.general.string else { return }
        text = pasteboardString
        isFocused = false
        resolve(text: pasteboardString)
    }

    // MARK: - Resolving

    private func resolve(text: String?) {
        if let resolvingTask {
            resolvingTask.cancel()
        }

        resolvingState = .none
        guard let text, !text.isEmpty else {
            return
        }

        resolvingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self.resolvingState = .resolving
            do {
                let recipient = try await self.recipientResolver.resolverTonRecipient(string: text, network: wallet.network)
                self.resolvingState = .success(recipient)
            } catch {
                self.resolvingState = .failed
            }
        }
    }

    private func didUpdateResolveState() {
        switch resolvingState {
        case .none, .success:
            isValid = true
            isResolving = false
        case .failed:
            isValid = false
            isResolving = false
        case .resolving:
            isValid = true
            isResolving = true
        }
    }
}
