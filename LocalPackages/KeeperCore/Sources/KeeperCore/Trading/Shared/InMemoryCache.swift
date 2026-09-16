actor InMemoryKeyedCache<Key: Hashable & Sendable, Value: Sendable> {
    private var storage: [Key: Value] = [:]

    init() {}

    func get(_ key: Key) -> Value? {
        storage[key]
    }

    func get(_ keys: [Key]) -> [Key: Value] {
        keys.reduce(into: [Key: Value]()) { result, key in
            result[key] = storage[key]
        }
    }

    func set(_ value: Value, for key: Key) {
        storage[key] = value
    }

    func merge(_ values: [Key: Value]) {
        storage.merge(values) { _, new in new }
    }
}
