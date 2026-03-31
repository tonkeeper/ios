import CoreComponents
import Foundation
import TonSwift

public protocol BatteryPromocodeRepository {
    func savePromocode(_ promocode: String?) throws
    func getPromocode() -> String?
}

struct BatteryPromocodeRepositoryImplementation: BatteryPromocodeRepository {
    let fileSystemVault: FileSystemVault<String, String>

    func savePromocode(_ promocode: String?) throws {
        if let promocode {
            try fileSystemVault.saveItem(promocode, key: key)
        } else {
            try fileSystemVault.deleteItem(key: key)
        }
    }

    func getPromocode() -> String? {
        try? fileSystemVault.loadItem(key: key)
    }

    private var key: String {
        "battery_promocode"
    }
}
