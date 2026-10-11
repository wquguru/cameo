// Cuts the figure out of every PNG in a folder with macOS's own foreground matting (Vision,
// macOS 14+, on the Neural Engine: ~0.2 s a frame against BiRefNet's ~10 s on the CPU).
// Usage: matte <in-dir> <out-dir>   writes an RGBA PNG of the same name per input; a frame with
// no foreground comes out fully transparent. common.py compiles and calls it (model "vision").
import CoreImage
import Foundation
import Vision

let args = CommandLine.arguments
guard args.count == 3 else { print("usage: matte <in-dir> <out-dir>"); exit(2) }
let inDir = URL(fileURLWithPath: args[1]), outDir = URL(fileURLWithPath: args[2])
let ctx = CIContext()
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
let files = try FileManager.default.contentsOfDirectory(at: inDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

for file in files {
    guard let image = CIImage(contentsOf: file) else { print("FAIL: can't read \(file.path)"); exit(1) }
    let handler = VNImageRequestHandler(ciImage: image)
    let request = VNGenerateForegroundInstanceMaskRequest()
    try handler.perform([request])
    var out = CIImage.empty().cropped(to: image.extent)
    if let r = request.results?.first {
        // Every instance: the figure plus whatever it holds; stray props are dropped later as specks.
        let mask = CIImage(cvPixelBuffer: try r.generateScaledMaskForImage(forInstances: r.allInstances, from: handler))
        out = image.applyingFilter("CIBlendWithMask", parameters: [
            "inputMaskImage": mask, "inputBackgroundImage": CIImage.empty()])
    }
    try ctx.writePNGRepresentation(of: out.cropped(to: image.extent), to: outDir.appendingPathComponent(file.lastPathComponent),
                                   format: .RGBA8, colorSpace: sRGB)
}
