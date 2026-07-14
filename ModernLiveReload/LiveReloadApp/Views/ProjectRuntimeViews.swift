import LiveReloadCore
import SwiftUI

struct ProjectMonitoringSection: View {
    let model: AppModel
    let project: ProjectConfiguration

    private var projection: ProjectRuntimeProjection {
        model.runtimeProjection(for: project.id)
    }

    private var isProjectBusy: Bool {
        model.isProjectMutationPending(project.id) || model.isRuntimeOperationPending(project.id)
    }

    var body: some View {
        Section("Monitoring") {
            Label(stateTitle, systemImage: stateSymbol)
                .accessibilityIdentifier(stateIdentifier)
                .accessibilityLabel("Monitoring status: \(stateTitle)")
                .accessibilitySortPriority(4)

            Text(stateExplanation)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let recoveryExplanation {
                Label(recoveryExplanation, systemImage: "shield.checkered")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("monitoring.recovery-reason")
            }

            monitoringAction

            if projection.recoveryReason == .folderUnavailable ||
                projection.recoveryReason == .rootChanged {
                Button("Repair Folder Access", systemImage: "folder.badge.gearshape") {
                    Task { await model.repair(project) }
                }
                .accessibilityIdentifier("monitoring.repair")
                .accessibilityLabel("Repair folder access for this project")
                .disabled(isProjectBusy)
            }

            if model.isRuntimeOperationPending(project.id) {
                ProgressView("Updating monitoring…")
                    .accessibilityIdentifier("monitoring.operation.pending")
            }
        }
    }

    @ViewBuilder
    private var monitoringAction: some View {
        switch projection.monitoringState {
        case .stopped:
            Button("Start Monitoring", systemImage: "play.fill") {
                Task { await model.startMonitoring(project) }
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .accessibilityIdentifier("monitoring.start")
            .accessibilityLabel("Start monitoring this project")
            .disabled(isProjectBusy || !project.isEnabled || project.folderAccessState != .available)

        case .starting, .watching:
            Button("Stop Monitoring", systemImage: "stop.fill") {
                Task { await model.stopMonitoring(project) }
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .accessibilityIdentifier("monitoring.stop")
            .accessibilityLabel("Stop monitoring this project")
            .disabled(isProjectBusy)

        case .recovering, .failed:
            Button("Retry Monitoring", systemImage: "arrow.clockwise") {
                Task { await model.retryMonitoring(project) }
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .accessibilityIdentifier("monitoring.retry")
            .accessibilityLabel("Retry monitoring this project")
            .disabled(isProjectBusy || !project.isEnabled || project.folderAccessState != .available)

        case .stopping:
            EmptyView()
        }
    }

    private var stateTitle: String {
        switch projection.monitoringState {
        case .stopped: "Stopped"
        case .starting: "Starting"
        case .watching: "Watching"
        case .stopping: "Stopping"
        case .recovering: "Recovering"
        case .failed: "Failed"
        }
    }

    private var stateSymbol: String {
        switch projection.monitoringState {
        case .stopped: "pause.circle"
        case .starting: "hourglass.circle"
        case .watching: "eye.circle.fill"
        case .stopping: "stop.circle"
        case .recovering: "arrow.trianglehead.2.clockwise.rotate.90.circle"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var stateIdentifier: String {
        switch projection.monitoringState {
        case .stopped: "monitoring.stopped"
        case .starting: "monitoring.starting"
        case .watching: "monitoring.watching"
        case .stopping: "monitoring.stopping"
        case .recovering: "monitoring.recovering"
        case .failed: "monitoring.failed"
        }
    }

    private var stateExplanation: String {
        switch projection.monitoringState {
        case .stopped:
            "This project is not observing files. Start monitoring when you are ready."
        case .starting:
            "LiveReload is preparing folder access and file observation."
        case .watching:
            "Supported project-relative changes can trigger reloads."
        case .stopping:
            "LiveReload is releasing file observation and folder access."
        case .recovering:
            "Monitoring paused safely. The project configuration is preserved."
        case .failed:
            "Monitoring could not start safely. The project configuration is preserved."
        }
    }

    private var recoveryExplanation: String? {
        switch projection.recoveryReason {
        case .rootChanged:
            "The selected folder changed or moved. Repair folder access or restore it, then retry."
        case .eventsDropped:
            "Some file events were lost. Retry to begin a fresh monitoring session."
        case .scanRequired:
            "The file event stream requires a fresh scan. Retry to begin a new session."
        case .folderUnavailable:
            "Folder access is unavailable. Repair access, then retry monitoring."
        case .sourceFailure:
            "File observation ended unexpectedly. Retry when the folder is available."
        case nil:
            nil
        }
    }
}

struct LocalReloadServerSection: View {
    let model: AppModel
    let project: ProjectConfiguration

    private var clientCountSummary: String {
        model.connectedClientCount == 1
            ? "1 compatible browser connected"
            : "\(model.connectedClientCount) compatible browsers connected"
    }

    var body: some View {
        Section("Local Server") {
            serverStatus

            if model.serverState.phase == .listening {
                Label(
                    model.connectedClientCount == 0
                        ? "No compatible browsers connected"
                        : clientCountSummary,
                    systemImage: model.connectedClientCount == 0
                        ? "rectangle.connected.to.line.below"
                        : "checkmark.rectangle.stack.fill"
                )
                .accessibilityIdentifier(
                    model.connectedClientCount == 0 ? "server.no-clients" : "server.clients"
                )
                .accessibilityLabel("Browser connections")
                .accessibilityValue(clientCountSummary)
                .accessibilitySortPriority(2)

                if model.connectedClientCount == 0 {
                    Text("Connect a protocol-7 compatible browser to the local LiveReload endpoint.")
                        .foregroundStyle(.secondary)
                }
            }

            serverAction

            Button("Reload Connected Browsers", systemImage: "arrow.clockwise") {
                Task { await model.manualReload(project) }
            }
            .keyboardShortcut("r", modifiers: .command)
            .accessibilityIdentifier("reload.manual")
            .accessibilityLabel("Reload this project in connected browsers")
            .disabled(
                !model.canManuallyReload(project.id) ||
                    model.isServerOperationPending ||
                    model.isProjectMutationPending(project.id)
            )

            if model.isServerOperationPending {
                ProgressView("Updating local server…")
                    .accessibilityIdentifier("server.operation.pending")
            }
        }
    }

    @ViewBuilder
    private var serverStatus: some View {
        switch model.serverState.phase {
        case .stopped:
            Label("Local server stopped", systemImage: "network.slash")
                .accessibilityIdentifier("server.stopped")
        case .starting:
            Label("Local server starting", systemImage: "hourglass.circle")
                .accessibilityIdentifier("server.starting")
        case .listening:
            Label("Local server ready", systemImage: "network")
                .accessibilityIdentifier("server.listening")
        case .portConflict:
            VStack(alignment: .leading, spacing: 6) {
                Label("Local reload port is in use", systemImage: "exclamationmark.triangle.fill")
                    .accessibilityIdentifier("server.port-conflict")
                Text("Monitoring is unchanged and project configuration is preserved. Resolve the local conflict, then retry.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .failed:
            VStack(alignment: .leading, spacing: 6) {
                Label("Local server failed", systemImage: "xmark.octagon.fill")
                    .accessibilityIdentifier("server.failed")
                Text("Monitoring is unchanged. Retry when the local endpoint is available.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var serverAction: some View {
        switch model.serverState.phase {
        case .stopped:
            Button("Start Local Server", systemImage: "play.fill") {
                Task { await model.startLocalServer() }
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .accessibilityIdentifier("server.start")
            .disabled(model.isServerOperationPending)
        case .portConflict, .failed:
            Button("Retry Local Server", systemImage: "arrow.clockwise") {
                Task { await model.retryLocalServer() }
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .accessibilityIdentifier("server.retry")
            .accessibilityLabel("Retry the local reload server")
            .disabled(model.isServerOperationPending)
        case .starting, .listening:
            EmptyView()
        }
    }
}

struct ProjectActivitySection: View {
    static let maximumVisibleBatchPaths = 8
    static let maximumVisibleEvents = 12

    let model: AppModel
    let project: ProjectConfiguration

    private var batch: ChangeBatch? {
        model.runtimeProjection(for: project.id).lastSafeBatch
    }

    private var visiblePaths: [String] {
        Array(batch?.relativePaths.prefix(Self.maximumVisibleBatchPaths) ?? [])
    }

    private var recentActivities: [ActivityEvent] {
        Array(model.activities.lazy
            .filter { $0.projectID == nil || $0.projectID == project.id }
            .suffix(Self.maximumVisibleEvents))
    }

    var body: some View {
        Section("Activity") {
            if let batch {
                Label(batchTitle(batch), systemImage: batchSymbol(batch))
                    .accessibilityIdentifier("activity.batch")
                    .accessibilityLabel(batchTitle(batch))

                ForEach(Array(visiblePaths.enumerated()), id: \.offset) { index, path in
                    Text(path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("activity.batch.path.\(index)")
                        .accessibilityLabel("Changed project file: \(path)")
                }

                let overflowCount = batch.relativePaths.count - visiblePaths.count
                if overflowCount > 0 {
                    Label("\(overflowCount) more changed files", systemImage: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("activity.batch.overflow")
                        .accessibilityLabel("\(overflowCount) additional project-relative file changes")
                }
            } else {
                Text("No settled file changes")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("activity.batch.empty")
            }

            ForEach(recentActivities) { event in
                Label(event.summary, systemImage: activitySymbol(event.severity))
                    .lineLimit(2)
                    .accessibilityLabel("\(event.severity.rawValue.capitalized): \(event.summary)")
            }
        }
    }

    private func batchTitle(_ batch: ChangeBatch) -> String {
        let count = batch.relativePaths.count
        let noun = count == 1 ? "file" : "files"
        let kind = batch.classification == .stylesheetOnly ? "Stylesheet update" : "Page update"
        return "\(kind): \(count) \(noun)"
    }

    private func batchSymbol(_ batch: ChangeBatch) -> String {
        batch.classification == .stylesheetOnly ? "paintbrush.fill" : "doc.badge.arrow.up"
    }

    private func activitySymbol(_ severity: ActivitySeverity) -> String {
        switch severity {
        case .debug: "ladybug"
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .error: "xmark.octagon"
        }
    }
}
