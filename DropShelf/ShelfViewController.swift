import Cocoa

class ShelfViewController: NSViewController {
    private var overlapView: OverlapStackView!
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
        // Drop target (фон/blur как раньше можно оставить в твоём коде)
        let dropTargetView = DropTargetView(frame: view.bounds)
        dropTargetView.autoresizingMask = [.width, .height]
        dropTargetView.onFilesDropped = { [weak self] urls in urls.forEach { self?.addFile(url: $0) } }
        view.addSubview(dropTargetView)

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

        // Центровой лейбл
        titleLabel = NSTextField(labelWithString: "Drop files here")
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = NSColor(white: 0.9, alpha: 0.85)
        titleLabel.alignment = .center
        titleLabel.backgroundColor = .clear
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        dropTargetView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Стопка
        overlapView = OverlapStackView(frame: view.bounds)
        overlapView.autoresizingMask = [.width, .height]
        overlapView.wantsLayer = true
        overlapView.layer?.masksToBounds = false
        overlapView.maxVisible = 4
        overlapView.baseAngles = [-12, -6, 6, 12]
        dropTargetView.addSubview(overlapView)
        overlapView.isHidden = true

        // dnd прямо по стопке (поверх иконок)
        overlapView.onFilesDropped = { [weak self] urls in
            urls.forEach { self?.addFile(url: $0) }
        }
        // очистка после группового дропа наружу
        overlapView.onRemoveAll = { [weak self] in
            self?.clearAll()
        }
    }

    private func setupDragAndDrop() {
        view.registerForDraggedTypes([.fileURL])
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }
        urls.forEach { addFile(url: $0) }
        return true
    }

    private func addFile(url: URL) {
        guard !fileItems.contains(url) else { return }
        fileItems.append(url)

        titleLabel.isHidden = true
        overlapView.isHidden = false

        let fileView = FileItemView(fileURL: url)
        overlapView.addSubview(fileView)    // OverlapStackView сам выровняет/повернёт
        overlapView.needsLayout = true
        overlapView.layoutSubtreeIfNeeded()
    }

    private func clearAll() {
        fileItems.removeAll()
        overlapView.subviews.forEach { $0.removeFromSuperview() }
        overlapView.isHidden = true
        titleLabel.isHidden = false
    }
}
