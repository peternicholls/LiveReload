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
        } else if !model.canMutateProjects {
            ConfigurationRecoveryView(state: model.configurationStoreState)
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
                    .disabled(!model.canMutateProjects || model.isAddingProject)
                    .padding()
            }
        } detail: {
            if let project = model.selectedProject {
                ProjectDetailView(model: model, project: project)
                    .id(project.id)
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

private struct ConfigurationRecoveryView: View {
    let state: ConfigurationStoreState

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "externaldrive.badge.exclamationmark")
                .accessibilityIdentifier(accessibilityIdentifier)
        } description: {
            Text(message)
        }
        .frame(minWidth: 760, minHeight: 500)
    }

    private var title: String {
        switch state {
        case .sourceRecoveryRequired:
            "Configuration Needs Recovery"
        case .newerVersion:
            "Newer Configuration Detected"
        case .unavailable:
            "Configuration Storage Unavailable"
        case .writable:
            "Configuration Ready"
        }
    }

    private var message: String {
        switch state {
        case .sourceRecoveryRequired:
            "LiveReload preserved the existing configuration. Restore access to its storage, then relaunch before changing projects."
        case .newerVersion(let version):
            "This file uses configuration version \(version). Open it with a compatible LiveReload version; this version will not modify it."
        case .unavailable:
            "LiveReload could not open Application Support. Restore storage access, then relaunch before changing projects."
        case .writable:
            "Project configuration is available."
        }
    }

    private var accessibilityIdentifier: String {
        switch state {
        case .sourceRecoveryRequired:
            "state.configuration.source-recovery"
        case .newerVersion:
            "state.configuration.newer"
        case .unavailable:
            "state.configuration.unavailable"
        case .writable:
            "state.configuration.writable"
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
            Text("LiveReload remembers folders you explicitly select. Monitoring begins only when you start it for a project.")
        } actions: {
            Button("Add Project") { Task { await model.addProject() } }
                .accessibilityIdentifier("empty.add")
                .disabled(!model.canMutateProjects || model.isAddingProject)
        }
    }
}

private struct ProjectDetailView: View {
    let model: AppModel
    let project: ProjectConfiguration
    @State private var draftName = ""
    @State private var confirmingRemoval = false

    var body: some View {
        let mutationPending = model.isProjectMutationPending(project.id)
        let runtimePending = model.isRuntimeOperationPending(project.id)
        let projectOperationPending = mutationPending || runtimePending
        Form {
            Section("Project") {
                TextField("Display name", text: $draftName)
                    .onAppear { draftName = project.displayName }
                    .onSubmit { Task { await model.rename(project, to: draftName) } }
                    .accessibilityIdentifier("project.name")
                    .disabled(projectOperationPending)
                Text(project.folderReference.displayLabel)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityLabel("Selected folder: \(project.folderReference.displayLabel)")
                Toggle("Enabled for monitoring", isOn: Binding(
                    get: { project.isEnabled },
                    set: { value in Task { await model.setEnabled(project, enabled: value) } }
                ))
                .accessibilityIdentifier("project.enabled")
                .disabled(projectOperationPending)
                if mutationPending {
                    ProgressView("Saving project changes…")
                        .accessibilityIdentifier("project.mutation.pending")
                }
            }
            if project.folderAccessState != .available {
                Section("Access needs attention") {
                    Text("The folder is unavailable, but this project and its settings are preserved.")
                    Button("Repair Access") { Task { await model.repair(project) } }
                        .accessibilityIdentifier("project.repair")
                        .disabled(projectOperationPending)
                }
            }
            ProjectMonitoringSection(model: model, project: project)
            LocalReloadServerSection(model: model, project: project)
            ProjectActivitySection(model: model, project: project)
            Section("About") {
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
                let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Local"
                Text("LiveReload \(version) (\(build))")
                    .accessibilityIdentifier("app.version")
            }
            Section {
                Button("Remove Project…", role: .destructive) { confirmingRemoval = true }
                    .accessibilityIdentifier("project.remove")
                    .disabled(projectOperationPending)
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
