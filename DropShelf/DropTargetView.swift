import Cocoa

class DropTargetView: NSView {
    var onFilesDropped: (([URL]) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL])
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        NSLog("🎯 DropTargetView: Dragging entered!")
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        NSLog("📦 DropTargetView: Perform drag operation!")
        
        let pasteboard = sender.draggingPasteboard
        
        // Пробуем получить файлы разными способами
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            NSLog("✅ Found \(urls.count) files")
            onFilesDropped?(urls)
            return true
        }
        
        // Альтернативный способ
        if let filenames = pasteboard.propertyList(forType: .fileURL) as? [String] {
            let urls = filenames.compactMap { URL(string: $0) }
            NSLog("✅ Found \(urls.count) files (method 2)")
            onFilesDropped?(urls)
            return true
        }
        
        NSLog("❌ No files found in pasteboard")
        return false
    }
}
