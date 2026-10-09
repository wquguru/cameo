import AppKit
import CryptoKit

/// Installs an update in place: downloads the release zip, checks it against checksums.txt,
/// unpacks it, then hands off to a small shell script that swaps the app bundle once Cameo
/// has quit and relaunches it. URLSession downloads carry no quarantine, so the new
/// (ad-hoc signed) app opens without a Gatekeeper prompt.
@MainActor
enum Updater {
    struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }

    static func install(_ update: UpdateChecker.Update) async throws {
        guard let zipURL = update.zip, let checksumsURL = update.checksums else {
            throw Failure("这个版本没有可安装的包")
        }
        let app = Bundle.main.bundleURL
        let folder = app.deletingLastPathComponent()
        guard !app.path.contains("/AppTranslocation/"),
              FileManager.default.isWritableFile(atPath: folder.path) else {
            throw Failure("Cameo 所在位置无法写入，请先把它移到“应用程序”文件夹")
        }

        let work = FileManager.default.temporaryDirectory.appendingPathComponent("CameoUpdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        do {
            let zip = work.appendingPathComponent(zipURL.lastPathComponent)
            let (downloaded, _) = try await URLSession.shared.download(from: zipURL)
            try FileManager.default.moveItem(at: downloaded, to: zip)
            let (checksums, _) = try await URLSession.shared.data(from: checksumsURL)
            guard let expected = expectedHash(of: zip.lastPathComponent, in: checksums),
                  try await sha256(of: zip) == expected else {
                throw Failure("下载的文件校验失败")
            }

            let unpacked = work.appendingPathComponent("unpacked")
            try await run("/usr/bin/ditto", "-x", "-k", zip.path, unpacked.path)
            let newApp = unpacked.appendingPathComponent("Cameo.app")
            let info = Bundle(url: newApp)?.infoDictionary
            guard info?["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
                  info?["CFBundleShortVersionString"] as? String == update.version else {
                throw Failure("下载的包与新版本不符")
            }
            try await run("/usr/bin/codesign", "--verify", "--deep", "--strict", newApp.path)

            let script = work.appendingPathComponent("swap.sh")
            try swapScript.write(to: script, atomically: true, encoding: .utf8)
            let swap = Process()
            swap.executableURL = URL(fileURLWithPath: "/bin/sh")
            swap.arguments = [script.path, String(getpid()), app.path, newApp.path, work.path]
            try swap.run()
        } catch {
            try? FileManager.default.removeItem(at: work)
            throw error
        }
        NSApp.terminate(nil)
    }

    /// Waits for Cameo to quit, moves the old bundle aside (restoring it if the new one can't be
    /// moved in), relaunches, and cleans up. Arguments: pid, app path, new app path, work folder.
    private static let swapScript = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        if mv "$2" "$4/old.app"; then
          if mv "$3" "$2"; then rm -rf "$4/old.app"; else mv "$4/old.app" "$2"; fi
        fi
        open "$2"
        rm -rf "$4"
        """

    /// The hash listed for `name` in a `shasum -a 256` file.
    nonisolated static func expectedHash(of name: String, in checksums: Data) -> String? {
        String(decoding: checksums, as: UTF8.self)
            .split(separator: "\n")
            .map { $0.split(separator: " ", omittingEmptySubsequences: true) }
            .first { $0.count == 2 && $0[1].trimmingCharacters(in: CharacterSet(charactersIn: "*")) == name }
            .map { $0[0].lowercased() }
    }

    private static func sha256(of file: URL) async throws -> String {
        try await Task.detached {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            var hasher = SHA256()
            while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        }.value
    }

    private static func run(_ tool: String, _ arguments: String...) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { p in
                p.terminationStatus == 0 ? done.resume() : done.resume(throwing: Failure("安装包无效"))
            }
            do { try process.run() } catch { done.resume(throwing: error) }
        }
    }
}
