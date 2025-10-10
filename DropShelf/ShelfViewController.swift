import Cocoa

class ShelfViewController: NSViewController {
    private var stackView: NSStackView!
    private var scrollView: NSScrollView!
    private var titleLabel: NSTextField!
    private var fileItems: [URL] = []
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDragAndDrop()
    }
    
    private func setupUI() {
        // Drop-target слой
        let dropTargetView = DropTargetView(frame: view.bounds)
        dropTargetView.autoresizingMask = [.width, .height]
        dropTargetView.onFilesDropped = { [weak self] urls in
            NSLog("🎉 Files dropped: \(urls)")
            urls.forEach { self?.addFile(url: $0) }
        }
        view.addSubview(dropTargetView)
        
        // Фон с blur-эффектом
        let visualEffect = NSVisualEffectView(frame: view.bounds)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 20
        visualEffect.autoresizingMask = [.width, .height]
        
        let darkOverlay = CALayer()
        darkOverlay.backgroundColor = NSColor(white: 0.1, alpha: 0.75).cgColor
        darkOverlay.frame = view.bounds
        darkOverlay.cornerRadius = 20
        darkOverlay.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        visualEffect.layer?.addSublayer(darkOverlay)
        dropTargetView.addSubview(visualEffect)
        
        // Заголовок по центру до первого дропа
        titleLabel = NSTextField(labelWithString: "Drop files here")
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = NSColor(white: 0.9, alpha: 0.85)
        titleLabel.alignment = .center
        titleLabel.backgroundColor = .clear
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        dropTargetView.addSubview(titleLabel)
        
        // Скролл (изначально скрыт)
        scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.isHidden = true
        dropTargetView.addSubview(scrollView)
        
        // Документ-вью (контейнер для контента)
        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView
        
        // Горизонтальный стек с файлами
        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 10
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        stackView.translatesAutoresizingMaskIntoConstraints = false
        // ⭐ Чуть отступов и «ненулевая» высота/ширина, чтобы был размер даже с 1 элементом
        stackView.edgeInsets = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        stackView.setHuggingPriority(.required, for: .horizontal)
        stackView.setHuggingPriority(.required, for: .vertical)
        
        documentView.addSubview(stackView)
        
        let clipView = scrollView.contentView
        
        // Констрейнты
        NSLayoutConstraint.activate([
            // Заголовок по центру окна
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Скролл занимает окно с отступами
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            
            // Документ-вью центрируется и не меньше clipView
            documentView.centerXAnchor.constraint(equalTo: clipView.centerXAnchor),
            documentView.centerYAnchor.constraint(equalTo: clipView.centerYAnchor),
            documentView.widthAnchor.constraint(greaterThanOrEqualTo: clipView.widthAnchor),
            documentView.heightAnchor.constraint(greaterThanOrEqualTo: clipView.heightAnchor),
            
            // Стек по центру документа
            stackView.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: documentView.centerYAnchor),
            // Позволяем расти
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: documentView.leadingAnchor),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: documentView.topAnchor),
        ])
    }
    
    private func setupDragAndDrop() {
        view.registerForDraggedTypes([.fileURL])
    }
    
    // MARK: - Drag & Drop
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }
        for url in urls { addFile(url: url) }
        return true
    }
    
    // MARK: - Управление файлами
    private func addFile(url: URL) {
        guard !fileItems.contains(url) else { return }
        fileItems.append(url)

        titleLabel.isHidden = true
        scrollView.isHidden = false

        let fileView = FileItemView(fileURL: url)
        fileView.onRemove = { [weak self] in self?.removeFile(url: url) }
        stackView.addArrangedSubview(fileView)
    }
    
    private func removeFile(url: URL) {
        if let index = fileItems.firstIndex(of: url) {
            fileItems.remove(at: index)
            if index < stackView.arrangedSubviews.count {
                let viewToRemove = stackView.arrangedSubviews[index]
                stackView.removeArrangedSubview(viewToRemove)
                viewToRemove.removeFromSuperview()
            }
            if fileItems.isEmpty {
                titleLabel.isHidden = false
                scrollView.isHidden = true
            }
        }
    }
}
