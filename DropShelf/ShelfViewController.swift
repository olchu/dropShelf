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
        // Drop-target слой
        let dropTargetView = DropTargetView(frame: view.bounds)
        dropTargetView.autoresizingMask = [.width, .height]
        dropTargetView.onFilesDropped = { [weak self] urls in
            urls.forEach { self?.addFile(url: $0) }
        }
        view.addSubview(dropTargetView)

        // Фон с blur
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

        // Заголовок в центре
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

        // Наша «веерная» стопка карточек (все центры совпадают, верхняя без поворота)
        overlapView = OverlapStackView(frame: view.bounds)
        overlapView.autoresizingMask = [.width, .height]
        overlapView.wantsLayer = true
        overlapView.layer?.masksToBounds = false
        overlapView.maxVisible = 4
        overlapView.baseAngles = [-12, -6, 6, 12] // можно подрегулировать
        dropTargetView.addSubview(overlapView)
        overlapView.isHidden = true
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

        // Показать стопку, скрыть заголовок
        titleLabel.isHidden = true
        overlapView.isHidden = false

        let fileView = FileItemView(fileURL: url)
        fileView.onRemove = { [weak self, weak fileView] in
            guard let self, let fileView else { return }
            self.removeFile(url: url, view: fileView)
        }
        overlapView.addSubview(fileView) // контейнер сам разложит по центру с поворотами
        overlapView.needsLayout = true
        overlapView.layoutSubtreeIfNeeded()
    }

    private func removeFile(url: URL, view: NSView) {
        if let idx = fileItems.firstIndex(of: url) {
            fileItems.remove(at: idx)
        }
        overlapView.removeSubview(view)
        overlapView.layoutSubtreeIfNeeded()

        if fileItems.isEmpty {
            overlapView.isHidden = true
            titleLabel.isHidden = false
        }
    }
}
