import Foundation

public enum ConflationPriority: String, Codable, Sendable {
    case background
    case userVisible = "user-visible"
    case userBlocking = "user-blocking"
}

public struct TimeScaleOptions: Sendable {
    public var rightOffset: Double?
    public var barSpacing: Double?
    public var minBarSpacing: Double?
    public var maxBarSpacing: Double?
    public var fixLeftEdge: Bool?
    public var fixRightEdge: Bool?
    public var lockVisibleTimeRangeOnResize: Bool?
    public var rightBarStaysOnScroll: Bool?
    public var borderVisible: Bool?
    public var borderColor: ChartColor?
    public var visible: Bool?
    public var timeVisible: Bool?
    public var secondsVisible: Bool?
    public var shiftVisibleRangeOnNewBar: Bool?
    public var rightOffsetPixels: Double?
    public var allowShiftVisibleRangeOnWhitespaceReplacement: Bool?
    public var tickMarkMaxCharacterLength: Int?
    public var minimumHeight: Double?
    public var ticksVisible: Bool?
    public var uniformDistribution: Bool?
    public var allowBoldLabels: Bool?
    public var ignoreWhitespaceIndices: Bool?
    public var enableConflation: Bool?
    public var conflationThresholdFactor: Double?
    public var precomputeConflationOnInit: Bool?
    public var precomputeConflationPriority: ConflationPriority?

    public var tickMarkFormatter: JavaScriptMethod<TickMarkFormatterParameters, String>? {
        get {
            tickMarkFormatterJSFunction?.function
        }
        set {
            tickMarkFormatterJSFunction = newValue.map { JSFunction(prompt: .tickMarkFormatter, function: $0) }
        }
    }

    var tickMarkFormatterJSFunction: JSFunction<TickMarkFormatterParameters, String>?

    public init(
        rightOffset: Double? = nil,
        barSpacing: Double? = nil,
        minBarSpacing: Double? = nil,
        maxBarSpacing: Double? = nil,
        fixLeftEdge: Bool? = nil,
        fixRightEdge: Bool? = nil,
        lockVisibleTimeRangeOnResize: Bool? = nil,
        rightBarStaysOnScroll: Bool? = nil,
        borderVisible: Bool? = nil,
        borderColor: ChartColor? = nil,
        visible: Bool? = nil,
        timeVisible: Bool? = nil,
        secondsVisible: Bool? = nil,
        shiftVisibleRangeOnNewBar: Bool? = nil,
        rightOffsetPixels: Double? = nil,
        allowShiftVisibleRangeOnWhitespaceReplacement: Bool? = nil,
        tickMarkMaxCharacterLength: Int? = nil,
        minimumHeight: Double? = nil,
        ticksVisible: Bool? = nil,
        uniformDistribution: Bool? = nil,
        allowBoldLabels: Bool? = nil,
        ignoreWhitespaceIndices: Bool? = nil,
        enableConflation: Bool? = nil,
        conflationThresholdFactor: Double? = nil,
        precomputeConflationOnInit: Bool? = nil,
        precomputeConflationPriority: ConflationPriority? = nil,
        tickMarkFormatter: JavaScriptMethod<TickMarkFormatterParameters, String>? = nil
    ) {
        self.rightOffset = rightOffset
        self.barSpacing = barSpacing
        self.minBarSpacing = minBarSpacing
        self.maxBarSpacing = maxBarSpacing
        self.fixLeftEdge = fixLeftEdge
        self.fixRightEdge = fixRightEdge
        self.lockVisibleTimeRangeOnResize = lockVisibleTimeRangeOnResize
        self.rightBarStaysOnScroll = rightBarStaysOnScroll
        self.borderVisible = borderVisible
        self.borderColor = borderColor
        self.visible = visible
        self.timeVisible = timeVisible
        self.secondsVisible = secondsVisible
        self.shiftVisibleRangeOnNewBar = shiftVisibleRangeOnNewBar
        self.rightOffsetPixels = rightOffsetPixels
        self.allowShiftVisibleRangeOnWhitespaceReplacement = allowShiftVisibleRangeOnWhitespaceReplacement
        self.tickMarkMaxCharacterLength = tickMarkMaxCharacterLength
        self.minimumHeight = minimumHeight
        self.ticksVisible = ticksVisible
        self.uniformDistribution = uniformDistribution
        self.allowBoldLabels = allowBoldLabels
        self.ignoreWhitespaceIndices = ignoreWhitespaceIndices
        self.enableConflation = enableConflation
        self.conflationThresholdFactor = conflationThresholdFactor
        self.precomputeConflationOnInit = precomputeConflationOnInit
        self.precomputeConflationPriority = precomputeConflationPriority
        self.tickMarkFormatter = tickMarkFormatter
    }
}

// MARK: - Codable

extension TimeScaleOptions: Codable {
    enum CodingKeys: String, CodingKey {
        case rightOffset
        case barSpacing
        case minBarSpacing
        case maxBarSpacing
        case fixLeftEdge
        case fixRightEdge
        case lockVisibleTimeRangeOnResize
        case rightBarStaysOnScroll
        case borderVisible
        case borderColor
        case visible
        case timeVisible
        case secondsVisible
        case shiftVisibleRangeOnNewBar
        case rightOffsetPixels
        case allowShiftVisibleRangeOnWhitespaceReplacement
        case tickMarkMaxCharacterLength
        case minimumHeight
        case ticksVisible
        case uniformDistribution
        case allowBoldLabels
        case ignoreWhitespaceIndices
        case enableConflation
        case conflationThresholdFactor
        case precomputeConflationOnInit
        case precomputeConflationPriority
    }
}

// MARK: -

extension TimeScaleOptions {
    func optionsScript(for closuresStore: ClosuresStore?) -> (options: String, variableName: String) {
        let variableName = "options"
        var builder = JavaScriptOptionsScriptBuilder(variableName: variableName, baseJSON: jsonString, closuresStore: closuresStore)
        builder.assign("tickMarkFormatter", formatter: tickMarkFormatterJSFunction)
        return (builder.script, variableName)
    }
}
