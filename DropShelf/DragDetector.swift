import Cocoa

class DragDetector {
    private var eventMonitor: Any?
    private var lastMouseLocation: CGPoint = .zero
    private var shakeStartTime: Date?
    private var shakeCount = 0

    var onShakeDetected: ((CGPoint) -> Void)?

    func startMonitoring() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            self?.handleMouseDrag(event: event)
        }
    }

    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleMouseDrag(event: NSEvent) {
        let currentLocation = NSEvent.mouseLocation
        let deltaY = abs(currentLocation.y - lastMouseLocation.y)

        if deltaY > 20 {
            let now = Date()
            if let startTime = shakeStartTime {
                if now.timeIntervalSince(startTime) < 0.7 {
                    shakeCount += 1
                    if shakeCount >= 2 {
                        stopMonitoring()
                        onShakeDetected?(currentLocation)
                        resetShakeDetection()
                    }
                } else {
                    shakeStartTime = now
                    shakeCount = 1
                }
            } else {
                shakeStartTime = now
                shakeCount = 1
            }
        }

        lastMouseLocation = currentLocation
    }

    private func resetShakeDetection() {
        shakeStartTime = nil
        shakeCount = 0
    }
}
