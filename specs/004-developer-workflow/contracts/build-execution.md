# Build Execution Contract

## Configuration

The app accepts an executable URL, ordered arguments, working directory, environment additions, timeout, and enabled flag. It does not accept a shell command string. Validation errors identify the field and preserve the previous valid configuration.

## Run results

`BuildRunner` reports exactly one terminal result per started run:

- `succeeded(exitCode: 0)`
- `failed(exitCode: nonZero, summary)`
- `launchFailed(summary)`
- `timedOut(summary)`
- `cancelled(summary)`
- `stopped(summary)`

stdout/stderr arrive as bounded incremental events. A result marks truncation when the configured output cap is reached. Environment values are never included in emitted summaries.

## Lifecycle

The owner starts, cancels, and tears down the child process. Cancellation attempts graceful termination, then forced termination within the documented grace period. Repeated cancellation and teardown are no-ops after a terminal result.
