import AppUI
import Combine

@MainActor
final class WalletSectionLimitModel {
    private let subject: CurrentValueSubject<WalletSectionLimit, Never>
    private let save: (WalletSectionLimit) -> Void

    var limit: WalletSectionLimit {
        subject.value
    }

    var limitChanges: AnyPublisher<WalletSectionLimit, Never> {
        subject.dropFirst().eraseToAnyPublisher()
    }

    init(limit: WalletSectionLimit, save: @escaping (WalletSectionLimit) -> Void) {
        subject = CurrentValueSubject(limit)
        self.save = save
    }

    convenience init(storedCount: Int, save: @escaping (WalletSectionLimit) -> Void) {
        self.init(limit: WalletSectionLimit(rawValue: storedCount) ?? .initial, save: save)
    }

    func select(_ limit: WalletSectionLimit) {
        guard limit != subject.value else { return }
        save(limit)
        subject.send(limit)
    }
}
