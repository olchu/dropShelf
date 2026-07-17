import Foundation

enum WebLocation {
    static func destination(for fileURL: URL) -> URL? {
        guard fileURL.pathExtension.lowercased() == "webloc",
              let data = try? Data(contentsOf: fileURL),
              let propertyList = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ),
              let dictionary = propertyList as? [String: Any],
              let value = dictionary["URL"] as? String else { return nil }
        return URL(string: value)
    }

    static func displayName(for fileURL: URL) -> String {
        guard let destination = destination(for: fileURL) else {
            return fileURL.lastPathComponent
        }
        return destination.host?.replacingOccurrences(of: "www.", with: "")
            ?? destination.absoluteString
    }
}
