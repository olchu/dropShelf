import Cocoa

/// Кнопка закрытия: круг с заданной прозрачностью + «x».
/// Цвета адаптируются под светлую и тёмную тему.
final class CloseButton: NSButton {
    private let diameter: CGFloat

    private let backgroundView = NSView()
    private let iconView = NSImageView()

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

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = diameter / 2
        backgroundView.layer?.masksToBounds = true
        applyAlpha(normalAlpha)
        addSubview(backgroundView)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        if let img = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close") {
            let cfg = NSImage.SymbolConfiguration(pointSize: diameter * 0.5, weight: .semibold)
            iconView.image = img.withSymbolConfiguration(cfg)
        }
        iconView.contentTintColor = .secondaryLabelColor
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

    private func applyAlpha(_ alpha: CGFloat) {
        backgroundView.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(alpha).cgColor
    }

    // Обновляем цвет слоя при смене темы (cgColor не динамический)
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAlpha(normalAlpha)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        // consume
    }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        window?.orderOut(nil)
    }

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
        backgroundView.animator().layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(hoverAlpha).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        backgroundView.animator().layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(normalAlpha).cgColor
    }
}
