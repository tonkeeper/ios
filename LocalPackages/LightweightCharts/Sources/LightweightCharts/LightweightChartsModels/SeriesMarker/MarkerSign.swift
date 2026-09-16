import Foundation

/**
 Represents the sign of a marker for directional price changes.

 The value indicates whether a price movement is positive (upward),
 negative (downward), or neutral (no change).
 */
public enum MarkerSign: Int, Codable, Sendable {
    /// Represents a negative change (-1)
    case negative = -1
    /// Represents no change (0)
    case neutral = 0
    /// Represents a positive change (1)
    case positive = 1
}
