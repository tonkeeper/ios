import Foundation

@frozen public enum TokenImage: Equatable, Hashable {
    case ton
    case usdt
    case url(URL?)
}
