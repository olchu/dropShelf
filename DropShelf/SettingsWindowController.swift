import Cocoa
import ServiceManagement
import SwiftUI

private struct SettingsView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Toggle(
                "Launch DropShelf at login",
                isOn: Binding(
                    get: { launchAtLogin },
                    set: { updateLaunchAtLogin($0) }
                )
            )

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 420, height: 160)
        .onAppear(perform: refreshStatus)
    }

    private func updateLaunchAtLogin(_ isEnabled: Bool) {
        launchAtLogin = isEnabled
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshStatus()
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            statusMessage = error.localizedDescription
        }
    }

    private func refreshStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLogin = true
            statusMessage = nil
        case .requiresApproval:
            launchAtLogin = false
            statusMessage = "Allow DropShelf in System Settings → General → Login Items."
        case .notFound:
            launchAtLogin = false
            statusMessage = "Launch at login is unavailable for this build."
        case .notRegistered:
            launchAtLogin = false
            statusMessage = nil
        @unknown default:
            launchAtLogin = false
            statusMessage = nil
        }
    }
}

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "DropShelf Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        self.init(window: window)
    }

    func present() {
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
