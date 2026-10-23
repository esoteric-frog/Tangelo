import AppKit
import TangeloCore

@MainActor
enum ActionRunner {
    static func run(_ action: FileAction, _ files: [URL]) {
        let pb = NSPasteboard.general
        switch action {
        case .airDrop:
            NSApp.activate()
            NSSharingService(named: .sendViaAirDrop)?.perform(withItems: files)
        case .copyFiles:
            pb.clearContents()
            pb.writeObjects(files as [NSURL])
        case .copyPaths:
            pb.clearContents()
            pb.setString(FileAction.paths(files), forType: .string)
        case .terminal:
            guard let dir = FileAction.terminalFolder(for: files),
                  let term = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else { return }
            NSWorkspace.shared.open([dir], withApplicationAt: term, configuration: NSWorkspace.OpenConfiguration())
        case .showInFinder:
            NSWorkspace.shared.activateFileViewerSelecting(files)
        }
    }
}
