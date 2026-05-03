import Cocoa
import SwiftUI

@available(macOS 26.0, *)
private struct GlassPanel: View {
    var cornerRadius: CGFloat
    var body: some View {
        Color.clear
            .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

class ShelfViewController: NSViewController {
    private var overlapView: OverlapStackView!
    private var titleLabel: NSTextField!
    private var fileItems: [URL] = []

    // Кнопка закрытия
    private var closeButton: CloseButton!
    // Радиус скругления окна/панели
    private let cornerRadius: CGFloat = 20.0

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupDragAndDrop()
    }

    private func setupUI() {
        // Drop target
        let dropTargetView = DropTargetView(frame: view.bounds)
        dropTargetView.autoresizingMask = [.width, .height]
        dropTargetView.onFilesDropped = { [weak self] urls in urls.forEach { self?.addFile(url: $0) } }
        view.addSubview(dropTargetView)

        // Фон панели — Liquid Glass (macOS 26+)
        if #available(macOS 26.0, *) {
            let glassHost = NSHostingView(rootView: GlassPanel(cornerRadius: cornerRadius))
            glassHost.frame = view.bounds
            glassHost.autoresizingMask = [.width, .height]
            dropTargetView.addSubview(glassHost)
        } else {
            let visualEffect = NSVisualEffectView(frame: view.bounds)
            visualEffect.material = .popover
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            visualEffect.wantsLayer = true
            visualEffect.layer?.cornerRadius = cornerRadius
            visualEffect.autoresizingMask = [.width, .height]

            let darkOverlay = CALayer()
            darkOverlay.backgroundColor = NSColor(white: 0.1, alpha: 0.25).cgColor
            darkOverlay.frame = view.bounds
            darkOverlay.cornerRadius = cornerRadius
            darkOverlay.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            visualEffect.layer?.addSublayer(darkOverlay)
            dropTargetView.addSubview(visualEffect)
        }

        // Заголовок
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

        // Стопка превью
        overlapView = OverlapStackView(frame: view.bounds)
        overlapView.autoresizingMask = [.width, .height]
        overlapView.wantsLayer = true
        overlapView.layer?.masksToBounds = false
        overlapView.maxVisible = 4
        overlapView.baseAngles = [-12, -6, 6, 12]
        dropTargetView.addSubview(overlapView)
        overlapView.isHidden = true

        overlapView.onFilesDropped = { [weak self] urls in urls.forEach { self?.addFile(url: $0) } }
        overlapView.onRemoveAll = { [weak self] in self?.clearAll() }

        // Кнопка: белый круг α=0.3; на ховере α=0.7; белый «x»
        let diameter = cornerRadius * 1.5
        closeButton = CloseButton(diameter: diameter)
        closeButton.normalAlpha = 0.10
        closeButton.hoverAlpha  = 0.25
        closeButton.target = self
        closeButton.action = #selector(hideWindow)
        dropTargetView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8)
        ])
    }

    @objc private func hideWindow() { view.window?.orderOut(nil) }

    // DnD
    private func setupDragAndDrop() { view.registerForDraggedTypes([.fileURL]) }
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }
        urls.forEach { addFile(url: $0) }
        return true
    }

    // Files
    private func addFile(url: URL) {
        guard !fileItems.contains(url) else { return }
        fileItems.append(url)
        titleLabel.isHidden = true
        overlapView.isHidden = false

        let fileView = FileItemView(fileURL: url)
        overlapView.addSubview(fileView)
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
