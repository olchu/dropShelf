import Cocoa

/// Контейнер-«стопка»: карточки по общему центру, нижние слегка повернуты,
/// верхняя (последняя добавленная) — без поворота.
/// Поддерживает ГРУППОВОЙ перетаскивание и приём drop по всей области.
final class OverlapStackView: NSView, NSDraggingSource {

    /// Сколько карточек максимум показывать (остальные скрываются визуально, но участвуют в drag)
    var maxVisible: Int = 4 { didSet { needsLayout = true } }

    /// Углы поворота (в градусах) для нижних карточек. Верхняя = 0°.
    var baseAngles: [CGFloat] = [-12, -6, 6, 12] { didSet { needsLayout = true } }

    /// Callback: успешный ГРУППОВОЙ drop → очистить стопку
    var onRemoveAll: (() -> Void)?

    /// Callback: пришли файлы через drop на область стопки (в т.ч. поверх иконок)
    var onFilesDropped: (([URL]) -> Void)?

    override var isFlipped: Bool { true }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        wantsLayer = true
        layer?.masksToBounds = false
        // Принимаем файлы по ВСЕЙ области стопки
        registerForDraggedTypes([.fileURL])
    }

    // ВАЖНО: все события (мышь/dnd) всегда идут в контейнер,
    // даже если курсор над дочерними превью — так drop работает по всей области.
    override func hitTest(_ point: NSPoint) -> NSView? { self }

    // MARK: - Layout

    override func addSubview(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.masksToBounds = false
        super.addSubview(view)
        for v in subviews { v.isHidden = false }
        needsLayout = true
    }

    func removeSubview(_ view: NSView) {
        view.removeFromSuperview()
        needsLayout = true
    }

    override func layout() {
        super.layout()

        let all = subviews
        let visible = Array(all.suffix(maxVisible))
        let count = visible.count
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        if all.count > visible.count {
            for v in all.dropLast(visible.count) { v.isHidden = true }
        }

        for (i, v) in visible.enumerated() {
            let size = v.intrinsicContentSize == .zero ? v.bounds.size : v.intrinsicContentSize
            let frame = CGRect(x: center.x - size.width/2,
                               y: center.y - size.height/2,
                               width: size.width,
                               height: size.height)
            v.frame = frame.integral

            let isTop = (i == count - 1)
            let angleDeg: CGFloat = isTop ? 0 : (baseAngles[i % baseAngles.count])
            let angleRad = angleDeg * (.pi / 180)

            v.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            v.layer?.position = CGPoint(x: frame.midX, y: frame.midY)
            v.layer?.transform = CATransform3DMakeRotation(angleRad, 0, 0, 1)

            v.layer?.shadowOpacity = isTop ? 0.4 : 0.25
            v.layer?.zPosition = CGFloat(i)
        }
    }

    // MARK: - Group Drag (ВСЕГДА от имени стопки)

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        beginGroupDrag(event: event)
    }

    private func beginGroupDrag(event: NSEvent) {
        let itemsViews = subviews.compactMap { $0 as? FileItemView }
        guard !itemsViews.isEmpty else { return }

        var draggingItems: [NSDraggingItem] = []
        draggingItems.reserveCapacity(itemsViews.count)

        let mouse = convert(event.locationInWindow, from: nil)
        for (i, v) in itemsViews.enumerated() {
            let writer = v.fileURL as NSURL
            let di = NSDraggingItem(pasteboardWriter: writer)

            let img = v.dragSnapshot ?? snapshot(of: v)

            let spread: CGFloat = 6
            let frame = NSRect(
                x: mouse.x - img.size.width/2 + CGFloat(i - itemsViews.count + 1) * spread,
                y: mouse.y - img.size.height/2 + CGFloat(i - itemsViews.count + 1) * (-spread),
                width: img.size.width,
                height: img.size.height
            )
            di.setDraggingFrame(frame, contents: img)
            draggingItems.append(di)
        }

        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .pile
    }

    private func snapshot(of view: NSView) -> NSImage {
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

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .move]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if !operation.isEmpty { onRemoveAll?() }
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
}

// MARK: - NSDraggingDestination (приём drop поверх стопки/иконок)
extension OverlapStackView {

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        guard let urls = pb.readObjects(forClasses: [NSURL.self],
                                        options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty else { return false }
        onFilesDropped?(urls)
        return true
    }
}
