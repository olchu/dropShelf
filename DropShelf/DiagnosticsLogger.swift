import Foundation
import OSLog

@MainActor
final class DiagnosticsLogger {
    static let shared = DiagnosticsLogger()

    private let systemLogger = Logger(subsystem: "olchu.DropShelf", category: "Lifecycle")
    private let fileManager = FileManager.default
    private let formatter = ISO8601DateFormatter()
    private let sessionMarkerName = "active-session.txt"
    private let logFileName = "latest.log"

    private(set) lazy var directoryURL: URL = {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return applicationSupport
            .appendingPathComponent("DropShelf", isDirectory: true)
            .appendingPathComponent("Diagnostics", isDirectory: true)
    }()

    private init() {}

    func startSession() {
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            rotateLogIfNeeded()

            let markerURL = directoryURL.appendingPathComponent(sessionMarkerName)
            if fileManager.fileExists(atPath: markerURL.path) {
                warning("Previous session did not record a normal termination")
            }

            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
            let marker = "started=\(formatter.string(from: Date())) pid=\(ProcessInfo.processInfo.processIdentifier) version=\(version) build=\(build)\n"
            try marker.write(to: markerURL, atomically: true, encoding: .utf8)
            info("Session started; version=\(version) build=\(build)")
        } catch {
            systemLogger.error("Unable to initialize diagnostics: \(error.localizedDescription, privacy: .public)")
        }
    }

    func finishSession() {
        info("Session finished normally")
        let markerURL = directoryURL.appendingPathComponent(sessionMarkerName)
        try? fileManager.removeItem(at: markerURL)
    }

    func info(_ message: String) {
        systemLogger.info("\(message, privacy: .public)")
        append(level: "INFO", message: message)
    }

    func warning(_ message: String) {
        systemLogger.warning("\(message, privacy: .public)")
        append(level: "WARNING", message: message)
    }

    private func append(level: String, message: String) {
        let line = "\(formatter.string(from: Date())) [\(level)] \(message)\n"
        let logURL = directoryURL.appendingPathComponent(logFileName)
        guard let data = line.data(using: .utf8) else { return }

        do {
            if !fileManager.fileExists(atPath: logURL.path) {
                try Data().write(to: logURL)
            }
            let handle = try FileHandle(forWritingTo: logURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            systemLogger.error("Unable to write diagnostics: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func rotateLogIfNeeded() {
        let logURL = directoryURL.appendingPathComponent(logFileName)
        let attributes = try? fileManager.attributesOfItem(atPath: logURL.path)
        let size = attributes?[.size] as? Int64 ?? 0
        guard size > 1_000_000 else { return }

        let previousURL = directoryURL.appendingPathComponent("previous.log")
        try? fileManager.removeItem(at: previousURL)
        try? fileManager.moveItem(at: logURL, to: previousURL)
    }
}
