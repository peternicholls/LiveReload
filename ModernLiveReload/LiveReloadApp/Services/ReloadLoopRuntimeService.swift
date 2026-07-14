import Foundation
import LiveReloadCore

struct ProjectRuntimeProjection: Equatable, Sendable {
    let monitoringState: MonitoringRuntimeState
    let recoveryReason: MonitoringRecoveryReason?
    let lastSafeBatch: ChangeBatch?

    static let stopped = ProjectRuntimeProjection(
        monitoringState: .stopped,
        recoveryReason: nil,
        lastSafeBatch: nil
    )

    func replacingState(
        _ state: MonitoringRuntimeState,
        reason: MonitoringRecoveryReason? = nil
    ) -> Self {
        Self(monitoringState: state, recoveryReason: reason, lastSafeBatch: lastSafeBatch)
    }
}

enum ReloadLoopRuntimeUpdate: Equatable, Sendable {
    case project(UUID, ProjectRuntimeProjection)
    case server(ServerState)
}

protocol ReloadLoopRuntimeServing: Sendable {
    func updates() async -> AsyncStream<ReloadLoopRuntimeUpdate>
    func startServer() async -> ServerState
    func stopServer() async -> ServerState
    func startMonitoring(_ project: ProjectConfiguration) async -> ProjectRuntimeProjection
    func stopMonitoring(projectID: UUID) async -> ProjectRuntimeProjection
    func retryMonitoring(_ project: ProjectConfiguration) async -> ProjectRuntimeProjection
    func manualReload(projectID: UUID) async -> ReloadBroadcastResult?
}

actor LiveReloadLoopRuntimeService: ReloadLoopRuntimeServing {
    private struct ProjectSession {
        let monitor: ProjectMonitor
        let pipeline: ProjectPipeline
    }

    private let provider: any FolderAccessProvider
    private let eventSource: any FileEventSource
    private let server: any ReloadServerControlling
    private var projectSessions: [UUID: ProjectSession] = [:]
    private var projectProjections: [UUID: ProjectRuntimeProjection] = [:]
    private var updateContinuations: [UUID: AsyncStream<ReloadLoopRuntimeUpdate>.Continuation] = [:]
    private var serverUpdatesTask: Task<Void, Never>?
    private var latestServerState: ServerState = .stopped

    init(
        provider: any FolderAccessProvider,
        eventSource: any FileEventSource = FSEventsFileEventSource(),
        server: any ReloadServerControlling = ReloadServer()
    ) {
        self.provider = provider
        self.eventSource = eventSource
        self.server = server
    }

    deinit {
        serverUpdatesTask?.cancel()
        for continuation in updateContinuations.values { continuation.finish() }
    }

    func updates() async -> AsyncStream<ReloadLoopRuntimeUpdate> {
        observeServerUpdatesIfNeeded()
        let id = UUID()
        let pair = AsyncStream<ReloadLoopRuntimeUpdate>.makeStream(bufferingPolicy: .bufferingNewest(128))
        pair.continuation.onTermination = { [weak self] _ in
            Task { await self?.removeUpdateContinuation(id) }
        }
        updateContinuations[id] = pair.continuation
        pair.continuation.yield(.server(latestServerState))
        for (projectID, projection) in projectProjections {
            pair.continuation.yield(.project(projectID, projection))
        }
        return pair.stream
    }

    func startServer() async -> ServerState {
        publishServer(.starting)
        await server.start()
        let state = await server.currentState()
        publishServer(state)
        return state
    }

    func stopServer() async -> ServerState {
        await server.stop()
        publishServer(.stopped)
        return .stopped
    }

    func startMonitoring(_ project: ProjectConfiguration) async -> ProjectRuntimeProjection {
        if let session = projectSessions[project.id] {
            return await projection(for: project.id, pipeline: session.pipeline)
        }

        publishProject(
            project.id,
            projectProjections[project.id, default: .stopped].replacingState(.starting)
        )

        let reference: FolderReference
        switch await provider.resolve(project.folderReference) {
        case .available(let availableReference):
            reference = availableReference
        case .stale, .missing, .denied, .corrupt:
            return failMonitoring(project.id, reason: .folderUnavailable)
        }

        do {
            let policy = try ExclusionPolicy(ignoreRules: project.ignoreRules)
            let accessToken: ScopedAccessToken
            do {
                accessToken = try await provider.beginAccess(to: reference)
            } catch {
                return failMonitoring(project.id, reason: .folderUnavailable)
            }
            let rootURL: URL
            do {
                rootURL = try await provider.resolvedURL(for: reference)
            } catch {
                accessToken.release()
                return failMonitoring(project.id, reason: .folderUnavailable)
            }
            let projectID = project.id
            let pipeline: ProjectPipeline
            do {
                pipeline = try ProjectPipeline(
                    projectID: projectID,
                    server: server,
                    policy: policy,
                    onSettled: { [weak self] batch, _ in
                        await self?.batchSettled(batch, projectID: projectID)
                    }
                )
            } catch {
                accessToken.release()
                throw error
            }
            let monitor = ProjectMonitor(
                source: eventSource,
                onSignal: { [weak self] signal in
                    await self?.receive(signal, pipeline: pipeline)
                },
                onStateChange: { [weak self] state, reason in
                    await self?.monitoringStateChanged(
                        projectID: projectID,
                        pipeline: pipeline,
                        state: state,
                        reason: reason
                    )
                }
            )
            projectSessions[project.id] = ProjectSession(monitor: monitor, pipeline: pipeline)
            await monitor.start(projectID: project.id, rootURL: rootURL, accessToken: accessToken)
            return await projection(for: project.id, pipeline: pipeline)
        } catch is FolderAccessError {
            projectSessions.removeValue(forKey: project.id)
            return failMonitoring(project.id, reason: .folderUnavailable)
        } catch {
            projectSessions.removeValue(forKey: project.id)
            return failMonitoring(project.id, reason: .sourceFailure)
        }
    }

    func stopMonitoring(projectID: UUID) async -> ProjectRuntimeProjection {
        guard let session = projectSessions.removeValue(forKey: projectID) else {
            publishProject(projectID, .stopped)
            return .stopped
        }
        await session.monitor.stop()
        await session.pipeline.stop()
        let stopped = ProjectRuntimeProjection(
            monitoringState: .stopped,
            recoveryReason: nil,
            lastSafeBatch: await session.pipeline.lastSettledBatch()
        )
        publishProject(projectID, stopped)
        return stopped
    }

    func retryMonitoring(_ project: ProjectConfiguration) async -> ProjectRuntimeProjection {
        _ = await stopMonitoring(projectID: project.id)
        return await startMonitoring(project)
    }

    func manualReload(projectID: UUID) async -> ReloadBroadcastResult? {
        guard let pipeline = projectSessions[projectID]?.pipeline else { return nil }
        let result = await pipeline.manualReload()
        publishServer(await server.currentState())
        return result
    }

    private func receive(
        _ signal: FileChangeSignal,
        pipeline: ProjectPipeline
    ) async {
        await pipeline.receive(signal)
    }

    private func monitoringStateChanged(
        projectID: UUID,
        pipeline: ProjectPipeline,
        state: MonitoringRuntimeState,
        reason: MonitoringRecoveryReason?
    ) async {
        await pipeline.setMonitoringState(state, reason: reason)
        publishProject(projectID, await projection(for: projectID, pipeline: pipeline))
    }

    private func projection(
        for projectID: UUID,
        pipeline: ProjectPipeline
    ) async -> ProjectRuntimeProjection {
        ProjectRuntimeProjection(
            monitoringState: await pipeline.state(),
            recoveryReason: await pipeline.currentRecoveryReason(),
            lastSafeBatch: await pipeline.lastSettledBatch()
        )
    }

    private func batchSettled(_ batch: ChangeBatch, projectID: UUID) async {
        guard batch.projectID == projectID,
              let pipeline = projectSessions[projectID]?.pipeline else { return }
        publishProject(projectID, await projection(for: projectID, pipeline: pipeline))
    }

    private func failMonitoring(
        _ projectID: UUID,
        reason: MonitoringRecoveryReason
    ) -> ProjectRuntimeProjection {
        let failed = ProjectRuntimeProjection(
            monitoringState: .failed,
            recoveryReason: reason,
            lastSafeBatch: projectProjections[projectID]?.lastSafeBatch
        )
        publishProject(projectID, failed)
        return failed
    }

    private func publishProject(_ projectID: UUID, _ projection: ProjectRuntimeProjection) {
        projectProjections[projectID] = projection
        publish(.project(projectID, projection))
    }

    private func publishServer(_ state: ServerState) {
        latestServerState = state
        publish(.server(state))
    }

    private func publish(_ update: ReloadLoopRuntimeUpdate) {
        for continuation in updateContinuations.values {
            continuation.yield(update)
        }
    }

    private func observeServerUpdatesIfNeeded() {
        guard serverUpdatesTask == nil else { return }
        let server = server
        serverUpdatesTask = Task { [weak self] in
            let updates = await server.stateUpdates()
            for await state in updates {
                guard !Task.isCancelled else { return }
                await self?.receiveServerState(state)
            }
        }
    }

    private func receiveServerState(_ state: ServerState) {
        if state != latestServerState { publishServer(state) }
    }

    private func removeUpdateContinuation(_ id: UUID) {
        updateContinuations.removeValue(forKey: id)
    }
}
