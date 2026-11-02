import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct MetadataRow: Identifiable, Sendable {
    public let id: String
    public let group: String
    public let field: String
    public let value: String

    public init(group: String, field: String, value: String) {
        self.id = "\(group).\(field)"
        self.group = group
        self.field = field
        self.value = value
    }
}

public enum ImageMetadata {
    public static func rows(for url: URL) -> [MetadataRow] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return [] }
        return rows(properties: properties, url: url)
    }

    static func rows(properties: [CFString: Any], url: URL) -> [MetadataRow] {
        let exif = cfDictionary(properties[kCGImagePropertyExifDictionary])
        let gps = cfDictionary(properties[kCGImagePropertyGPSDictionary])
        let tiff = cfDictionary(properties[kCGImagePropertyTIFFDictionary])

        var rows: [MetadataRow] = []
        func add(_ group: String, _ field: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            rows.append(MetadataRow(group: group, field: field, value: value))
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue
        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file
        add("File", "Name", url.lastPathComponent)
        if let size, size > 0 {
            add("File", "Size", byteFormatter.string(fromByteCount: Int64(size)))
        }
        add("File", "Created", formatFileDate(attributes?[.creationDate] as? Date))
        add("File", "Modified", formatFileDate(attributes?[.modificationDate] as? Date))

        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
        if let width, let height {
            add("Image", "Dimensions", "\(width) × \(height)")
        }
        add("Image", "Color", properties[kCGImagePropertyColorModel] as? String)
        if let depth = (properties[kCGImagePropertyDepth] as? NSNumber)?.intValue {
            add("Image", "Depth", "\(depth) bits/channel")
        }
        let dpiWidth = (properties[kCGImagePropertyDPIWidth] as? NSNumber)?.intValue
        let dpiHeight = (properties[kCGImagePropertyDPIHeight] as? NSNumber)?.intValue
        if let dpiWidth, let dpiHeight {
            add("Image", "DPI", "\(dpiWidth) × \(dpiHeight)")
        }
        if let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue {
            add("Image", "Orientation", orientationName(orientation))
        }

        add("Camera", "Make", string(tiff, kCGImagePropertyTIFFMake))
        add("Camera", "Model", string(tiff, kCGImagePropertyTIFFModel))
        add("Camera", "Lens", string(exif, kCGImagePropertyExifLensModel))
        if let exposure = double(exif, kCGImagePropertyExifExposureTime) {
            if exposure > 0, exposure < 1 {
                add("Camera", "Exposure", "1/\(Int((1 / exposure).rounded())) s")
            } else {
                add("Camera", "Exposure", String(format: "%.1f s", exposure))
            }
        }
        if let aperture = double(exif, kCGImagePropertyExifFNumber) {
            add("Camera", "Aperture", String(format: "f/%.1f", aperture))
        }
        if let iso = (exif?[kCGImagePropertyExifISOSpeedRatings] as? [NSNumber])?.first {
            add("Camera", "ISO", "ISO \(iso.intValue)")
        }
        if let focal = double(exif, kCGImagePropertyExifFocalLength) {
            add("Camera", "Focal length", String(format: "%.1f mm", focal))
        }

        add("Dates", "Taken", formatExifDate(string(exif, kCGImagePropertyExifDateTimeOriginal)))
        add("Dates", "Digitized", formatExifDate(string(exif, kCGImagePropertyExifDateTimeDigitized)))

        add("Location", "Latitude", coordinate(gps, kCGImagePropertyGPSLatitude, kCGImagePropertyGPSLatitudeRef, "N", "S"))
        add("Location", "Longitude", coordinate(gps, kCGImagePropertyGPSLongitude, kCGImagePropertyGPSLongitudeRef, "E", "W"))
        if let altitude = double(gps, kCGImagePropertyGPSAltitude) {
            let below = (gps?[kCGImagePropertyGPSAltitudeRef] as? NSNumber)?.intValue == 1
            add("Location", "Altitude", String(format: "%.0f m %@", altitude, below ? "below sea level" : ""))
        }

        add("Other", "Software", string(tiff, kCGImagePropertyTIFFSoftware))
        add("Other", "Artist", string(tiff, kCGImagePropertyTIFFArtist))
        add("Other", "Copyright", string(tiff, kCGImagePropertyTIFFCopyright))

        return rows
    }

    public static func hasLocation(_ rows: [MetadataRow]) -> Bool {
        rows.contains { $0.group == "Location" }
    }

    // MARK: Helpers

    /// Nested dictionaries bridge as `[String: Any]`, not `[CFString: Any]`.
    private static func cfDictionary(_ value: Any?) -> [CFString: Any]? {
        guard let dictionary = value as? [String: Any] else { return nil }
        var converted: [CFString: Any] = [:]
        for (key, value) in dictionary {
            converted[key as CFString] = value
        }
        return converted
    }

    private static func string(_ dictionary: [CFString: Any]?, _ key: CFString) -> String? {
        guard let value = dictionary?[key] else { return nil }
        if let string = value as? String, !string.isEmpty { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private static func double(_ dictionary: [CFString: Any]?, _ key: CFString) -> Double? {
        (dictionary?[key] as? NSNumber)?.doubleValue
    }

    private static func formatFileDate(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func formatExifDate(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy:MM:dd HH:mm:ss"
        guard let date = parser.date(from: raw) else { return raw }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func coordinate(
        _ gps: [CFString: Any]?,
        _ valueKey: CFString,
        _ referenceKey: CFString,
        _ positive: String,
        _ negative: String
    ) -> String? {
        guard let parts = gps?[valueKey] as? [NSNumber], parts.count >= 3 else { return nil }
        let value = parts[0].doubleValue
            + parts[1].doubleValue / 60
            + parts[2].doubleValue / 3600
        let reference = (gps?[referenceKey] as? String) ?? positive
        let signed = reference == negative ? -value : value
        return String(format: "%.6f° %@", abs(signed), reference)
    }

    private static func orientationName(_ value: Int) -> String {
        switch value {
        case 1: return "Normal"
        case 2: return "Mirrored"
        case 3: return "Rotated 180°"
        case 4: return "Mirrored vertically"
        case 5: return "Mirrored, rotated 90°"
        case 6: return "Rotated 90° clockwise"
        case 7: return "Mirrored, rotated 90°"
        case 8: return "Rotated 90° counter-clockwise"
        default: return "\(value)"
        }
    }
}
