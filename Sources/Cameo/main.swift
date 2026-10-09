import AppKit

MainActor.assumeIsolated {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--render-poses"), i + 1 < args.count {
        PoseSheet.render(to: URL(fileURLWithPath: args[i + 1]))
        exit(0)
    }
    if let i = args.firstIndex(of: "--render-dmg-background"), i + 2 < args.count {
        do {
            try DMGBackground.render(to: URL(fileURLWithPath: args[i + 1]), scale: Int(args[i + 2]) ?? 1)
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(1)
        }
    }
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
