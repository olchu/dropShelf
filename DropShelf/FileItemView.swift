import Cocoa
import UniformTypeIdentifiers

class FileItemView: NSView {
    private let fileURL: URL
    var onRemove: (() -> Void)?
    
    private var imageView: NSImageView!
    private var nameLabel: NSTextField!
    private var removeButton: NSButton!
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(frame: NSRect(x: 0, y: 0, width: 120, height: 115))
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.12).cgColor  // Светлее на тёмном фоне
        layer?.cornerRadius = 10
        
        // Иконка файла
        imageView = NSImageView(frame: NSRect(x: 15, y: 30, width: 50, height: 50))
        imageView.image = NSWorkspace.shared.icon(forFile: fileURL.path)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(imageView)
        
        // Название файла
        nameLabel = NSTextField(labelWithString: fileURL.lastPathComponent)
        nameLabel.frame = NSRect(x: 5, y: 10, width: 70, height: 15)
        nameLabel.font = .systemFont(ofSize: 10)
        nameLabel.textColor = .white
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingMiddle
        addSubview(nameLabel)
        
        // Кнопка удаления
        removeButton = NSButton(frame: NSRect(x: 60, y: 80, width: 16, height: 16))
        removeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove")
        removeButton.isBordered = false
        removeButton.target = self
        removeButton.action = #selector(removeClicked)
        removeButton.alphaValue = 0.7
        addSubview(removeButton)
        
        // Регистрируем как источник перетаскивания
        registerForDraggedTypes([.fileURL])
    }
    
    @objc private func removeClicked() {
        onRemove?()
    }
    
    // Поддержка перетаскивания файла из этого view
    override func mouseDown(with event: NSEvent) {
        // Используем NSFilePromiseProvider для правильной работы с файлами
        let provider = NSFilePromiseProvider(fileType: kUTTypeFileURL as String, delegate: self)
        provider.userInfo = fileURL
        
        // Создаём красивый preview для перетаскивания
        let iconSize = NSSize(width: 64, height: 64)
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        icon.size = iconSize
        
        let draggingItem = NSDraggingItem(pasteboardWriter: provider)
        
        // Получаем позицию клика относительно view
        let mouseLocation = convert(event.locationInWindow, from: nil)
        
        // Центрируем иконку относительно курсора
        let draggingFrame = NSRect(
            x: mouseLocation.x - iconSize.width / 2,
            y: mouseLocation.y - iconSize.height / 2,
            width: iconSize.width,
            height: iconSize.height
        )
        
        draggingItem.setDraggingFrame(draggingFrame, contents: icon)
        
        let draggingSession = beginDraggingSession(with: [draggingItem], event: event, source: self)
        
        // ВАЖНО: отключаем анимацию возврата
        draggingSession.animatesToStartingPositionsOnCancelOrFail = false
        draggingSession.draggingFormation = .none
    }
}

// MARK: - NSDraggingSource
extension FileItemView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return [.move, .copy]
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        NSLog("🎯 Drag ended with operation: \(operation.rawValue)")
        
        if operation.isEmpty {
            NSLog("❌ Drag was cancelled")
        }
        // Удаление файла произойдёт в filePromiseProvider:didFinish
    }
    
    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        NSLog("🚀 Drag session beginning")
    }
}

// MARK: - NSFilePromiseProviderDelegate
extension FileItemView: NSFilePromiseProviderDelegate {
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        return fileURL.lastPathComponent
    }
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        NSLog("📝 Writing file to: \(url.path)")
        
        do {
            // Копируем файл в целевое место
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.copyItem(at: fileURL, to: url)
            
            NSLog("✅ File copied successfully")
            completionHandler(nil)
            
            // Теперь можно безопасно удалить исходный файл
            DispatchQueue.main.async {
                do {
                    if FileManager.default.fileExists(atPath: self.fileURL.path) {
                        try FileManager.default.removeItem(at: self.fileURL)
                        NSLog("🗑 Original file deleted: \(self.fileURL.lastPathComponent)")
                    }
                } catch {
                    NSLog("⚠️ Failed to delete original file: \(error)")
                }
                
                // Удаляем из окна
                self.onRemove?()
            }
        } catch {
            NSLog("❌ Failed to copy file: \(error)")
            completionHandler(error)
        }
    }
    
    func operationMask(forDraggingInfo draggingInfo: NSDraggingInfo) -> NSDragOperation {
        return [.move, .copy]
    }
}
