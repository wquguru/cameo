import Foundation

/// A build run from a checkout rather than installed from a release, so the two can run side by
/// side and be told apart. `scripts/build.sh` without `RELEASE=1` stamps `CameoDev` (branch and
/// commit) into Info.plist and gives the app its own bundle id; `swift run` has no bundle at all.
enum DevBuild {
    /// Where it came from ("main @ 1b3d7f7", "swift run"), or nil for a release build.
    static let label: String? = {
        if let stamp = Bundle.main.object(forInfoDictionaryKey: "CameoDev") as? String { return stamp }
        return Bundle.main.bundleIdentifier == nil ? "swift run" : nil
    }()

    static var isDev: Bool { label != nil }
}
