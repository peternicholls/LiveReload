import LiveReloadCore
import SwiftUI

@main
struct LiveReloadApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ProjectShellView(model: model)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Add Project") { Task { await model.addProject() } }
                    .keyboardShortcut("n", modifiers: .command)
                    .disabled(model.isLoading || !model.canMutateProjects || model.isAddingProject)
            }
        }
    }
}
