import Cocoa
import QuickLookThumbnailing

/// Превью файла: только изображение по центру с белой рамкой 2pt.
/// НЕ инициирует drag сам — drag всегда запускает OverlapStackView.
final class FileItemView: NSView {

    let fileURL: URL
    private let imageView = NSImageView()

    private let maxPreviewSide: CGFloat = 120

    private(set) var dragSnapshot: NSImage?
    private var previewTask: Task<Void, Never>?
    private var hasLoadedPreview = false

    private var cachedIntrinsic: NSSize = NSSize(width: 120, height: 120) {
        didSet { invalidateIntrinsicContentSize() }
    }
    override var intrinsicContentSize: NSSize { cachedIntrinsic }

    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(frame: .zero)
        // Положение и поворот карточки вручную задаёт OverlapStackView.
        // Включённый Auto Layout без constraints мог сбрасывать frame,
        // особенно при пакетном добавлении нескольких файлов.
        translatesAutoresizingMaskIntoConstraints = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false

        setupUI()
        loadPreviewAndSize()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        previewTask?.cancel()
    }

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
        if WebLocation.destination(for: fileURL) != nil {
            let configuration = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular)
            imageView.image = NSImage(
                systemSymbolName: "globe",
                accessibilityDescription: "Web link"
            )?.withSymbolConfiguration(configuration)
            imageView.image?.isTemplate = true
            imageView.contentTintColor = NSColor(
                srgbRed: 1,
                green: 56 / 255,
                blue: 60 / 255,
                alpha: 1
            )
            applyImageSize(NSSize(width: 96, height: 96))
            return
        }

        // Never decode the original file on the main thread. Large images and
        // batches of files otherwise make the whole panel unresponsive.
        let placeholder = NSWorkspace.shared.icon(forFile: fileURL.path)
        imageView.image = placeholder
        applyImageSize(NSSize(width: maxPreviewSide, height: maxPreviewSide))
    }

    func setPreviewVisible(_ isVisible: Bool) {
        guard WebLocation.destination(for: fileURL) == nil else { return }
        if isVisible {
            loadQuickLookPreviewIfNeeded()
        } else if !hasLoadedPreview {
            previewTask?.cancel()
        }
    }

    private func loadQuickLookPreviewIfNeeded() {
        guard !hasLoadedPreview, previewTask == nil else { return }
        let request = QLThumbnailGenerator.Request(
            fileAt: fileURL,
            size: CGSize(width: maxPreviewSide * 2, height: maxPreviewSide * 2),
            scale: 2,
            representationTypes: .thumbnail
        )
        previewTask = Task { [weak self] in
            guard let self else { return }
            do {
                let representation = try await QLThumbnailGenerator.shared
                    .generateBestRepresentation(for: request)
                try Task.checkCancellation()
                let image = representation.nsImage
                imageView.image = image
                applyImageSize(fittedSize(for: image.size, maxSide: maxPreviewSide))
                hasLoadedPreview = true
                previewTask = nil
            } catch is CancellationError {
                previewTask = nil
                if !isHidden {
                    loadQuickLookPreviewIfNeeded()
                }
                return
            } catch {
                // The file icon is already a useful fallback.
                previewTask = nil
            }
        }
    }

    private func applyImageSize(_ fitted: NSSize) {
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

        guard superview != nil, !isHidden else { return }
        Task { @MainActor [weak self] in
            await Task.yield()
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
