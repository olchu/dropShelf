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
        // Базовый drop-target слой
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
        
        // ⚠️ Используем СВОЙСТВО контроллера (не локальную переменную)
        titleLabel = NSTextField(labelWithString: "Drop files here")
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = NSColor(white: 0.9, alpha: 0.85)
        titleLabel.alignment = .center
        titleLabel.backgroundColor = .clear
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        dropTargetView.addSubview(titleLabel)
        
        // ScrollView со стеком — изначально скрыт
        scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.isHidden = true
        dropTargetView.addSubview(scrollView)
        
        // Горизонтальный стек для файлов
        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 10
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        
        // Контейнер для документа scrollView
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 120))
        containerView.addSubview(stackView)
        stackView.frame = NSRect(x: 0, y: 0, width: 1000, height: 120)
        scrollView.documentView = containerView
        
        NSLog("📐 StackView configured with frame: \(stackView.frame)")
        
        // Констрейнты — центрируем заголовок, скролл по краям
        NSLayoutConstraint.activate([
            // Заголовок по центру окна 200×200
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Скролл занимает всё пространство с отступами
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
        ])
    }
    
    private func setupDragAndDrop() {
        view.registerForDraggedTypes([.fileURL])
    }
    
    // MARK: - Drag & Drop (если DropTargetView не обрабатывает сам)
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        
        for url in urls {
            addFile(url: url)
        }
        
        return true
    }
    
    // MARK: - Управление файлами
    private func addFile(url: URL) {
        guard !fileItems.contains(url) else {
            NSLog("⚠️ File already exists: \(url.lastPathComponent)")
            return
        }
        
        NSLog("➕ Adding file: \(url.lastPathComponent)")
        fileItems.append(url)
        
        // Прячем заголовок, показываем список
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.titleLabel.isHidden = true
            self.scrollView.isHidden = false
        }
        
        let fileView = FileItemView(fileURL: url)
        fileView.onRemove = { [weak self] in
            self?.removeFile(url: url)
        }
        
        stackView.addArrangedSubview(fileView)
        NSLog("📊 StackView now has \(stackView.arrangedSubviews.count) views")
    }
    
    private func removeFile(url: URL) {
        if let index = fileItems.firstIndex(of: url) {
            fileItems.remove(at: index)
            
            if index < stackView.arrangedSubviews.count {
                let viewToRemove = stackView.arrangedSubviews[index]
                stackView.removeArrangedSubview(viewToRemove)
                viewToRemove.removeFromSuperview()
            }
            
            // Если файлов нет — показываем заголовок обратно
            if fileItems.isEmpty {
                titleLabel.isHidden = false
                scrollView.isHidden = true
            }
        }
    }
}
