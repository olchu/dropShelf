import Cocoa

class DragDetector {
    private var eventMonitor: Any?
    private var lastMouseLocation: CGPoint = .zero
    private var shakeStartTime: Date?
    private var shakeCount = 0
    
    var onShakeDetected: (() -> Void)?
    
    func startMonitoring() {
        // Мониторим движения мыши с зажатой кнопкой (перетаскивание)
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
        
        // Проверяем быстрое движение мыши в разные стороны (встряхивание)
        let deltaX = abs(currentLocation.x - lastMouseLocation.x)
        
        if deltaX > 30 { // Порог для определения встряхивания
            let now = Date()
            
            if let startTime = shakeStartTime {
                // Если встряхивание произошло менее чем за 0.3 секунды
                if now.timeIntervalSince(startTime) < 0.3 {
                    shakeCount += 1
                    
                    // Если было 2+ быстрых движения - это встряхивание
                    if shakeCount >= 2 {
                        onShakeDetected?()
                        resetShakeDetection()
                    }
                } else {
                    // Слишком долго между движениями - сбрасываем
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
