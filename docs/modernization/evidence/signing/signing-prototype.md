# Signing Prototype Evidence

- **Task:** T048
- **Date:** 2026-07-12
- **Procedure:** Compile a trivial Swift arm64 executable, sign it ad hoc with Hardened Runtime, then inspect and verify it.

```text
swiftc -warnings-as-errors main.swift -o SigningPrototype
codesign --force --sign - --options runtime SigningPrototype
codesign --verify --strict SigningPrototype
```

Observed metadata:

```text
Format=Mach-O thin (arm64)
Signature=adhoc
CodeDirectory flags=adhoc,runtime
Runtime Version=26.2.0
TeamIdentifier=not set
```

This proves a local private hardened-runtime workflow only. Ad-hoc signing is not a public-distribution, Developer ID, notarization, or App Store result.
