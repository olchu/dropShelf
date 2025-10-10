import Cocoa

final class FileItemView: NSView, NSDraggingSource {

    // MARK: - Public
    let fileURL: URL
    var onRemove: (() -> Void)?

    // MARK: - UI
    private let imageView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let removeButton = NSButton()
    private let vstack = NSStackView()

    // Интринсик — чтобы карточка всегда имела видимый размер
    override var intrinsicContentSize: NSSize { NSSize(width: 120, height: 115) }

    // MARK: - Init
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.12).cgColor
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - UI
    private func setupUI() {
        // Тень/стиль
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = 6
        layer?.shadowOffset = .zero

        // Иконка файла
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        icon.size = NSSize(width: 48, height: 48)
        imageView.image = icon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false

        // Название файла — ТРАНКАЦИЯ по середине + однострочный режим
        nameLabel.stringValue = fileURL.lastPathComponent
        nameLabel.font = .systemFont(ofSize: 10)
        nameLabel.textColor = .white
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        // Разрешаем «сжимать» лейбл по горизонтали, чтобы он уходил в троеточие,
        // а не раздвигал контейнер
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        // Вертикальный стек по центру карточки
        vstack.orientation = .vertical
        vstack.alignment = .centerX
        vstack.spacing = 6
        vstack.translatesAutoresizingMaskIntoConstraints = false
        vstack.addArrangedSubview(imageView)
        vstack.addArrangedSubview(nameLabel)
        addSubview(vstack)

        // Кнопка удаления (крестик)
        removeButton.title = ""
        removeButton.isBordered = false
        removeButton.bezelStyle = .texturedRounded
        removeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove")
        removeButton.contentTintColor = .tertiaryLabelColor
        removeButton.alphaValue = 0.8
        removeButton.target = self
        removeButton.action = #selector(removeTapped)
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(removeButton)

        // Констрейнты — центр содержимого и ограничение ширины текста,
        // чтобы длинные имена сокращались внутри карточки
        NSLayoutConstraint.activate([
            vstack.centerXAnchor.constraint(equalTo: centerXAnchor),
            vstack.centerYAnchor.constraint(equalTo: centerYAnchor),
            vstack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            vstack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),

            imageView.widthAnchor.constraint(equalToConstant: 48),
            imageView.heightAnchor.constraint(equalToConstant: 48),

            // Лейбл не шире карточки (минус поля), иначе будет вылезать
            nameLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -16),

            // Крестик
            removeButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            removeButton.widthAnchor.constraint(equalToConstant: 18),
            removeButton.heightAnchor.constraint(equalToConstant: 18),

            // Минимальные размеры самой карточки
            widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 115)
        ])
    }

    @objc private func removeTapped() { onRemove?() }

    // MARK: - Drag out (перетаскивание файла наружу)
    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }

        // Пишем в pasteboard сам файл (NSURL) — файл уже существует
        let writer = fileURL as NSURL
        let draggingItem = NSDraggingItem(pasteboardWriter: writer)

        // Превью перетаскивания — снимок карточки
        let dragImage = snapshotImage()
        let location = convert(event.locationInWindow, from: nil)
        let frame = NSRect(x: location.x - dragImage.size.width / 2,
                           y: location.y - dragImage.size.height / 2,
                           width: dragImage.size.width,
                           height: dragImage.size.height)
        draggingItem.setDraggingFrame(frame, contents: dragImage)

        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .default

        window.makeFirstResponder(self)
    }

    private func snapshotImage() -> NSImage {
        let size = bounds.size
        let rep = bitmapImageRepForCachingDisplay(in: bounds) ?? NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        cacheDisplay(in: bounds, to: rep)
        let img = NSImage(size: size)
        img.addRepresentation(rep)
        return img
    }

    // MARK: - NSDraggingSource
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return [.copy, .move]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // Если drop состоялся — удаляем элемент из полки (файл на диске не трогаем)
        if !operation.isEmpty {
            onRemove?()
        }
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
}
