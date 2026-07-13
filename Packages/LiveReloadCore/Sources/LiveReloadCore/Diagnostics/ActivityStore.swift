public actor ActivityStore {
    public static let defaultCapacity = 200

    private let capacity: Int
    private var events: [ActivityEvent]

    public init(capacity: Int = defaultCapacity, initialEvents: [ActivityEvent] = []) {
        self.capacity = max(1, capacity)
        events = Array(initialEvents.suffix(self.capacity))
    }

    public func append(_ event: ActivityEvent) {
        events.append(event)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
    }

    public func snapshot() -> [ActivityEvent] {
        events
    }

    public func removeAll() {
        events.removeAll(keepingCapacity: true)
    }
}
