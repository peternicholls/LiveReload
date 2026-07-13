# Ignore Rules Contract

## Input normalization

- Rules and observed paths are evaluated as normalized paths relative to the selected project root.
- Separators are `/`; matching is Unicode-normalization stable.
- A path that resolves outside the selected root is not eligible for a reload decision.

## Rule grammar

| Token | Meaning |
|---|---|
| `/` | path separator |
| `*` | zero or more characters within one path segment |
| `**` | zero or more path segments |
| `?` | one character within a path segment |
| trailing `/` | directory and all descendants |

Rules are positive exclusions only. Escaping, negation, inclusion overrides, and full gitignore compatibility are deferred.

## Precedence

1. Normalize the observed path relative to the project root.
2. Apply built-in exclusions for version-control metadata, common dependencies, build outputs, and editor temporary files.
3. Apply user exclusion rules in stored order.
4. If any rule matches, exclude the path; otherwise retain it.

Hidden files are retained unless a built-in or user rule matches them.

## Verification examples

- `.git/HEAD`, `node_modules/pkg/index.js`, build output, and editor swap files are excluded.
- `.env.example`, `.well-known/site`, and a user source file beginning with `.` remain eligible unless explicitly excluded.
- Unicode and repeated separators normalize to one deterministic matching result.
