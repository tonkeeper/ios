import Foundation

public enum EventTime: Sendable {
    case utc(timestamp: Double)
    case businessDay(BusinessDay)
    case businessDayString(String)
}

public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    public var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    public var intValue: Int? {
        guard case let .int(value) = self else { return nil }
        return value
    }

    public var doubleValue: Double? {
        switch self {
        case let .int(value):
            return Double(value)
        case let .double(value):
            return value
        default:
            return nil
        }
    }

    public var boolValue: Bool? {
        guard case let .bool(value) = self else { return nil }
        return value
    }

    public var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    public var arrayValue: [JSONValue]? {
        guard case let .array(value) = self else { return nil }
        return value
    }

    var eventTimeValue: EventTime? {
        switch self {
        case let .int(value):
            return .utc(timestamp: Double(value))
        case let .double(value):
            return .utc(timestamp: value)
        case let .string(value):
            return .businessDayString(value)
        case let .object(value):
            guard let data = try? JSONEncoder().encode(value) else {
                return nil
            }
            return try? JSONDecoder().decode(BusinessDay.self, from: data).map(EventTime.businessDay)
        case .bool, .array, .null:
            return nil
        }
    }
}

public struct EventSeriesData: Codable, Equatable, Sendable {
    public let rawValue: JSONValue

    public init(rawValue: JSONValue) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        rawValue = try JSONValue(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try rawValue.encode(to: encoder)
    }

    public var objectValue: [String: JSONValue]? {
        rawValue.objectValue
    }

    public var time: EventTime? {
        objectValue?["time"]?.eventTimeValue
    }

    public var value: Double? {
        objectValue?["value"]?.doubleValue
    }

    public var open: Double? {
        objectValue?["open"]?.doubleValue
    }

    public var high: Double? {
        objectValue?["high"]?.doubleValue
    }

    public var low: Double? {
        objectValue?["low"]?.doubleValue
    }

    public var close: Double? {
        objectValue?["close"]?.doubleValue
    }

    public var kind: Kind {
        let object = objectValue ?? [:]

        if object["open"] != nil || object["high"] != nil || object["low"] != nil || object["close"] != nil {
            return .ohlc
        }
        if object["value"] != nil {
            return .singleValue
        }
        if object["time"] != nil {
            return .whitespace
        }
        return .unknown
    }

    public enum Kind: String, Codable, Equatable, Sendable {
        case singleValue
        case ohlc
        case whitespace
        case unknown
    }
}

public struct TouchMouseEventData: Codable, Sendable {
    /**
     * The X coordinate of the mouse pointer in local (DOM content) coordinates.
     */
    public let clientX: Double?

    /**
     * The Y coordinate of the mouse pointer in local (DOM content) coordinates.
     */
    public let clientY: Double?

    /**
     * The X coordinate of the mouse pointer relative to the whole document.
     */
    public let pageX: Double?

    /**
     * The Y coordinate of the mouse pointer relative to the whole document.
     */
    public let pageY: Double?

    /**
     * The X coordinate of the mouse pointer in global (screen) coordinates.
     */
    public let screenX: Double?

    /**
     * The Y coordinate of the mouse pointer in global (screen) coordinates.
     */
    public let screenY: Double?

    /**
     * The X coordinate of the mouse pointer relative to the chart / price axis / time axis canvas element.
     */
    public let localX: Double?

    /**
     * The Y coordinate of the mouse pointer relative to the chart / price axis / time axis canvas element.
     */
    public let localY: Double?

    /**
     * Returns a boolean value that is true if the Ctrl key was active when the key event was generated.
     */
    public let ctrlKey: Bool?

    /**
     * Returns a boolean value that is true if the Alt (Option or ? on macOS) key was active when the
     * key event was generated.
     */
    public let altKey: Bool?

    /**
     * Returns a boolean value that is true if the Shift key was active when the key event was generated.
     */
    public let shiftKey: Bool?

    /**
     * Returns a boolean value that is true if the Meta key (on Mac keyboards, the Command key; on
     * Windows keyboards, the Windows key) was active when the key event was generated.
     */
    public let metaKey: Bool?

    public init(
        clientX: Double?,
        clientY: Double?,
        pageX: Double?,
        pageY: Double?,
        screenX: Double?,
        screenY: Double?,
        localX: Double?,
        localY: Double?,
        ctrlKey: Bool?,
        altKey: Bool?,
        shiftKey: Bool?,
        metaKey: Bool?
    ) {
        self.clientX = clientX
        self.clientY = clientY
        self.pageX = pageX
        self.pageY = pageY
        self.screenX = screenX
        self.screenY = screenY
        self.localX = localX
        self.localY = localY
        self.ctrlKey = ctrlKey
        self.altKey = altKey
        self.shiftKey = shiftKey
        self.metaKey = metaKey
    }
}

public struct MouseEventParams: Codable, Sendable {
    public let time: EventTime?
    public let logical: Double?
    public let point: Point?
    public let paneIndex: Int?
    public let hoveredObjectId: JSONValue?
    public let sourceEvent: TouchMouseEventData?
    public let hoveredSeries: String?
    public let seriesData: [String: EventSeriesData]

    enum CodingKeys: String, CodingKey {
        case time
        case logical
        case point
        case paneIndex
        case hoveredObjectId
        case sourceEvent
        case hoveredSeries
        case seriesData
    }

    public init(
        time: EventTime?,
        logical: Double?,
        point: Point?,
        paneIndex: Int? = nil,
        hoveredObjectId: JSONValue?,
        sourceEvent: TouchMouseEventData?,
        hoveredSeries: String?,
        seriesData: [String: EventSeriesData] = [:]
    ) {
        self.time = time
        self.logical = logical
        self.point = point
        self.paneIndex = paneIndex
        self.hoveredObjectId = hoveredObjectId
        self.sourceEvent = sourceEvent
        self.hoveredSeries = hoveredSeries
        self.seriesData = seriesData
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decodeIfPresent(EventTime.self, forKey: .time)
        logical = try container.decodeIfPresent(Double.self, forKey: .logical)
        point = try container.decodeIfPresent(Point.self, forKey: .point)
        paneIndex = try container.decodeIfPresent(Int.self, forKey: .paneIndex)
        hoveredObjectId = try container.decodeIfPresent(JSONValue.self, forKey: .hoveredObjectId)
        sourceEvent = try container.decodeIfPresent(TouchMouseEventData.self, forKey: .sourceEvent)
        hoveredSeries = try container.decodeIfPresent(String.self, forKey: .hoveredSeries)
        seriesData = try container.decodeIfPresent([String: EventSeriesData].self, forKey: .seriesData) ?? [:]
    }

    public func data(forSeries series: SeriesObject) -> EventSeriesData? {
        seriesData[series.jsName]
    }

    @available(*, deprecated, renamed: "data(forSeries:)")
    public func price(forSeries series: SeriesObject) -> EventSeriesData? {
        data(forSeries: series)
    }

    public func isHovered(series: SeriesObject) -> Bool {
        hoveredSeries == series.jsName
    }
}

extension EventTime: Codable, Equatable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let utcTimestamp = try? container.decode(Double.self) {
            self = .utc(timestamp: utcTimestamp)
        } else if let businessDay = try? container.decode(BusinessDay.self) {
            self = .businessDay(businessDay)
        } else if let businessDayString = try? container.decode(String.self) {
            self = .businessDayString(businessDayString)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Error decoding \(type(of: self))")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .utc(timestamp):
            try container.encode(timestamp)
        case let .businessDay(businessDay):
            try container.encode(businessDay)
        case let .businessDayString(businessDayString):
            try container.encode(businessDayString)
        }
    }
}

private extension BusinessDay {
    func map<T>(_ transform: (BusinessDay) -> T) -> T {
        transform(self)
    }
}
