import Cocoa

class FileItemView: NSView {
    private let fileURL: URL
    var onRemove: (() -> Void)?
    
    private var imageView: NSImageView!
    private var nameLabel: NSTextField!
    private var removeButton: NSButton!
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(frame: NSRect(x: 0, y: 0, width: 80, height: 100))
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.3).cgColor
        layer?.cornerRadius = 8
        
        NSLog("🎨 Setting up FileItemView with frame: \(self.frame)")
        
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
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(fileURL.absoluteString, forType: .fileURL)
        
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(self.bounds, contents: imageView.image)
        
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
}

// MARK: - NSDraggingSource
extension FileItemView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}
