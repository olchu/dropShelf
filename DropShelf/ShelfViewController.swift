import Cocoa
import SwiftUI
import QuickLookThumbnailing

@available(macOS 26.0, *)
private struct GlassPanel: View {
    var cornerRadius: CGFloat
    var body: some View {
        ZStack {
            Color.clear
                .glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.black.opacity(0.50))
        }
    }
}

@available(macOS 26.0, *)
private struct ThumbnailPanelShape: Shape {
    let cornerRadius: CGFloat
    let pointerHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(
            roundedRect: CGRect(
                x: rect.minX,
                y: rect.minY + pointerHeight,
                width: rect.width,
                height: rect.height - pointerHeight
            ),
            cornerRadius: cornerRadius
        )
        let pointerHalfWidth: CGFloat = 10
        path.move(to: CGPoint(x: rect.midX - pointerHalfWidth, y: rect.minY + pointerHeight))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + pointerHalfWidth, y: rect.minY + pointerHeight))
        path.closeSubpath()
        return path
    }
}

@available(macOS 26.0, *)
private struct ThumbnailPanelBackground: View {
    let cornerRadius: CGFloat
    let pointerHeight: CGFloat

    var body: some View {
        let shape = ThumbnailPanelShape(
            cornerRadius: cornerRadius,
            pointerHeight: pointerHeight
        )
        ZStack {
            Color.clear.glassEffect(in: shape)
            shape.fill(.black.opacity(0.50))
        }
    }
}

// Кнопка с привязанным URL для строк списка управления
private class URLButton: NSButton {
    let fileURL: URL
    init(url: URL) {
        self.fileURL = url
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }
}

private final class ManageFileDragSurface: NSButton, NSDraggingSource {
    let fileURL: URL
    var onDragCompleted: ((URL) -> Void)?

    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(frame: .zero)
        isBordered = false
        title = ""
        image = nil
    }

    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        let draggingItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        let image = dragImage()
        let point = convert(event.locationInWindow, from: nil)
        draggingItem.setDraggingFrame(
            NSRect(
                x: point.x - image.size.width / 2,
                y: point.y - image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ),
            contents: image
        )
        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        [.copy, .move]
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        if operation.isEmpty == false {
            onDragCompleted?(fileURL)
        }
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

    private func dragImage() -> NSImage {
        if WebLocation.destination(for: fileURL) != nil,
           let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Web link") {
            return image.withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 32, weight: .regular)
            ) ?? image
        }
        let image = NSWorkspace.shared.icon(forFile: fileURL.path)
        image.size = NSSize(width: 40, height: 40)
        return image
    }
}

private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

private final class ThumbnailScrollFooterView: NSView {
    private let glowLayer = CAGradientLayer()
    private let glowMaskLayer = CAGradientLayer()
    private let lineLayer = CAGradientLayer()

    init(accentColor: NSColor) {
        super.init(frame: .zero)
        wantsLayer = true

        glowLayer.colors = [
            accentColor.withAlphaComponent(0).cgColor,
            accentColor.withAlphaComponent(0.10).cgColor
        ]
        glowLayer.locations = [0, 1]
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0)
        glowLayer.endPoint = CGPoint(x: 0.5, y: 1)

        glowMaskLayer.colors = [
            NSColor.clear.cgColor,
            NSColor.white.cgColor,
            NSColor.clear.cgColor
        ]
        glowMaskLayer.locations = [0, 0.5, 1]
        glowMaskLayer.startPoint = CGPoint(x: 0, y: 0.5)
        glowMaskLayer.endPoint = CGPoint(x: 1, y: 0.5)
        glowLayer.mask = glowMaskLayer

        lineLayer.colors = [
            accentColor.withAlphaComponent(0).cgColor,
            accentColor.withAlphaComponent(0.85).cgColor,
            accentColor.withAlphaComponent(0).cgColor
        ]
        lineLayer.locations = [0, 0.5, 1]
        lineLayer.startPoint = CGPoint(x: 0, y: 0.5)
        lineLayer.endPoint = CGPoint(x: 1, y: 0.5)

        layer?.addSublayer(glowLayer)
        layer?.addSublayer(lineLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        glowLayer.frame = bounds
        glowMaskLayer.frame = glowLayer.bounds
        lineLayer.frame = NSRect(x: 8, y: bounds.height - 1, width: max(0, bounds.width - 16), height: 1)
    }
}

class ShelfViewController: NSViewController {
    private let accentColor = NSColor(srgbRed: 1, green: 56 / 255, blue: 60 / 255, alpha: 1)
    private var overlapView: OverlapStackView!
    private var titleLabel: NSTextField!
    private var importStatusLabel: NSTextField!
    private var fileItems: [URL] = []
    private var queuedFileURLs: [URL] = []
    private var queuedFileIndex = 0
    private var importTask: Task<Void, Never>?
    private var importGeneration = 0

    private var closeButton: CloseButton!
    private var bottomBar: NSView!
    private var manageButton: NSButton!
    private var clearButton: NSButton!
    private var manageScrollView: NSScrollView!
    private var manageStack: NSStackView!
    private var countButton: NSButton!
    private var thumbnailPanel: NSPanel!
    private var thumbnailScrollView: NSScrollView!
    private var thumbnailStack: NSStackView!
    private var thumbnailScrollFooter: NSView!
    private var thumbnailScrollFooterHeight: NSLayoutConstraint!
    private var thumbnailScrollFooterLabel: NSTextField!
    private var isManaging = false
    private var isThumbnailDrawerOpen = false

    private let cornerRadius: CGFloat = 20.0
    private let bottomBarHeight: CGFloat = 40.0
    private let closeButtonInset: CGFloat = 38.0
    private let thumbnailCellSize = NSSize(width: 68, height: 74)
    private let thumbnailPanelPadding: CGFloat = 8
    private let thumbnailTopPadding: CGFloat = 13
    private let thumbnailGridSpacing: CGFloat = 8
    private let thumbnailPointerHeight: CGFloat = 8

    func closeThumbnailPanel() {
        guard isThumbnailDrawerOpen else { return }
        setThumbnailDrawerOpen(false, animated: false)
    }

    func prepareForWindowPresentation() {
        guard !fileItems.isEmpty, !isManaging else { return }
        overlapView.alphaValue = 0
        overlapView.isHidden = true
    }

    func completeWindowPresentation() {
        guard !fileItems.isEmpty, !isManaging else { return }
        overlapView.isHidden = false

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            overlapView.alphaValue = 1
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            overlapView.animator().alphaValue = 1
        }
    }

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.registerForDraggedTypes([.fileURL])
    }

    // MARK: - Setup

    private func setupUI() {
        let dropTargetView = DropTargetView(frame: view.bounds)
        dropTargetView.autoresizingMask = [.width, .height]
        dropTargetView.onFilesDropped = { [weak self] urls in
            self?.addFiles(urls)
        }
        view.addSubview(dropTargetView)

        // Фон
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
            darkOverlay.backgroundColor = NSColor.black.withAlphaComponent(0.50).cgColor
            darkOverlay.frame = view.bounds
            darkOverlay.cornerRadius = cornerRadius
            darkOverlay.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            visualEffect.layer?.addSublayer(darkOverlay)
            dropTargetView.addSubview(visualEffect)
        }

        // Заголовок-подсказка
        titleLabel = NSTextField(labelWithString: "Drop files here")
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .center
        titleLabel.backgroundColor = .clear
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        dropTargetView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        importStatusLabel = NSTextField(labelWithString: "")
        importStatusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        importStatusLabel.textColor = .labelColor
        importStatusLabel.alignment = .center
        importStatusLabel.wantsLayer = true
        importStatusLabel.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        importStatusLabel.layer?.cornerRadius = 8
        importStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        importStatusLabel.isHidden = true
        dropTargetView.addSubview(importStatusLabel)
        NSLayoutConstraint.activate([
            importStatusLabel.centerXAnchor.constraint(equalTo: dropTargetView.centerXAnchor),
            importStatusLabel.bottomAnchor.constraint(
                equalTo: dropTargetView.bottomAnchor,
                constant: -(bottomBarHeight + 8)
            ),
            importStatusLabel.heightAnchor.constraint(equalToConstant: 24),
            importStatusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])

        // Стопка превью — не перекрывает нижний тулбар
        overlapView = OverlapStackView(frame: .zero)
        overlapView.translatesAutoresizingMaskIntoConstraints = false
        overlapView.wantsLayer = true
        overlapView.layer?.masksToBounds = false
        overlapView.maxVisible = 4
        // Компактный веер: нижние карточки немного расходятся в стороны,
        // а верхняя остаётся ровной и хорошо читается.
        overlapView.baseAngles = [-6, 6, -3, 3]
        dropTargetView.addSubview(overlapView)
        overlapView.isHidden = true
        NSLayoutConstraint.activate([
            overlapView.topAnchor.constraint(equalTo: dropTargetView.topAnchor, constant: closeButtonInset),
            overlapView.leadingAnchor.constraint(equalTo: dropTargetView.leadingAnchor),
            overlapView.trailingAnchor.constraint(equalTo: dropTargetView.trailingAnchor),
            overlapView.bottomAnchor.constraint(equalTo: dropTargetView.bottomAnchor, constant: -bottomBarHeight)
        ])

        overlapView.onFilesDropped = { [weak self] urls in
            self?.addFiles(urls)
        }
        overlapView.onRemoveAll = { [weak self] in self?.clearAll() }
        overlapView.onRemoveFile = { [weak self] url in self?.removeFile(url: url) }

        // Кнопка закрытия
        let diameter = cornerRadius * 1.5
        closeButton = CloseButton(diameter: diameter)
        closeButton.accentColor = accentColor
        closeButton.normalAlpha = 0.10
        closeButton.hoverAlpha  = 0.25
        dropTargetView.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8)
        ])

        setupBottomBar(in: dropTargetView)
        setupThumbnailPanel()
        setupManageView(in: dropTargetView)
        dropTargetView.addSubview(importStatusLabel, positioned: .above, relativeTo: nil)
    }

    private func setupBottomBar(in parent: NSView) {
        bottomBar = NSView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: bottomBarHeight)
        ])

        let sep = NSView()
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.wantsLayer = true
        sep.layer?.backgroundColor = accentColor.withAlphaComponent(0.22).cgColor
        bottomBar.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 12),
            sep.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -12),
            sep.heightAnchor.constraint(equalToConstant: 0.5)
        ])

        clearButton = makeBarButton(symbol: "trash", size: 14, action: #selector(clearAllTapped))
        bottomBar.addSubview(clearButton)
        NSLayoutConstraint.activate([
            clearButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 14),
            clearButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor)
        ])

        manageButton = makeBarButton(symbol: "list.bullet", size: 14, action: #selector(toggleManage))
        bottomBar.addSubview(manageButton)
        NSLayoutConstraint.activate([
            manageButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -14),
            manageButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor)
        ])

        countButton = NSButton(title: "", target: self, action: #selector(toggleThumbnailDrawer))
        countButton.isBordered = false
        countButton.font = .systemFont(ofSize: 12, weight: .medium)
        countButton.contentTintColor = .secondaryLabelColor
        countButton.imagePosition = .imageTrailing
        countButton.imageHugsTitle = true
        countButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(countButton)
        NSLayoutConstraint.activate([
            countButton.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            countButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor)
        ])

        bottomBar.isHidden = true
    }

    private func updateCountLabel() {
        let n = fileItems.count
        countButton.title = n == 1 ? "1 file" : "\(n) files"
        updateCountChevron()
    }

    private func updateCountChevron() {
        let symbol = isThumbnailDrawerOpen ? "chevron.down" : "chevron.up"
        let configuration = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
        countButton.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: isThumbnailDrawerOpen ? "Hide file thumbnails" : "Show file thumbnails"
        )?.withSymbolConfiguration(configuration)
    }

    private func setupThumbnailPanel() {
        let panelSize = NSSize(width: 280, height: 200)
        thumbnailPanel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        thumbnailPanel.level = .statusBar
        thumbnailPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        thumbnailPanel.isOpaque = false
        thumbnailPanel.backgroundColor = .clear
        thumbnailPanel.appearance = NSAppearance(named: .darkAqua)
        thumbnailPanel.hasShadow = false
        thumbnailPanel.isMovableByWindowBackground = false

        let background = NSView(frame: NSRect(origin: .zero, size: panelSize))
        background.wantsLayer = true
        background.layer?.cornerRadius = 18
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true
        background.autoresizingMask = [.width, .height]
        thumbnailPanel.contentView = background

        if #available(macOS 26.0, *) {
            let glassHost = NSHostingView(
                rootView: ThumbnailPanelBackground(
                    cornerRadius: 18,
                    pointerHeight: thumbnailPointerHeight
                )
            )
            glassHost.frame = background.bounds
            glassHost.autoresizingMask = [.width, .height]
            background.addSubview(glassHost)
        } else {
            let visualEffect = NSVisualEffectView(frame: background.bounds)
            visualEffect.material = .popover
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            visualEffect.autoresizingMask = [.width, .height]
            background.addSubview(visualEffect)

            let darkOverlay = CALayer()
            darkOverlay.backgroundColor = NSColor.black.withAlphaComponent(0.50).cgColor
            darkOverlay.cornerRadius = 18
            darkOverlay.cornerCurve = .continuous
            darkOverlay.frame = NSRect(origin: .zero, size: panelSize)
            darkOverlay.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            background.layer?.addSublayer(darkOverlay)
        }

        thumbnailScrollView = NSScrollView()
        thumbnailScrollView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailScrollView.drawsBackground = false
        thumbnailScrollView.borderType = .noBorder
        thumbnailScrollView.hasHorizontalScroller = false
        thumbnailScrollView.hasVerticalScroller = false
        thumbnailScrollView.scrollerStyle = .overlay
        thumbnailScrollView.autohidesScrollers = true
        thumbnailScrollView.verticalScrollElasticity = .automatic
        background.addSubview(thumbnailScrollView)

        thumbnailScrollFooter = ThumbnailScrollFooterView(accentColor: accentColor)
        thumbnailScrollFooter.translatesAutoresizingMaskIntoConstraints = false
        thumbnailScrollFooter.isHidden = true
        background.addSubview(thumbnailScrollFooter)

        thumbnailScrollFooterLabel = NSTextField(labelWithString: "Scroll to see more  ↓")
        thumbnailScrollFooterLabel.font = .systemFont(ofSize: 11, weight: .medium)
        thumbnailScrollFooterLabel.textColor = accentColor
        thumbnailScrollFooterLabel.alignment = .center
        thumbnailScrollFooterLabel.translatesAutoresizingMaskIntoConstraints = false
        thumbnailScrollFooter.addSubview(thumbnailScrollFooterLabel)

        thumbnailScrollFooterHeight = thumbnailScrollFooter.heightAnchor.constraint(equalToConstant: 0)

        thumbnailStack = FlippedStackView()
        thumbnailStack.orientation = .vertical
        thumbnailStack.alignment = .leading
        thumbnailStack.spacing = 8
        thumbnailStack.edgeInsets = NSEdgeInsets(
            top: 0,
            left: thumbnailPanelPadding,
            bottom: thumbnailPanelPadding,
            right: thumbnailPanelPadding
        )
        thumbnailStack.translatesAutoresizingMaskIntoConstraints = false

        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(thumbnailStack)
        thumbnailScrollView.documentView = documentView

        NSLayoutConstraint.activate([
            thumbnailScrollView.topAnchor.constraint(
                equalTo: background.topAnchor,
                constant: thumbnailPointerHeight + thumbnailTopPadding
            ),
            thumbnailScrollView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            thumbnailScrollView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            thumbnailScrollView.bottomAnchor.constraint(equalTo: thumbnailScrollFooter.topAnchor),

            thumbnailScrollFooter.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            thumbnailScrollFooter.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            thumbnailScrollFooter.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            thumbnailScrollFooterHeight,

            thumbnailScrollFooterLabel.centerXAnchor.constraint(equalTo: thumbnailScrollFooter.centerXAnchor),
            thumbnailScrollFooterLabel.centerYAnchor.constraint(equalTo: thumbnailScrollFooter.centerYAnchor, constant: -1),

            documentView.topAnchor.constraint(equalTo: thumbnailScrollView.contentView.topAnchor),
            documentView.leadingAnchor.constraint(equalTo: thumbnailScrollView.contentView.leadingAnchor),
            documentView.widthAnchor.constraint(equalTo: thumbnailScrollView.contentView.widthAnchor),

            thumbnailStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            thumbnailStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            thumbnailStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            thumbnailStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor)
        ])

        thumbnailScrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thumbnailScrollPositionDidChange),
            name: NSView.boundsDidChangeNotification,
            object: thumbnailScrollView.contentView
        )

        thumbnailPanel.orderOut(nil)
    }

    @objc private func thumbnailScrollPositionDidChange(_ notification: Notification) {
        updateThumbnailScrollFooter()
    }

    private func updateThumbnailScrollFooter() {
        guard !thumbnailScrollFooter.isHidden,
              let documentView = thumbnailScrollView.documentView else { return }
        let visibleBottom = thumbnailScrollView.contentView.bounds.maxY
        let isAtBottom = visibleBottom >= documentView.bounds.height - 1
        thumbnailScrollFooterLabel.stringValue = isAtBottom
            ? "Scroll up to see more  ↑"
            : "Scroll to see more  ↓"
    }

    @objc private func toggleThumbnailDrawer() {
        setThumbnailDrawerOpen(!isThumbnailDrawerOpen, animated: true)
    }

    private func setThumbnailDrawerOpen(_ isOpen: Bool, animated: Bool) {
        guard isOpen != isThumbnailDrawerOpen else { return }
        isThumbnailDrawerOpen = isOpen
        updateCountChevron()

        if isOpen {
            refreshThumbnailDrawer()
            guard let parentWindow = view.window else { return }
            let panelSize = thumbnailPanelSize(for: fileItems.count)
            let finalFrame = NSRect(
                x: parentWindow.frame.midX - panelSize.width / 2,
                y: parentWindow.frame.minY - panelSize.height - 6,
                width: panelSize.width,
                height: panelSize.height
            )
            let startingFrame = finalFrame.offsetBy(dx: 0, dy: 8)
            thumbnailPanel.setFrame(animated ? startingFrame : finalFrame, display: true)
            parentWindow.addChildWindow(thumbnailPanel, ordered: .above)
            thumbnailPanel.alphaValue = animated ? 0 : 1
            thumbnailPanel.orderFront(nil)

            guard animated else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                thumbnailPanel.animator().alphaValue = 1
                thumbnailPanel.animator().setFrame(finalFrame, display: true)
            }
            return
        }

        guard animated else {
            view.window?.removeChildWindow(thumbnailPanel)
            thumbnailPanel.orderOut(nil)
            thumbnailPanel.alphaValue = 1
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            thumbnailPanel.animator().alphaValue = 0
            thumbnailPanel.animator().setFrame(
                thumbnailPanel.frame.offsetBy(dx: 0, dy: 6),
                display: true
            )
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.view.window?.removeChildWindow(self.thumbnailPanel)
            self.thumbnailPanel.orderOut(nil)
            self.thumbnailPanel.alphaValue = 1
        }
    }

    private func refreshThumbnailDrawer() {
        thumbnailStack.arrangedSubviews.forEach {
            thumbnailStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let columnCount = thumbnailColumnCount(for: fileItems.count)
        let hasOverflow = fileItems.count > columnCount * 2
        thumbnailScrollView.hasVerticalScroller = hasOverflow
        thumbnailScrollFooter.isHidden = !hasOverflow
        thumbnailScrollFooterHeight.constant = hasOverflow ? 30 : 0
        thumbnailScrollFooterLabel.stringValue = "Scroll to see more  ↓"

        for rowStart in stride(from: 0, to: fileItems.count, by: columnCount) {
            let rowItems = Array(fileItems[rowStart..<min(rowStart + columnCount, fileItems.count)])
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .top
            row.distribution = .fill
            row.spacing = thumbnailGridSpacing
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(equalToConstant: thumbnailCellSize.height).isActive = true

            for url in rowItems {
                row.addArrangedSubview(makeThumbnailItem(for: url))
            }

            thumbnailStack.addArrangedSubview(row)
            row.leadingAnchor.constraint(
                equalTo: thumbnailStack.leadingAnchor,
                constant: thumbnailPanelPadding
            ).isActive = true
        }

        DispatchQueue.main.async { [weak self] in
            self?.updateThumbnailScrollFooter()
        }
    }

    private func thumbnailPanelSize(for fileCount: Int) -> NSSize {
        let columnCount = thumbnailColumnCount(for: fileCount)
        let totalRowCount = max(1, Int(ceil(Double(fileCount) / Double(columnCount))))
        let visibleRowCount = min(totalRowCount, 2)
        let width = CGFloat(columnCount) * thumbnailCellSize.width
            + CGFloat(columnCount - 1) * thumbnailGridSpacing
            + thumbnailPanelPadding * 2
        let height = CGFloat(visibleRowCount) * thumbnailCellSize.height
            + CGFloat(visibleRowCount - 1) * thumbnailGridSpacing
            + thumbnailTopPadding
            + thumbnailPanelPadding
            + (fileCount > columnCount * 2 ? 30 : 0)
            + thumbnailPointerHeight
        return NSSize(width: width, height: height)
    }

    private func thumbnailColumnCount(for fileCount: Int) -> Int {
        fileCount > 6 ? 4 : max(1, min(fileCount, 3))
    }

    private func resizeAndCenterThumbnailPanel(animated: Bool) {
        guard isThumbnailDrawerOpen, let parentWindow = view.window else { return }
        let panelSize = thumbnailPanelSize(for: fileItems.count)
        let frame = NSRect(
            x: parentWindow.frame.midX - panelSize.width / 2,
            y: parentWindow.frame.minY - panelSize.height - 6,
            width: panelSize.width,
            height: panelSize.height
        )

        guard animated else {
            thumbnailPanel.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            thumbnailPanel.animator().setFrame(frame, display: true)
        }
    }

    private func makeThumbnailItem(for url: URL) -> NSView {
        let item = NSView()
        item.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            item.widthAnchor.constraint(equalToConstant: thumbnailCellSize.width),
            item.heightAnchor.constraint(equalToConstant: thumbnailCellSize.height)
        ])

        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 7
        imageView.layer?.cornerCurve = .continuous
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let webDestination = WebLocation.destination(for: url)
        if webDestination != nil {
            let configuration = NSImage.SymbolConfiguration(pointSize: 30, weight: .regular)
            imageView.image = NSImage(
                systemSymbolName: "globe",
                accessibilityDescription: "Web link"
            )?.withSymbolConfiguration(configuration)
            imageView.image?.isTemplate = true
            imageView.contentTintColor = accentColor
        } else {
            imageView.image = NSWorkspace.shared.icon(forFile: url.path)
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: 112, height: 112),
                scale: 2,
                representationTypes: .thumbnail
            )
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
                guard let image = thumbnail?.nsImage else { return }
                DispatchQueue.main.async { [weak imageView] in
                    imageView?.image = image
                }
            }
        }

        let dragSurface = ManageFileDragSurface(fileURL: url)
        dragSurface.translatesAutoresizingMaskIntoConstraints = false
        dragSurface.toolTip = WebLocation.displayName(for: url)
        dragSurface.onDragCompleted = { [weak self] draggedURL in
            self?.removeFromManage(url: draggedURL)
        }

        let nameLabel = NSTextField(labelWithString: WebLocation.displayName(for: url))
        nameLabel.font = .systemFont(ofSize: 9, weight: .regular)
        nameLabel.textColor = .secondaryLabelColor
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.maximumNumberOfLines = 1
        nameLabel.cell?.wraps = false
        nameLabel.cell?.isScrollable = false
        nameLabel.toolTip = WebLocation.displayName(for: url)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        item.addSubview(imageView)
        item.addSubview(nameLabel)
        item.addSubview(dragSurface)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: item.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: item.topAnchor, constant: 2),
            imageView.widthAnchor.constraint(equalToConstant: 54),
            imageView.heightAnchor.constraint(equalToConstant: 54),

            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: item.leadingAnchor, constant: 2),
            nameLabel.trailingAnchor.constraint(equalTo: item.trailingAnchor, constant: -2),
            nameLabel.bottomAnchor.constraint(equalTo: item.bottomAnchor, constant: -2),

            dragSurface.leadingAnchor.constraint(equalTo: item.leadingAnchor),
            dragSurface.trailingAnchor.constraint(equalTo: item.trailingAnchor),
            dragSurface.topAnchor.constraint(equalTo: item.topAnchor),
            dragSurface.bottomAnchor.constraint(equalTo: item.bottomAnchor)
        ])
        return item
    }

    private func setupManageView(in parent: NSView) {
        manageScrollView = NSScrollView()
        manageScrollView.translatesAutoresizingMaskIntoConstraints = false
        manageScrollView.hasVerticalScroller = true
        manageScrollView.drawsBackground = false
        manageScrollView.borderType = .noBorder
        parent.addSubview(manageScrollView)
        NSLayoutConstraint.activate([
            manageScrollView.topAnchor.constraint(equalTo: parent.topAnchor, constant: closeButtonInset),
            manageScrollView.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            manageScrollView.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            manageScrollView.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -bottomBarHeight)
        ])

        manageStack = NSStackView()
        manageStack.orientation = .vertical
        manageStack.alignment = .leading
        manageStack.distribution = .fill
        manageStack.spacing = 0
        manageStack.translatesAutoresizingMaskIntoConstraints = false
        manageScrollView.documentView = manageStack
        NSLayoutConstraint.activate([
            manageStack.topAnchor.constraint(equalTo: manageScrollView.contentView.topAnchor),
            manageStack.leadingAnchor.constraint(equalTo: manageScrollView.contentView.leadingAnchor),
            manageStack.widthAnchor.constraint(equalTo: manageScrollView.contentView.widthAnchor)
        ])

        manageScrollView.isHidden = true
    }

    private func makeBarButton(symbol: String, size: CGFloat, action: Selector) -> NSButton {
        let btn = NSButton()
        btn.isBordered = false
        let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
        btn.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
        btn.image?.isTemplate = true
        btn.contentTintColor = accentColor
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.target = self
        btn.action = action
        return btn
    }

    // MARK: - Manage mode

    @objc private func toggleManage() {
        isManaging ? exitManageMode() : enterManageMode()
    }

    private func enterManageMode() {
        if isThumbnailDrawerOpen {
            setThumbnailDrawerOpen(false, animated: true)
        }
        isManaging = true
        refreshManageView()
        manageScrollView.isHidden = false
        overlapView.isHidden = true
        titleLabel.isHidden = true
        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        manageButton.image = NSImage(
            systemSymbolName: "square.stack",
            accessibilityDescription: "Show file stack"
        )?.withSymbolConfiguration(cfg)
        manageButton.image?.isTemplate = true
    }

    private func exitManageMode() {
        isManaging = false
        manageScrollView.isHidden = true
        overlapView.isHidden = fileItems.isEmpty
        titleLabel.isHidden = !fileItems.isEmpty
        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        manageButton.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
        manageButton.image?.isTemplate = true
    }

    private func refreshManageView() {
        manageStack.arrangedSubviews.forEach {
            manageStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for url in fileItems {
            let row = makeManageRow(for: url)
            manageStack.addArrangedSubview(row)
            row.trailingAnchor.constraint(equalTo: manageStack.trailingAnchor).isActive = true
        }
    }

    private func makeManageRow(for url: URL) -> NSView {
        let thumbSize: CGFloat = 32
        let rowHeight: CGFloat = 44

        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true

        let dragSurface = ManageFileDragSurface(fileURL: url)
        dragSurface.translatesAutoresizingMaskIntoConstraints = false
        dragSurface.onDragCompleted = { [weak self] url in
            self?.removeFromManage(url: url)
        }

        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 4
        icon.layer?.masksToBounds = true
        let webDestination = WebLocation.destination(for: url)
        if webDestination != nil {
            let configuration = NSImage.SymbolConfiguration(pointSize: 24, weight: .regular)
            icon.image = NSImage(
                systemSymbolName: "globe",
                accessibilityDescription: "Web link"
            )?.withSymbolConfiguration(configuration)
            icon.image?.isTemplate = true
            icon.contentTintColor = accentColor
        } else {
            icon.image = NSWorkspace.shared.icon(forFile: url.path) // placeholder
        }
        icon.translatesAutoresizingMaskIntoConstraints = false

        // Загружаем превью асинхронно через QuickLook
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: thumbSize * 2, height: thumbSize * 2),
            scale: 2.0,
            representationTypes: .thumbnail
        )
        if webDestination == nil {
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumb, _ in
                if let img = thumb?.nsImage {
                    DispatchQueue.main.async { icon.image = img }
                }
            }
        }

        let label = NSTextField(labelWithString: WebLocation.displayName(for: url))
        label.lineBreakMode = .byTruncatingMiddle
        label.maximumNumberOfLines = 1
        label.cell?.wraps = false
        label.cell?.isScrollable = false
        label.font = .systemFont(ofSize: 12)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let deleteBtn = URLButton(url: url)
        deleteBtn.isBordered = false
        let cfg = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        deleteBtn.image = NSImage(
            systemSymbolName: "minus.circle",
            accessibilityDescription: "Remove"
        )?.withSymbolConfiguration(cfg)
        deleteBtn.image?.isTemplate = true
        deleteBtn.contentTintColor = accentColor
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false
        deleteBtn.target = self
        deleteBtn.action = #selector(deleteFromManage(_:))

        row.addSubview(icon)
        row.addSubview(label)
        // Прозрачная поверхность находится поверх иконки и текста,
        // поэтому тянуть можно за любую часть строки.
        row.addSubview(dragSurface)
        row.addSubview(deleteBtn)

        NSLayoutConstraint.activate([
            dragSurface.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            dragSurface.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            dragSurface.topAnchor.constraint(equalTo: row.topAnchor),
            dragSurface.bottomAnchor.constraint(equalTo: row.bottomAnchor),

            icon.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: thumbSize),
            icon.heightAnchor.constraint(equalToConstant: thumbSize),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: deleteBtn.leadingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            deleteBtn.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            deleteBtn.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            deleteBtn.widthAnchor.constraint(equalToConstant: 22),
            deleteBtn.heightAnchor.constraint(equalToConstant: 22)
        ])

        return row
    }

    @objc private func deleteFromManage(_ sender: URLButton) {
        removeFromManage(url: sender.fileURL)
    }

    private func removeFromManage(url: URL) {
        overlapView.subviews.compactMap { $0 as? FileItemView }
            .first { $0.fileURL == url }?.removeFromSuperview()
        overlapView.needsLayout = true
        removeFile(url: url)
        if fileItems.isEmpty {
            exitManageMode()
        } else {
            refreshManageView()
        }
    }

    @objc private func clearAllTapped() {
        clearAll()
    }

    // MARK: - Files

    private func addFiles(_ urls: [URL]) {
        guard !isManaging else { return }
        let newURLs = urls.filter { url in
            !fileItems.contains(url) && !queuedFileURLs[queuedFileIndex...].contains(url)
        }
        guard !newURLs.isEmpty else { return }

        queuedFileURLs.append(contentsOf: newURLs)
        updateImportStatus()
        guard importTask == nil else { return }

        importGeneration += 1
        let generation = importGeneration
        DiagnosticsLogger.shared.info("Queued \(queuedFileURLs.count) local files for import")
        importTask = Task { [weak self] in
            guard let self else { return }
            while generation == importGeneration,
                  queuedFileIndex < queuedFileURLs.count {
                guard !Task.isCancelled else { return }
                let url = queuedFileURLs[queuedFileIndex]
                queuedFileIndex += 1
                addFile(url: url)
                updateImportStatus()

                // Let AppKit draw progress and handle mouse events between
                // small chunks of a large drop.
                if queuedFileIndex.isMultiple(of: 6) {
                    try? await Task.sleep(for: .milliseconds(8))
                } else {
                    await Task.yield()
                }
            }
            finishImportQueue(generation: generation)
        }
    }

    private func addFile(url: URL) {
        guard !isManaging, !fileItems.contains(url) else { return }
        fileItems.append(url)
        titleLabel.isHidden = true
        overlapView.isHidden = isManaging
        bottomBar.isHidden = false

        let fileView = FileItemView(fileURL: url)
        overlapView.addSubview(fileView)
        overlapView.needsLayout = true

        updateCountLabel()
        if isThumbnailDrawerOpen {
            refreshThumbnailDrawer()
            resizeAndCenterThumbnailPanel(animated: true)
        }
        if isManaging { refreshManageView() }
    }

    private func updateImportStatus() {
        let total = queuedFileURLs.count
        let completed = min(queuedFileIndex, total)
        importStatusLabel.stringValue = completed == 0
            ? "Preparing \(total) files…"
            : "Adding \(completed) of \(total)…"
        importStatusLabel.isHidden = false
    }

    private func finishImportQueue(generation: Int) {
        guard generation == importGeneration else { return }
        queuedFileURLs.removeAll(keepingCapacity: false)
        queuedFileIndex = 0
        importTask = nil
        importStatusLabel.isHidden = true
        overlapView.layoutSubtreeIfNeeded()
        DiagnosticsLogger.shared.info("Local file import finished")
    }

    private func removeFile(url: URL) {
        fileItems.removeAll { $0 == url }
        if fileItems.isEmpty {
            if isThumbnailDrawerOpen {
                setThumbnailDrawerOpen(false, animated: false)
            }
            bottomBar.isHidden = true
            overlapView.isHidden = true
            titleLabel.isHidden = false
        } else {
            updateCountLabel()
            if isThumbnailDrawerOpen {
                refreshThumbnailDrawer()
                resizeAndCenterThumbnailPanel(animated: true)
            }
        }
    }

    private func clearAll() {
        importGeneration += 1
        importTask?.cancel()
        importTask = nil
        queuedFileURLs.removeAll(keepingCapacity: false)
        queuedFileIndex = 0
        importStatusLabel.isHidden = true
        fileItems.removeAll()
        if isThumbnailDrawerOpen {
            setThumbnailDrawerOpen(false, animated: false)
        }
        overlapView.subviews.forEach { $0.removeFromSuperview() }
        overlapView.isHidden = true
        titleLabel.isHidden = false
        bottomBar.isHidden = true
        if isManaging { exitManageMode() }
    }
}
