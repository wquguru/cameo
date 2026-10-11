import AppKit
import CameoShow
import CoreGraphics

/// Other apps' windows on the current Space, frontmost first, as places a package can stand.
/// Reads only window frames (no titles), which needs no Screen Recording permission.
enum WindowList {
    static func ledges() -> [Ledge] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]],
              let primary = NSScreen.screens.first else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        // Window bounds are in the global display space: origin at the primary screen's top-left, y down.
        let flip = primary.frame.maxY
        return info.compactMap { w in
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowOwnerPID as String] as? Int32) != me,
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.1,
                  let id = w[kCGWindowNumber as String] as? Int,
                  let dict = w[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dict),
                  rect.width >= 80, rect.height >= 60 else { return nil }
            return Ledge(id: id, minX: rect.minX, maxX: rect.maxX, minY: flip - rect.maxY, maxY: flip - rect.minY)
        }
    }
}
