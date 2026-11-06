import Foundation

/// Stable identity of the shipping app. Kept in one place so the UI and the
/// tests cannot disagree about the name or the bundle identifier.
enum AppIdentity {
    static let displayName = "FacetForge"
    static let tagline = "iPad CAD for jewellers"
    static let bundleIdentifier = "com.shahroodazerov.facetforge"
    static let phase = 7

    static var phaseLabel: String { "Phase \(phase) · mesh kernel" }
}
