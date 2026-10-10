import AppKit

/// How big the library draws its characters: View › Zoom In / Zoom Out / Actual Size
/// (⌘+, ⌘−, ⌘0), stored as `libraryZoom`, a step into `heights`.
@MainActor
final class LibraryZoom: NSObject {
    static let shared = LibraryZoom()
    static let key = "libraryZoom"
    static let heights: [CGFloat] = [72, 100, 136, 180]
    static let standard = 1

    static func height(_ step: Int) -> CGFloat { heights[min(max(step, 0), heights.count - 1)] }

    private var step: Int {
        get { UserDefaults.standard.object(forKey: Self.key) as? Int ?? Self.standard }
        set { UserDefaults.standard.set(min(max(newValue, 0), Self.heights.count - 1), forKey: Self.key) }
    }

    @objc func zoomIn(_ sender: Any?) { step += 1 }
    @objc func zoomOut(_ sender: Any?) { step -= 1 }
    @objc func actualSize(_ sender: Any?) { step = Self.standard }
}
