import Cocoa

class DragDetector {
    private var eventMonitor: Any?
    private var lastDeltaY: CGFloat = 0
    private var reversalCount = 0
    private var windowStart: Date?

    private let minDelta: CGFloat = 6
    private let timeWindow: TimeInterval = 0.5
    private let requiredReversals = 2

    var onShakeDetected: ((CGPoint) -> Void)?

    private var knownDragChangeCount: Int = NSPasteboard(name: .drag).changeCount

    func startMonitoring() {
        guard eventMonitor == nil else { return }
        reset()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            if event.type == .leftMouseUp {
                self?.reset()
            } else {
                self?.handleDrag(event: event)
            }
        }
    }

    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    func restartMonitoring() {
        stopMonitoring()
        reset()
        startMonitoring()
    }

    private func isFileDragging() -> Bool {
        let pb = NSPasteboard(name: .drag)
        return pb.changeCount != knownDragChangeCount
    }

    private func handleDrag(event: NSEvent) {
        guard isFileDragging() else { return }
        let dy = event.deltaY
        guard abs(dy) > minDelta else { return }

        let now = Date()

        if let start = windowStart, now.timeIntervalSince(start) > timeWindow {
            reset()
        }

        // direction reversal
        if lastDeltaY * dy < 0 {
            if windowStart == nil { windowStart = now }
            reversalCount += 1
            if reversalCount >= requiredReversals {
                stopMonitoring()
                onShakeDetected?(NSEvent.mouseLocation)
                reset()
                return
            }
        }

        lastDeltaY = dy
    }

    private func reset() {
        lastDeltaY = 0
        reversalCount = 0
        windowStart = nil
        knownDragChangeCount = NSPasteboard(name: .drag).changeCount
    }
}
