import FirebasePerformance
import Foundation

public final class Trace {
    private let firebaseTrace: FirebasePerformance.Trace?

    public init(name: String) {
        self.firebaseTrace = Performance.startTrace(name: name)
    }

    public func setValue(_ value: String, forAttribute attribute: String) {
        firebaseTrace?.setValue(value, forAttribute: attribute)
    }

    public func incrementMetric(_ name: String, by value: Int64) {
        firebaseTrace?.incrementMetric(name, by: value)
    }

    public func stop() {
        firebaseTrace?.stop()
    }
}
