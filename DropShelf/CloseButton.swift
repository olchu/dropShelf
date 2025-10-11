import Cocoa

/// Кнопка закрытия: белый круг с заданной прозрачностью + белый «x».
/// При наведении круг становится ЯРЧЕ (альфа увеличивается).
final class CloseButton: NSButton {
    // Размер
    private let diameter: CGFloat

    // Фон-круг (обычный NSView с CALayer)
    private let backgroundView = NSView()
    // Иконка «x»
    private let iconView = NSImageView()

    // Прозрачность белого круга
    var normalAlpha: CGFloat = 0.10 { didSet { applyAlpha(normalAlpha) } }
    var hoverAlpha:  CGFloat = 0.25

    private var tracking: NSTrackingArea?

    init(diameter: CGFloat) {
        self.diameter = diameter
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        bezelStyle = .shadowlessSquare
        imagePosition = .imageOnly
        wantsLayer = true

        // Белый круг с нужной альфой
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = diameter / 2
        backgroundView.layer?.masksToBounds = true
        applyAlpha(normalAlpha)
        addSubview(backgroundView)

        // Белый «x»
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        if let img = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close") {
            let cfg = NSImage.SymbolConfiguration(pointSize: diameter * 0.5, weight: .semibold)
            iconView.image = img.withSymbolConfiguration(cfg)
        }
        iconView.contentTintColor = NSColor(white: 0.9, alpha: 0.75)
        backgroundView.addSubview(iconView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: diameter),
            heightAnchor.constraint(equalToConstant: diameter),

            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // Применяем белый цвет с альфой к фону
    private func applyAlpha(_ alpha: CGFloat) {
        backgroundView.layer?.backgroundColor = NSColor.white.withAlphaComponent(alpha).cgColor
    }

    // Hover-эффект (увеличиваем альфу круга)
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        tracking = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking!)
    }

    override func mouseEntered(with event: NSEvent) {
        backgroundView.animator().layer?.backgroundColor = NSColor.white.withAlphaComponent(hoverAlpha).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        backgroundView.animator().layer?.backgroundColor = NSColor.white.withAlphaComponent(normalAlpha).cgColor
    }
}
