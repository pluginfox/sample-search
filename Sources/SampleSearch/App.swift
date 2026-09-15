import SwiftUI

@main
struct SampleSearchApp: App {
    @StateObject private var model = LibraryModel.shared
    @StateObject private var updates = UpdateChecker()

    var body: some Scene {
        WindowGroup("Sample Search") {
            ContentView()
                .environmentObject(model)
                .environmentObject(updates)
                .background(WindowFrameSaver(name: "MainWindow"))
                .onAppear { updates.checkAtLaunchIfDue() }
        }
        .defaultSize(width: 1280, height: 780)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(updates.isChecking ? "Checking for Updates…" : "Check for Updates…") {
                    Task { await updates.check() }
                }
                .disabled(updates.isChecking)
            }
            CommandGroup(replacing: .newItem) {
                Button("Library Folders…") { model.showFolders = true }
                    .keyboardShortcut(",", modifiers: .command)
                Button("Rescan Library") { model.rescan() }
                    .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Update Trigger Browser Folder") { model.updateBrowserFolder() }
                    .keyboardShortcut("e", modifiers: .command)
                Button("Reveal Trigger Browser Folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([BrowserFolder.url])
                }
            }
            CommandGroup(after: .textEditing) {
                Button("Find") { NotificationCenter.default.post(name: .focusSearch, object: nil) }
                    .keyboardShortcut("f", modifiers: .command)
            }
            CommandMenu("Sample") {
                Button("Play Preview") { model.playSelection() }
                    .keyboardShortcut(.space, modifiers: [])
                    .disabled(!model.selectedRows.contains { $0.isPlayable })
                Button("Stop Preview") { model.preview.stop() }
                    .keyboardShortcut(".", modifiers: .command)
                Divider()
                Button("Toggle Favourite") { model.toggleFavoriteOfSelection() }
                    .keyboardShortcut("d", modifiers: .command)
                    .disabled(model.selection.isEmpty)
                Button("Reveal in Finder") { model.revealInFinder(model.selection) }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(model.selection.isEmpty)
                Button("Copy Path") { model.copyPaths(model.selection) }
                    .keyboardShortcut("c", modifiers: .command)
                    .disabled(model.selection.isEmpty)
            }
        }
    }
}

/// Saves and restores the window's size and position under an autosave name, independent of the
/// system's "close windows when quitting" preference.
struct WindowFrameSaver: NSViewRepresentable {
    var name: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.setFrameAutosaveName(name)
            window.setFrameUsingName(name)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
