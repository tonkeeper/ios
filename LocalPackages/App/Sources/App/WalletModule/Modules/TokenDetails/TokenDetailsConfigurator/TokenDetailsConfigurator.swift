import BigInt
import Foundation
import KeeperCore
import TKLocalize

protocol TokenDetailsConfigurator {
    var didUpdate: (() -> Void)? { get set }

    func viewDidLoad()
    func reload()
    func getTokenModel(balance: ProcessedBalance?, isSecureMode: Bool) -> TokenDetailsModel
    func getDetailsURL() -> URL?
}

extension TokenDetailsConfigurator {
    func viewDidLoad() {}
    func reload() {}
}

extension String {
    static let tonviewer = "https://tonviewer.com"
    static let tronscan = "https://tronscan.org/#/address"
}
