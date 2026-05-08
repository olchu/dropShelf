import Cocoa

/// Превью файла: только изображение по центру с белой рамкой 2pt.
/// НЕ инициирует drag сам — drag всегда запускает OverlapStackView.
final class FileItemView: NSView {

    let fileURL: URL
    private let imageView = NSImageView()

    private let maxPreviewSide: CGFloat = 120

    private(set) var dragSnapshot: NSImage?

    private var cachedIntrinsic: NSSize = NSSize(width: 120, height: 120) {
        didSet { invalidateIntrinsicContentSize() }
    }
    override var intrinsicContentSize: NSSize { cachedIntrinsic }

    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false

        setupUI()
        loadPreviewAndSize()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.wantsLayer = true
        imageView.layer?.masksToBounds = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.borderWidth = 0
        imageView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
        imageView.layer?.shadowOpacity = 1
        imageView.layer?.shadowRadius = 6
        imageView.layer?.shadowOffset = .zero

        // Отключаем встроенный drag/dnd-приёмник NSImageView,
        // чтобы все dnd-события шли наверх (в OverlapStackView).
        imageView.unregisterDraggedTypes()

        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func loadPreviewAndSize() {
        let previewImage: NSImage?  = NSImage(contentsOf: fileURL)
        let isIcon = previewImage == nil
        let image = previewImage ?? NSWorkspace.shared.icon(forFile: fileURL.path)

        let fitted = isIcon
            ? NSSize(width: maxPreviewSide, height: maxPreviewSide)
            : fittedSize(for: image.size, maxSide: maxPreviewSide)

        imageView.image = image
        imageView.constraints
            .filter { ($0.firstAttribute == .width || $0.firstAttribute == .height) && $0.firstItem as? NSView === imageView }
            .forEach { $0.isActive = false }

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: fitted.width),
            imageView.heightAnchor.constraint(equalToConstant: fitted.height)
        ])

        cachedIntrinsic = fitted
        needsLayout = true
        layoutSubtreeIfNeeded()

        DispatchQueue.main.async { [weak self] in
            self?.cacheDragSnapshot()
        }
    }

    private func cacheDragSnapshot() {
        let size = bounds.size
        guard size.width > 0, size.height > 0,
              let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return }
        cacheDisplay(in: bounds, to: rep)
        let img = NSImage(size: size)
        img.addRepresentation(rep)
        dragSnapshot = img
    }

    private func fittedSize(for original: NSSize, maxSide: CGFloat) -> NSSize {
        guard original.width > 0, original.height > 0 else { return NSSize(width: maxPreviewSide, height: maxPreviewSide) }
        let scale = min(maxPreviewSide / original.width, maxPreviewSide / original.height, 1)
        return NSSize(width: round(original.width * scale), height: round(original.height * scale))
    }
}
