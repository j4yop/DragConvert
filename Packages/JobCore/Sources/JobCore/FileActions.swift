import AppKit
import Foundation

public enum FileActions {
    /// Copies or moves a selection into a destination folder, never overwriting.
    /// Files already in the destination are skipped (a no-op, not a rename).
    /// Tangerine's Copy action: file URLs on the general pasteboard so
    /// Finder can paste them. It is not a copy-to-folder operation.
    public static func copyToPasteboard(
        _ urls: [URL],
        pasteboard: NSPasteboard = .general
    ) {
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }

    public static func transfer(
        _ urls: [URL],
        to destination: URL,
        moving: Bool
    ) throws -> [URL] {
        var outputs: [URL] = []
        let folder = destination.standardizedFileURL

        for url in urls {
            if url.deletingLastPathComponent().standardizedFileURL == folder {
                continue
            }
            let candidate = folder.appendingPathComponent(url.lastPathComponent)
            let target = DestinationPolicy.unique(candidate)
            if moving {
                try FileManager.default.moveItem(at: url, to: target)
            } else {
                try FileManager.default.copyItem(at: url, to: target)
            }
            outputs.append(target)
        }
        return outputs
    }
}
