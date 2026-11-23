import Foundation

/// What the user entered per venue account and market. The typed ROI lasts for this
/// app launch; the leverage of an attempted open is kept across launches.
/// A sheet shows a remembered ROI only while it still names the leg's trigger
/// price, so a stale entry can never be shown — at worst it goes unused.
@MainActor
final class PerpsTradeInputMemory {
    static let shared = PerpsTradeInputMemory()

    @MainActor
    struct Slot {
        fileprivate let memory: PerpsTradeInputMemory
        fileprivate let key: Key

        var autoCloseInput: PerpsAutoCloseROIInput {
            memory.autoCloseInputs[key] ?? .none
        }

        var leverage: Double? {
            memory.userDefaults.object(forKey: key.leverageDefaultsKey) as? Double
        }

        func rememberAutoCloseInput(_ input: PerpsAutoCloseROIInput) {
            memory.autoCloseInputs[key] = input == .none ? nil : input
        }

        func rememberLeverage(_ leverage: Double) {
            memory.userDefaults.set(leverage, forKey: key.leverageDefaultsKey)
        }
    }

    fileprivate struct Key: Hashable {
        let accountIndex: Int64
        let marketId: Int64

        var leverageDefaultsKey: String {
            "perps.openLeverage.\(accountIndex).\(marketId)"
        }
    }

    private let userDefaults: UserDefaults
    private var autoCloseInputs = [Key: PerpsAutoCloseROIInput]()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func slot(accountIndex: Int64, marketId: Int64) -> Slot {
        Slot(memory: self, key: Key(accountIndex: accountIndex, marketId: marketId))
    }
}
