public struct SignedTransactions: Equatable, Sendable, RandomAccessCollection, ExpressibleByArrayLiteral {
    public typealias Element = String
    public typealias Index = Int

    public let bocs: [String]
    private let batterySendProofs: [String: String]

    public init(_ bocs: [String], batterySendProofs: [String: String] = [:]) {
        self.bocs = bocs
        self.batterySendProofs = batterySendProofs
    }

    public init(boc: String, batterySendProof: String? = nil) {
        bocs = [boc]
        batterySendProofs = batterySendProof.map { [boc: $0] } ?? [:]
    }

    public init(arrayLiteral elements: String...) {
        self.init(elements)
    }

    public var startIndex: Int {
        bocs.startIndex
    }

    public var endIndex: Int {
        bocs.endIndex
    }

    public subscript(position: Int) -> String {
        bocs[position]
    }

    public func index(after index: Int) -> Int {
        bocs.index(after: index)
    }

    public func index(before index: Int) -> Int {
        bocs.index(before: index)
    }

    public func batterySendProof(for boc: String) -> String? {
        batterySendProofs[boc]
    }
}
