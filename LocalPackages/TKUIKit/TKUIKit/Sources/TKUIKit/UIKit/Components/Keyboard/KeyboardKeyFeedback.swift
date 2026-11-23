import UIKit

@MainActor
final class KeyboardKeyFeedback {
    private static let longTapDuration: TimeInterval = 0.4

    private let rigid: UIImpactFeedbackGenerator
    private let soft: UIImpactFeedbackGenerator
    private let selection = UISelectionFeedbackGenerator()
    private let now: () -> TimeInterval
    private var pressStarts: [ObjectIdentifier: TimeInterval] = [:]

    init(
        rigid: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .rigid),
        soft: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .soft),
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.rigid = rigid
        self.soft = soft
        self.now = now
    }

    func press(_ key: ObjectIdentifier) {
        rigid.impactOccurred(intensity: 0.7)
        rigid.prepare()
        soft.prepare()
        pressStarts[key] = now()
    }

    func release(_ key: ObjectIdentifier) {
        guard let start = pressStarts.removeValue(forKey: key), now() - start >= Self.longTapDuration else { return }
        soft.impactOccurred(intensity: 0.7)
    }

    func cancel(_ key: ObjectIdentifier) {
        pressStarts[key] = nil
    }

    func delete() {
        soft.impactOccurred(intensity: 0.4)
        soft.prepare()
    }

    func select() {
        selection.selectionChanged()
    }
}
