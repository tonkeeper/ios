
import Foundation

public enum MismatchDirection: Int, Codable, Sendable {
    case nearestLeft = -1
    case none = 0
    case nearestRight = 1
}
