# Monitoring Service Contract

## Responsibilities

The monitoring boundary starts and stops a recursive observation session for one project root, converts native callbacks into bounded typed signals, and reports lifecycle and recovery outcomes. It does not decide browser protocol behavior or persist project configuration.

## Inputs

- A project ID and a validated folder-access scope.
- An explicit start or stop request.
- Native path/flag callbacks from the active stream.

## Outputs

- Lifecycle: `starting`, `watching`, `stopped`, `recovering`, or `failed`.
- A bounded `FileChangeSignal` for a normalized project-relative path.
- A recovery signal for root change, required scan, dropped events, inaccessible root, or source failure.

## Guarantees

- Exactly one active source belongs to a project session.
- Start and stop are idempotent.
- Callback data is copied before crossing into asynchronous processing.
- Stop and recovery cancel pending batch work and release folder access.
- The service never exposes raw absolute paths in user-visible output.

## Test seam

`FileEventSource` is injected. Its fake emits paths, flags, failure, and lifecycle events deterministically; the production adapter is verified against a workspace-backed disposable directory.
