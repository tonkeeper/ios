struct ScannerCameraSetupState {
    private enum State {
        case needed, configuring, ready
    }

    private var state: State = .needed

    mutating func beginConfiguration() -> Bool {
        guard state == .needed else { return false }
        state = .configuring
        return true
    }

    mutating func didConfigure() {
        state = .ready
    }

    mutating func didFailConfiguration() {
        if state == .configuring { state = .needed }
    }
}

struct ScannerCaptureLifecycle {
    private(set) var isVisible = false
    private(set) var run = 0
    private var hasDeliveredScan = false
    private var needsNewRun = true

    mutating func appear() {
        if !isVisible {
            hasDeliveredScan = false
            needsNewRun = true
        }
        isVisible = true
    }

    mutating func disappear() {
        isVisible = false
    }

    mutating func beginRun(isRunning: Bool) -> Int? {
        guard isVisible, !hasDeliveredScan else { return nil }
        if needsNewRun || !isRunning {
            run += 1
            needsNewRun = false
        }
        return run
    }

    mutating func consumeScan(run: Int) -> Bool {
        guard isVisible, self.run == run, !hasDeliveredScan else { return false }
        hasDeliveredScan = true
        return true
    }

    mutating func rejectScan(run: Int) {
        guard self.run == run else { return }
        hasDeliveredScan = false
    }

    mutating func completeScan(run: Int, accepted: Bool) -> Bool {
        guard isVisible, self.run == run, hasDeliveredScan else { return false }
        if !accepted { rejectScan(run: run) }
        return accepted
    }
}

struct ScannerViewVisibility {
    private(set) var isVisible = false
    private var appearance = 0

    mutating func appear() -> Int {
        if !isVisible { appearance += 1 }
        isVisible = true
        return appearance
    }

    mutating func disappear() {
        isVisible = false
    }

    func allowsDelivery(appearance: Int) -> Bool {
        isVisible && self.appearance == appearance
    }
}
