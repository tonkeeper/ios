import SwiftUI

public struct ShelfTransitionConfiguration: Equatable {
    var speed: Double

    public init(
        speed: Double = 1
    ) {
        self.speed = speed
    }
}

public extension ShelfTransitionConfiguration {
    static var `default`: ShelfTransitionConfiguration {
        ShelfTransitionConfiguration()
    }
}

extension ShelfTransitionConfiguration {
    var heightAnimation: Animation {
        .timingCurve(0.4, 0, 0.2, 1, duration: 0.3 / speed)
    }

    var fadeOutAnimation: Animation {
        .easeOut(duration: fadeOutDuration)
    }

    var fadeInAnimation: Animation {
        .timingCurve(0.33, 0, 0.2, 1, duration: 0.36 / speed)
            .delay(0.12 / speed)
    }

    var fadeOutDuration: TimeInterval {
        0.15 / speed
    }
}
