import Cocoa

enum PasteboardImporter {
    static let supportedTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        .URL,
        .png,
        .tiff,
        .string
    ]

    @discardableResult
    static func importItems(
        from pasteboard: NSPasteboard,
        completion: @escaping ([URL]) -> Void
    ) -> Bool {
        let localURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []

        if localURLs.isEmpty == false {
            completion(localURLs)
            return true
        }

        if let image = NSImage(pasteboard: pasteboard),
           let imageURL = saveImage(image) {
            completion([imageURL])
            return true
        }

        let remoteURLs = remoteURLs(from: pasteboard)
        guard remoteURLs.isEmpty == false else { return false }

        Task {
            var importedURLs: [URL] = []
            for remoteURL in remoteURLs {
                if let importedURL = await resolve(remoteURL) {
                    importedURLs.append(importedURL)
                }
            }
            completion(importedURLs)
        }
        return true
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

    private static func resolve(_ remoteURL: URL) async -> URL? {
        do {
            let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return createWebLocation(for: remoteURL)
            }

            guard responseRepresentsFile(httpResponse, remoteURL: remoteURL) else {
                return createWebLocation(for: remoteURL)
            }

            let filename = httpResponse.suggestedFilename
                ?? remoteURL.lastPathComponent
            let destination = try uniqueDestination(for: filename)
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            return destination
        } catch {
            return createWebLocation(for: remoteURL)
        }
    }

    private static func responseRepresentsFile(
        _ response: HTTPURLResponse,
        remoteURL: URL
    ) -> Bool {
        let contentDisposition = response.value(forHTTPHeaderField: "Content-Disposition")?
            .lowercased() ?? ""
        if contentDisposition.contains("attachment") {
            return true
        }

        if let mimeType = response.mimeType?.lowercased() {
            return mimeType != "text/html" && mimeType != "application/xhtml+xml"
        }

        let pathExtension = remoteURL.pathExtension.lowercased()
        return pathExtension.isEmpty == false
            && pathExtension != "html"
            && pathExtension != "htm"
    }

    private static func uniqueDestination(for suggestedFilename: String) throws -> URL {
        let directory = try importDirectory()
        let safeName = URL(fileURLWithPath: suggestedFilename).lastPathComponent
        let filename = safeName.isEmpty ? "Downloaded File" : safeName
        var destination = directory.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: destination.path) else {
            return destination
        }

        let stem = destination.deletingPathExtension().lastPathComponent
        let pathExtension = destination.pathExtension
        var index = 2
        repeat {
            let candidate = pathExtension.isEmpty
                ? "\(stem) \(index)"
                : "\(stem) \(index).\(pathExtension)"
            destination = directory.appendingPathComponent(candidate)
            index += 1
        } while FileManager.default.fileExists(atPath: destination.path)
        return destination
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
