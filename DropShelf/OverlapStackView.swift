import Cocoa

/// Контейнер, раскладывающий карточки по общему центру как «стопку»:
/// все карточки совмещены по центру, нижние слегка повернуты,
/// верхняя (последняя добавленная) — без поворота.
final class OverlapStackView: NSView {

    /// Сколько карточек максимум показывать (остальные скрываются)
    var maxVisible: Int = 4 { didSet { needsLayout = true } }

    /// Углы поворота (в градусах) для нижних карточек.
    /// Последняя карточка всегда отображается без поворота (0°).
    var baseAngles: [CGFloat] = [-12, -6, 6, 12] { didSet { needsLayout = true } }

    override var isFlipped: Bool { true }

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

        // Скрываем те, что вне лимита
        if all.count > visible.count {
            for v in all.dropLast(visible.count) { v.isHidden = true }
        }

        for (i, v) in visible.enumerated() {
            // Фрейм карточки — по центру
            let size = v.intrinsicContentSize == .zero ? v.bounds.size : v.intrinsicContentSize
            let frame = CGRect(x: center.x - size.width/2,
                               y: center.y - size.height/2,
                               width: size.width,
                               height: size.height)
            v.frame = frame.integral

            // Поворот: все, кроме верхней, имеют угол; верхняя = 0°
            let isTop = (i == count - 1)
            let angleDeg: CGFloat = isTop ? 0 : (baseAngles[i % baseAngles.count])
            let angleRad = angleDeg * (.pi / 180)

            v.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            v.layer?.position = CGPoint(x: frame.midX, y: frame.midY)
            v.layer?.transform = CATransform3DMakeRotation(angleRad, 0, 0, 1)

            // Лёгкая градация теней/глубины
            v.layer?.shadowOpacity = isTop ? 0.4 : 0.25
            v.layer?.zPosition = CGFloat(i)
        }
    }
}
