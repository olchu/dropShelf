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

class ShelfViewController: NSViewController {
    private let accentColor = NSColor(srgbRed: 1, green: 56 / 255, blue: 60 / 255, alpha: 1)
    private var overlapView: OverlapStackView!
    private var titleLabel: NSTextField!
    private var fileItems: [URL] = []

    private var closeButton: CloseButton!
    private var bottomBar: NSView!
    private var manageButton: NSButton!
    private var clearButton: NSButton!
    private var manageScrollView: NSScrollView!
    private var manageStack: NSStackView!
    private var countLabel: NSTextField!
    private var isManaging = false

    private let cornerRadius: CGFloat = 20.0
    private let bottomBarHeight: CGFloat = 40.0
    private let closeButtonInset: CGFloat = 38.0

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
        setupManageView(in: dropTargetView)
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

        countLabel = NSTextField(labelWithString: "")
        countLabel.font = .systemFont(ofSize: 12, weight: .medium)
        countLabel.textColor = .secondaryLabelColor
        countLabel.alignment = .center
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(countLabel)
        NSLayoutConstraint.activate([
            countLabel.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            countLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor)
        ])

        bottomBar.isHidden = true
    }

    private func updateCountLabel() {
        let n = fileItems.count
        countLabel.stringValue = n == 1 ? "1 file" : "\(n) files"
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
        for url in urls {
            addFile(url: url)
        }

        // Один drop может содержать сразу несколько URL. Завершаем ручной
        // layout всей стопки после добавления группы, чтобы углы применились
        // ко всем карточкам в одном проходе.
        overlapView.layoutSubtreeIfNeeded()
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
        if isManaging { refreshManageView() }
    }

    private func removeFile(url: URL) {
        fileItems.removeAll { $0 == url }
        if fileItems.isEmpty {
            bottomBar.isHidden = true
            overlapView.isHidden = true
            titleLabel.isHidden = false
        } else {
            updateCountLabel()
        }
    }

    private func clearAll() {
        fileItems.removeAll()
        overlapView.subviews.forEach { $0.removeFromSuperview() }
        overlapView.isHidden = true
        titleLabel.isHidden = false
        bottomBar.isHidden = true
        if isManaging { exitManageMode() }
    }
}
