import AppKit
import SwiftUI
import TangeloCore

/// Popover content: format buttons for just-dropped files, then the job list.
struct PanelView: View {
    @ObservedObject var queue: JobQueue
    @ObservedObject var drop: DropState
    let onPick: (Format) -> Void
    let onChooseFiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !drop.files.isEmpty {
                Text("Convert \(drop.files.count) file\(drop.files.count == 1 ? "" : "s") to:").font(.headline)
                if drop.choices.isEmpty {
                    Text("Can't convert this file type").foregroundStyle(.secondary)
                } else {
                    HStack { ForEach(drop.choices, id: \.self) { f in Button(f.name) { onPick(f) } } }
                }
                Divider()
            }
            if queue.jobs.isEmpty {
                Text("Drop files on the menu-bar icon").foregroundStyle(.secondary)
            }
            ForEach(queue.jobs) { job in JobRow(job: job) }
            HStack {
                Button("Choose Files…", action: onChooseFiles)
                Spacer()
                Button("Clear") { queue.clearFinished() }.disabled(queue.jobs.isEmpty)
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 360)
    }
}

struct JobRow: View {
    let job: Job
    var body: some View {
        HStack {
            Text("\(job.input.lastPathComponent) → \(job.format.name)").lineLimit(1).truncationMode(.middle)
            Spacer()
            switch job.state {
            case .queued: Text("waiting").foregroundStyle(.secondary)
            case .running: ProgressView().controlSize(.small)
            case .done(let url):
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            case .failed(let msg):
                Text(msg).foregroundStyle(.red).lineLimit(2).help(msg)
            }
        }
    }
}

final class DropState: ObservableObject {
    @Published var files: [URL] = []
    @Published var choices: [Format] = []
}
