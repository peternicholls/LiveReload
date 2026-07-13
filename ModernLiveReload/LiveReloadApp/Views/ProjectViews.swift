import LiveReloadCore
import SwiftUI

struct ProjectShellView: View {
    @Bindable var model: AppModel

    var body: some View {
        if model.isLoading {
            ProgressView("Restoring projects…")
                .controlSize(.large)
                .accessibilityIdentifier("state.loading")
                .frame(minWidth: 760, minHeight: 500)
        } else {
            projectNavigation
        }
    }

    private var projectNavigation: some View {
        NavigationSplitView {
            List(model.projects, selection: $model.selectedProjectID) { project in
                Label(project.displayName, systemImage: stateSymbol(project.folderAccessState))
                    .tag(project.id)
                    .accessibilityLabel("\(project.displayName), \(stateLabel(project.folderAccessState))")
                    .accessibilityIdentifier("project.row.\(project.id.uuidString)")
            }
            .navigationTitle("Projects")
            .safeAreaInset(edge: .bottom) {
                Button("Add Project", systemImage: "plus") { Task { await model.addProject() } }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("n", modifiers: .command)
                    .accessibilityIdentifier("project.add")
                    .padding()
            }
        } detail: {
            if let project = model.selectedProject {
                ProjectDetailView(model: model, project: project)
            } else {
                EmptyProjectView(model: model)
            }
        }
        .frame(minWidth: 760, minHeight: 500)
        .alert("Recovery information", isPresented: Binding(
            get: { model.recoveryMessage != nil },
            set: { if !$0 { model.recoveryMessage = nil } }
        )) { Button("OK") { model.recoveryMessage = nil } } message: {
            Text(model.recoveryMessage ?? "")
        }
    }

    private func stateSymbol(_ state: FolderAccessState) -> String {
        switch state {
        case .available: "checkmark.circle"
        case .needsRepair: "wrench.and.screwdriver"
        case .missing: "questionmark.folder"
        case .denied: "lock.trianglebadge.exclamationmark"
        }
    }

    private func stateLabel(_ state: FolderAccessState) -> String {
        switch state {
        case .available: "available"
        case .needsRepair: "access needs repair"
        case .missing: "folder missing"
        case .denied: "access denied"
        }
    }
}

private struct EmptyProjectView: View {
    let model: AppModel

    var body: some View {
        ContentUnavailableView {
            Label("No Projects Yet", systemImage: "folder.badge.plus")
                .accessibilityIdentifier("state.empty")
        } description: {
            Text("LiveReload will remember folders you explicitly select. Monitoring and reload are not enabled in this foundation release.")
        } actions: {
            Button("Add Project") { Task { await model.addProject() } }
                .accessibilityIdentifier("empty.add")
        }
    }
}

private struct ProjectDetailView: View {
    let model: AppModel
    let project: ProjectConfiguration
    @State private var draftName = ""
    @State private var confirmingRemoval = false

    var body: some View {
        Form {
            Section("Project") {
                TextField("Display name", text: $draftName)
                    .onAppear { draftName = project.displayName }
                    .onSubmit { Task { await model.rename(project, to: draftName) } }
                    .accessibilityIdentifier("project.name")
                Text(project.folderReference.displayLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityLabel("Selected folder: \(project.folderReference.displayLabel)")
                Toggle("Enabled for future monitoring", isOn: Binding(
                    get: { project.isEnabled },
                    set: { value in Task { await model.setEnabled(project, enabled: value) } }
                ))
                .accessibilityIdentifier("project.enabled")
            }
            if project.folderAccessState != .available {
                Section("Access needs attention") {
                    Text("The folder is unavailable, but this project and its settings are preserved.")
                    Button("Repair Access") { Task { await model.repair(project) } }
                        .accessibilityIdentifier("project.repair")
                }
            }
            Section("Activity") {
                if model.activities.isEmpty { Text("No recent activity") }
                ForEach(model.activities.suffix(20)) { event in
                    Label(event.summary, systemImage: event.severity == .error ? "exclamationmark.triangle" : "info.circle")
                }
            }
            Section("About") {
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
                let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Local"
                Text("LiveReload \(version) (\(build))")
                    .accessibilityIdentifier("app.version")
            }
            Section {
                Button("Remove Project…", role: .destructive) { confirmingRemoval = true }
                    .accessibilityIdentifier("project.remove")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(project.displayName)
        .confirmationDialog("Remove project configuration?", isPresented: $confirmingRemoval) {
            Button("Remove Configuration", role: .destructive) { Task { await model.remove(project) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only LiveReload's saved configuration and bookmark are removed. Files in the selected folder remain unchanged.")
                .accessibilityIdentifier("remove.explanation")
        }
    }
}
