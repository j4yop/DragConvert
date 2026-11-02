import Foundation
import Vision
import CoreGraphics

public enum QRCodeReader {
    /// Decodes QR payloads on-device. Returns unique values in detection order.
    public static func decode(at url: URL) -> [String] {
        guard let image = ImageConvertEngine.loadImage(at: url) else { return [] }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])

        let values = (request.results ?? []).compactMap(\.payloadStringValue)
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
