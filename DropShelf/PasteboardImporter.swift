import Cocoa

enum PasteboardImporter {
    static let supportedTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .URL,
        .png,
        .tiff,
        .string
    ]

    static func importItems(from pasteboard: NSPasteboard) -> [URL] {
        let localURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []

        if localURLs.isEmpty == false {
            return localURLs
        }

        if let image = NSImage(pasteboard: pasteboard),
           let imageURL = saveImage(image) {
            return [imageURL]
        }

        return remoteURLs(from: pasteboard).compactMap {
            createWebLocation(for: $0)
        }
    }

    private static func remoteURLs(from pasteboard: NSPasteboard) -> [URL] {
        let objectURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: nil
        ) as? [URL] ?? []

        let validObjectURLs = objectURLs.filter { isWebURL($0) }
        if validObjectURLs.isEmpty == false {
            return validObjectURLs
        }

        let value = pasteboard.string(forType: .URL)
            ?? pasteboard.string(forType: .string)
        guard let value,
              let url = URL(string: value),
              isWebURL(url) else { return [] }
        return [url]
    }

    private static func isWebURL(_ url: URL) -> Bool {
        url.scheme == "http" || url.scheme == "https"
    }

    private static func saveImage(_ image: NSImage) -> URL? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]),
              let directory = try? importDirectory() else { return nil }

        let url = directory.appendingPathComponent(
            "Dropped Image \(UUID().uuidString.prefix(8)).png"
        )
        do {
            try pngData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func createWebLocation(for remoteURL: URL) -> URL? {
        guard let directory = try? importDirectory(),
              let data = try? PropertyListSerialization.data(
                fromPropertyList: ["URL": remoteURL.absoluteString],
                format: .xml,
                options: 0
              ) else { return nil }

        let baseName = remoteURL.host ?? "Web Link"
        let url = directory.appendingPathComponent(
            "\(baseName) \(UUID().uuidString.prefix(8)).webloc"
        )
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func importDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DropShelf Imports", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
