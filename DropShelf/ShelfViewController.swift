import Cocoa

class ShelfViewController: NSViewController {
    private var stackView: NSStackView!
    private var scrollView: NSScrollView!
    private var fileItems: [URL] = []
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDragAndDrop()
    }
    
    private func setupUI() {
        // Создаём DropTargetView как основу
        let dropTargetView = DropTargetView(frame: view.bounds)
        dropTargetView.autoresizingMask = [.width, .height]
        dropTargetView.onFilesDropped = { [weak self] urls in
            NSLog("🎉 Files dropped: \(urls)")
            urls.forEach { self?.addFile(url: $0) }
        }
        view.addSubview(dropTargetView)
        
        // Фон с blur эффектом
        let visualEffect = NSVisualEffectView(frame: view.bounds)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 12
        visualEffect.autoresizingMask = [.width, .height]
        dropTargetView.addSubview(visualEffect)
        
        // Заголовок
        let titleLabel = NSTextField(labelWithString: "Drop files here")
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        dropTargetView.addSubview(titleLabel)
        
        // Scroll view для файлов
        scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        dropTargetView.addSubview(scrollView)
        
        // Stack view для горизонтального расположения файлов
        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 10
        stackView.alignment = .centerY
        stackView.distribution = .gravityAreas
        
        // Важно: создаём флиппед view для правильной координатной системы
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 120))
        containerView.addSubview(stackView)
        
        stackView.frame = NSRect(x: 0, y: 0, width: 1000, height: 120)
        scrollView.documentView = containerView
        
        NSLog("📐 StackView configured with frame: \(stackView.frame)")
        
        // Constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 15),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -15)
        ])
    }
    
    private func setupDragAndDrop() {
        view.registerForDraggedTypes([.fileURL])
    }
    
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
    
    private func addFile(url: URL) {
        guard !fileItems.contains(url) else {
            NSLog("⚠️ File already exists: \(url.lastPathComponent)")
            return
        }
        
        NSLog("➕ Adding file: \(url.lastPathComponent)")
        fileItems.append(url)
        
        let fileView = FileItemView(fileURL: url)
        fileView.onRemove = { [weak self] in
            self?.removeFile(url: url)
        }
        
        stackView.addArrangedSubview(fileView)
        
        // Обновляем размер stackView
        let totalWidth = CGFloat(fileItems.count) * 90 // 80 + 10 spacing
        stackView.frame.size.width = max(totalWidth, 1000)
        if let containerView = stackView.superview {
            containerView.frame.size.width = stackView.frame.width
        }
        
        NSLog("📊 StackView now has \(stackView.arrangedSubviews.count) views, width: \(stackView.frame.width)")
    }
    
    private func removeFile(url: URL) {
        if let index = fileItems.firstIndex(of: url) {
            fileItems.remove(at: index)
            
            if index < stackView.arrangedSubviews.count {
                let viewToRemove = stackView.arrangedSubviews[index]
                stackView.removeArrangedSubview(viewToRemove)
                viewToRemove.removeFromSuperview()
            }
        }
    }
}
