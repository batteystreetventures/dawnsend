/// V1 does not keep the Mac awake with the lid closed.
public enum LidClosedCapability: Sendable {
    public static let isSupported = false

    public static let userFacingLimitation =
        "V1 does not keep the Mac awake with the lid closed or the Mac locked."
}
