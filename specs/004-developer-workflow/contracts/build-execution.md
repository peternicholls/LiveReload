# Build Execution Contract

## Configuration

The app accepts an executable URL, ordered arguments, working directory, environment additions, timeout, and enabled flag. It does not accept a shell command string. Validation errors identify the field and preserve the previous valid configuration.

- The executable path is standardized, limited to 4,096 UTF-8 bytes, validated as a regular executable file when saved, and revalidated immediately before launch. A regular executable replaced in place is allowed; a missing or non-executable replacement becomes `launchFailed`.
- The working directory is standardized, symlink-resolved, limited to 4,096 UTF-8 bytes, and must remain inside the selected project root. It reuses that project's existing scoped folder access.
- Timeout defaults to 300 seconds and accepts whole seconds in `1...3600`.
- Arguments are limited to 256 entries, 4,096 UTF-8 bytes per entry, and 65,536 UTF-8 bytes total.
- Environment additions are limited to 64 entries, 128 UTF-8 bytes per key, 8,192 UTF-8 bytes per value, and 65,536 UTF-8 bytes total. Keys match `[A-Za-z_][A-Za-z0-9_]*`; exact keys `PWD`, `OLDPWD`, `SHLVL`, and `_` plus prefixes `DYLD_` and `LD_` are rejected, while `PATH` is allowed. Paths, arguments, keys, and values containing NUL are rejected.
- Because App Sandbox is deferred, Phase 3 stores the executable file URL without adding an executable bookmark; launch failure never overwrites the saved configuration.

The redacted configuration summary contains the executable label, project-relative working directory, argument count, environment-key names, timeout, and enabled state. It never contains argument or environment values.

## Run results

`BuildRunner` reports exactly one terminal result per started run:

- `succeeded(exitCode: 0)`
- `failed(exitCode: nonZero, summary)`
- `launchFailed(summary)`
- `timedOut(summary)`
- `cancelled(summary)`
- `stopped(summary)`

stdout/stderr arrive as bounded incremental events. Exact nonempty configured environment values are replaced before retention, bounding, or display. Combined live capture stops retaining bytes after 1,048,576 bytes per run, any displayed line is limited to 16,384 bytes, and the terminal activity summary is limited to 4,096 bytes. A result marks every truncation deterministically. Argument and environment values are never included in configuration or activity metadata. With two maximum-output active runs and 500 maximum-size terminal summaries, logical retained diagnostic payload remains at or below 5 MiB.

## Lifecycle

The owner starts, cancels, and tears down the launched process group through a narrow process-control adapter. Cancellation sends graceful termination, waits at most 2 seconds, then forcibly terminates the group, covering the direct process and fixture-supported descendants. The clock and grace interval are injectable for tests. Repeated cancellation and teardown are no-ops after a terminal result.
