/// Test- and preview-friendly persistence. Production uses `FileStateStore`.
public final class InMemoryStateStore: StatePersisting {
    private var state: PersistedScheduleState?

    public init(state: PersistedScheduleState? = nil) {
        self.state = state
    }

    public func load() throws -> PersistedScheduleState? {
        state
    }

    public func save(_ state: PersistedScheduleState) throws {
        self.state = state
    }

    public func clear() throws {
        state = nil
    }
}
