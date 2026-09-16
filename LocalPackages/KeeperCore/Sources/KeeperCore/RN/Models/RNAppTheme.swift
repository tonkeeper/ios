import Foundation
import TonSwift

public struct RNAppTheme: Codable {
    public struct State: Codable {
        public let selectedTheme: String
    }

    public let state: State
}
