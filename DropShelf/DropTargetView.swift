import Cocoa

class DropTargetView: NSView {
    var onFilesDropped: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL])
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
        guard !isLocalDrag(sender),
              let urls = sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]
              ) as? [URL], !urls.isEmpty else { return false }
        onFilesDropped?(urls)
        return true
    }
}
