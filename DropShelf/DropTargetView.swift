import Cocoa

class DropTargetView: NSView {
    var onFilesDropped: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(PasteboardImporter.supportedTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(PasteboardImporter.supportedTypes)
    }

    private func isLocalDrag(_ sender: NSDraggingInfo) -> Bool {
        sender.draggingSource is OverlapStackView
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isLocalDrag(sender) ? [] : .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        isLocalDrag(sender) ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard !isLocalDrag(sender) else { return false }
        return PasteboardImporter.importItems(from: sender.draggingPasteboard) { [weak self] urls in
            guard urls.isEmpty == false else { return }
            self?.onFilesDropped?(urls)
        }
    }
}
