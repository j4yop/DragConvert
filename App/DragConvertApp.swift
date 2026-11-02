import AppKit
import Foundation
import CapabilityGraph
import JobCore
import EngineKit
import PDFEngine
import ImageEngine

@main
struct DragConvertApp {
    @MainActor
    static func main() {
        if runHeadlessIfRequested() { return }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    /// `DragConvert --convert <file> --to <ext>`
    @MainActor
    private static func runHeadlessIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--convert"), args.count > flag + 1 else {
            return false
        }
        let input = URL(fileURLWithPath: args[flag + 1])
        var target = "jpg"
        if let to = args.firstIndex(of: "--to"), args.count > to + 1 {
            target = args[to + 1]
        }

        // Restore the sandbox bookmark without prompting.
        _ = FolderAccess.shared.ensureAccess(promptIfNeeded: false)
        Log.write("headless convert \(input.path) → \(target)")

        let job = Job(inputs: [input], operation: .convert(to: target))
        let engine: Engine?
        switch FileKind.detect(input) {
        case .pdf: engine = PDFToImageEngine()
        case .image: engine = ImageConvertEngine()
        default: engine = nil
        }
        guard let engine, engine.canHandle(job) else {
            FileHandle.standardError.write(Data("unsupported conversion\n".utf8))
            exit(2)
        }

        Task { @MainActor in
            do {
                let outputs = try await Task.detached {
                    try await engine.run(job) { _ in }
                }.value
                print(outputs.map(\.path).joined(separator: "\n"))
                exit(0)
            } catch {
                FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                exit(1)
            }
        }
        RunLoop.main.run()
        return true
    }
}
