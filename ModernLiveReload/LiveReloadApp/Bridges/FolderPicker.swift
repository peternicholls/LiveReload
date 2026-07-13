import AppKit

@MainActor
enum FolderPicker {
    static func chooseFolder(prompt: String = "Choose Project Folder") -> URL? {
        if let testPath = ProcessInfo.processInfo.environment["LIVERELOAD_UI_TEST_FOLDER"] {
            return URL(fileURLWithPath: testPath, isDirectory: true)
        }
        let panel = NSOpenPanel()
        panel.title = prompt
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }
}
