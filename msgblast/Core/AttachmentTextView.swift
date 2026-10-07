import AppKit

public final class AttachmentTextView: NSTextView {
    public var importAttachment: ((AttachmentImport) -> Void)?
    public var sendMessage: (() -> Void)?
    public var attachmentsEnabled = true
    public override var readablePasteboardTypes: [NSPasteboard.PasteboardType] { [.fileURL, .png, .tiff] + super.readablePasteboardTypes }
    public override func readSelection(from pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        if let selection = AttachmentImport.read(from: pasteboard) {
            if attachmentsEnabled { importAttachment?(selection) }
            return attachmentsEnabled
        }
        return super.readSelection(from: pasteboard, type: type)
    }
    public override func paste(_ sender: Any?) {
        if let selection = AttachmentImport.read(from: .general) {
            if attachmentsEnabled { importAttachment?(selection) }
        } else { super.paste(sender) }
    }
    public override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if let selection = AttachmentImport.read(from: sender.draggingPasteboard) {
            if attachmentsEnabled { importAttachment?(selection) }
            return attachmentsEnabled
        }
        return super.performDragOperation(sender)
    }
    public override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.availableType(from: [.fileURL, .png, .tiff]) != nil { return attachmentsEnabled ? .copy : [] }
        return super.draggingEntered(sender)
    }
    public override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if sender.draggingPasteboard.availableType(from: [.fileURL, .png, .tiff]) != nil { return attachmentsEnabled ? .copy : [] }
        return super.draggingUpdated(sender)
    }
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        if window?.firstResponder === self, [36, 76].contains(event.keyCode), modifiers == .command, let sendMessage {
            sendMessage()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
    public override func keyDown(with event: NSEvent) {
        if [36, 76].contains(event.keyCode), !event.modifierFlags.contains(.shift) { sendMessage?() }
        else { super.keyDown(with: event) }
    }
}

