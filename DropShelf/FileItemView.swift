import Cocoa

/// Превью файла без серого фона: только само изображение/иконка,
/// по центру, с белой рамкой 2pt, рамка обрамляет ровно превью.
/// Карточка = размеру превью (без дополнительных подложек).
final class FileItemView: NSView, NSDraggingSource {

    // MARK: - Public
    let fileURL: URL
    var onRemove: (() -> Void)?

    // MARK: - UI
    private let imageView = NSImageView()

    // Настраиваемая максимальная сторона превью
    private let maxPreviewSide: CGFloat = 120

    // Динамический интринсик — равен размеру превью
    private var cachedIntrinsic: NSSize = NSSize(width: 120, height: 120) {
        didSet { invalidateIntrinsicContentSize() }
    }
    override var intrinsicContentSize: NSSize { cachedIntrinsic }

    // MARK: - Init
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        // Никаких подложек/фонов у контейнера
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false

        setupUI()
        loadPreviewAndSize()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - UI
    private func setupUI() {
        // Превью по центру, с белой рамкой 2pt; рамка по размеру превью
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.wantsLayer = true
        imageView.layer?.masksToBounds = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.borderWidth = 2
        imageView.layer?.borderColor = NSColor.white.cgColor
        // Лёгкая тень именно у превью (а не у контейнера)
        imageView.layer?.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
        imageView.layer?.shadowOpacity = 1
        imageView.layer?.shadowRadius = 6
        imageView.layer?.shadowOffset = .zero

        addSubview(imageView)

        // Центрируем превью. Размеры зададим после вычисления фактического размера.
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    /// Загружает превью и настраивает точные размеры (без серых подложек).
    private func loadPreviewAndSize() {
        // 1) Попробуем открыть как изображение
        let previewImage: NSImage = NSImage(contentsOf: fileURL) ?? {
            // 2) Если не изображение — системная иконка файла
            let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
            return icon
        }()

        // Рассчитываем целевой размер, вписывая в квадрат maxPreviewSide×maxPreviewSide
        let fitted = fittedSize(for: previewImage.size, maxSide: maxPreviewSide)

        // Устанавливаем картинку и точные размеры imageView
        imageView.image = previewImage
        // Удалим старые size-констрейнты, если были
        imageView.constraints.filter {
            ($0.firstAttribute == .width || $0.firstAttribute == .height) && $0.firstItem as? NSView === imageView
        }.forEach { $0.isActive = false }

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: fitted.width),
            imageView.heightAnchor.constraint(equalToConstant: fitted.height)
        ])

        // Контейнер = размеру превью (рамка уже на imageView)
        cachedIntrinsic = fitted
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    private func fittedSize(for original: NSSize, maxSide: CGFloat) -> NSSize {
        guard original.width > 0, original.height > 0 else { return NSSize(width: maxSide, height: maxSide) }
        let scale = min(maxSide / original.width, maxSide / original.height, 1) // не увеличиваем сверх 1:1
        return NSSize(width: round(original.width * scale), height: round(original.height * scale))
    }

    // MARK: - Drag out
    override func mouseDown(with event: NSEvent) {
        guard window != nil else { return }

        let writer = fileURL as NSURL
        let draggingItem = NSDraggingItem(pasteboardWriter: writer)

        // Снимок — только превью (так красивее)
        let dragImage = snapshotOfView(imageView)
        let location = convert(event.locationInWindow, from: nil)
        let frame = NSRect(x: location.x - dragImage.size.width / 2,
                           y: location.y - dragImage.size.height / 2,
                           width: dragImage.size.width,
                           height: dragImage.size.height)
        draggingItem.setDraggingFrame(frame, contents: dragImage)

        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .default
    }

    private func snapshotOfView(_ view: NSView) -> NSImage {
        let size = view.bounds.size
        let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) ?? NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        view.cacheDisplay(in: view.bounds, to: rep)
        let img = NSImage(size: size)
        img.addRepresentation(rep)
        return img
    }

    // MARK: - NSDraggingSource
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { [.copy, .move] }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if !operation.isEmpty { onRemove?() }
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
}
