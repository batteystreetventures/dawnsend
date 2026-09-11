import Foundation

/// Installed app identity discovered from Launch Services. Paths must be sanitized before display.
public struct InstalledApplication: Equatable, Sendable {
    public var bundleIdentifier: String
    public var displayName: String
    public var shortVersion: String?
    public var executableName: String?
    public var pathDescription: String

    public init(
        bundleIdentifier: String,
        displayName: String,
        shortVersion: String? = nil,
        executableName: String? = nil,
        pathDescription: String
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.shortVersion = shortVersion
        self.executableName = executableName
        self.pathDescription = pathDescription
    }
}

public struct RunningApplicationInfo: Equatable, Sendable {
    public var bundleIdentifier: String?
    public var localizedName: String?
    public var processIdentifier: Int32
    public var isActive: Bool

    public init(
        bundleIdentifier: String?,
        localizedName: String?,
        processIdentifier: Int32,
        isActive: Bool
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
        self.processIdentifier = processIdentifier
        self.isActive = isActive
    }
}

/// Launch Services / process query seam. Tests inject a fake directory of apps.
public protocol ApplicationQuerying: Sendable {
    func application(withBundleIdentifier id: String) -> InstalledApplication?
    func runningApplications() -> [RunningApplicationInfo]
}

public struct ResolvedApplication: Equatable, Sendable {
    public var kind: TargetKind
    public var bundleIdentifier: String
    public var displayName: String
    public var shortVersion: String?
    public var pathDescription: String
    public var isInstalled: Bool
    public var isRunning: Bool
    public var isFrontmost: Bool
    public var processIdentifier: Int32?
    public var matchedCandidateIndex: Int?
    public var matchedByProcessName: Bool

    public init(
        kind: TargetKind,
        bundleIdentifier: String,
        displayName: String,
        shortVersion: String? = nil,
        pathDescription: String,
        isInstalled: Bool,
        isRunning: Bool,
        isFrontmost: Bool,
        processIdentifier: Int32? = nil,
        matchedCandidateIndex: Int? = nil,
        matchedByProcessName: Bool = false
    ) {
        self.kind = kind
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.shortVersion = shortVersion
        self.pathDescription = pathDescription
        self.isInstalled = isInstalled
        self.isRunning = isRunning
        self.isFrontmost = isFrontmost
        self.processIdentifier = processIdentifier
        self.matchedCandidateIndex = matchedCandidateIndex
        self.matchedByProcessName = matchedByProcessName
    }
}

/// Resolves a target definition against installed and running applications using ordered fallbacks.
public struct TargetResolver: Sendable {
    public init() {}

    public func resolve(
        definition: TargetDefinition,
        using query: ApplicationQuerying
    ) -> ResolvedApplication? {
        let running = query.runningApplications()
        var installedByID: [String: (index: Int, app: InstalledApplication)] = [:]
        for (index, bundleID) in definition.candidateBundleIdentifiers.enumerated() {
            if installedByID[bundleID] == nil, let app = query.application(withBundleIdentifier: bundleID) {
                installedByID[bundleID] = (index, app)
            }
        }

        for (index, bundleID) in definition.candidateBundleIdentifiers.enumerated() {
            guard let runningApp = running.first(where: { $0.bundleIdentifier == bundleID }) else {
                continue
            }
            let installed = installedByID[bundleID]?.app
            return ResolvedApplication(
                kind: definition.kind,
                bundleIdentifier: bundleID,
                displayName: installed?.displayName ?? runningApp.localizedName ?? definition.displayName,
                shortVersion: installed?.shortVersion,
                pathDescription: installed?.pathDescription ?? PathSanitizer.unknownInstalledLocation,
                isInstalled: true,
                isRunning: true,
                isFrontmost: runningApp.isActive,
                processIdentifier: runningApp.processIdentifier,
                matchedCandidateIndex: index,
                matchedByProcessName: false
            )
        }

        for processName in definition.candidateProcessNames {
            guard let runningApp = running.first(where: { $0.localizedName == processName }) else {
                continue
            }
            let bundleID = runningApp.bundleIdentifier
                ?? definition.candidateBundleIdentifiers.first
                ?? processName
            let installed = installedByID[bundleID]?.app
                ?? definition.candidateBundleIdentifiers.compactMap { installedByID[$0]?.app }.first
            let index = definition.candidateBundleIdentifiers.firstIndex(of: bundleID)
            return ResolvedApplication(
                kind: definition.kind,
                bundleIdentifier: bundleID,
                displayName: installed?.displayName ?? processName,
                shortVersion: installed?.shortVersion,
                pathDescription: installed?.pathDescription ?? PathSanitizer.unknownInstalledLocation,
                isInstalled: true,
                isRunning: true,
                isFrontmost: runningApp.isActive,
                processIdentifier: runningApp.processIdentifier,
                matchedCandidateIndex: index,
                matchedByProcessName: true
            )
        }

        if let firstInstalled = definition.candidateBundleIdentifiers.enumerated().compactMap({ index, id -> (Int, InstalledApplication)? in
            guard let app = installedByID[id]?.app else { return nil }
            return (index, app)
        }).first {
            return ResolvedApplication(
                kind: definition.kind,
                bundleIdentifier: firstInstalled.1.bundleIdentifier,
                displayName: firstInstalled.1.displayName,
                shortVersion: firstInstalled.1.shortVersion,
                pathDescription: firstInstalled.1.pathDescription,
                isInstalled: true,
                isRunning: false,
                isFrontmost: false,
                processIdentifier: nil,
                matchedCandidateIndex: firstInstalled.0,
                matchedByProcessName: false
            )
        }

        return nil
    }
}

public enum PathSanitizer {
    public static let unknownInstalledLocation = "(installed location withheld)"

    public static func describe(path: String) -> String {
        if path.hasPrefix("/Applications/") || path.hasPrefix("/System/") {
            return path
        }
        if let slash = path.lastIndex(of: "/") {
            return String(path[path.index(after: slash)...]) + " (outside /Applications)"
        }
        return unknownInstalledLocation
    }
}
