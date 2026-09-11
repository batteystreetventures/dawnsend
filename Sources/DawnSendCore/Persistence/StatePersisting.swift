/// Local persistence seam for operational schedule state.
public protocol StatePersisting: AnyObject {
    func load() throws -> PersistedScheduleState?
    func save(_ state: PersistedScheduleState) throws
    func clear() throws
}
