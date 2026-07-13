# Archived Application Static Inspection

- **Task:** T015
- **Date:** 2026-07-11
- **Procedure:** Hash executable components, inspect the code-signing metadata, and perform Gatekeeper assessment without launching the application.
- **Execution decision:** Not launched. ISS-001 records the unavailable disposable, network-restricted environment required by the constitution.

## SHA-256

```text
9376efd6734c3157593e2a815ba0d935a5be109b8c6b26857123ca1ae134ccab  LiveReload.app/Contents/MacOS/LiveReload
0db32f58cc5363a12e19aeefcba6e4019119fb37794b9120af26eab5bcc5abce  LiveReload.app/Contents/Resources/LiveReloadNodejs
```

## Signing and architecture observations

- Bundle identifier: `com.livereload.LiveReload`
- Main executable architecture: `x86_64`
- Signing authority chain: Apple Mac OS Application Signing → Apple Worldwide Developer Relations Certification Authority → Apple Root CA
- Team identifier: `D963M2VVCH`
- Gatekeeper assessment: accepted as a Mac App Store application (with local security override reported by the assessment tool)

## Limits

Static inspection does not establish runtime behavior. It only establishes the inspected artifact identity and signing/architecture metadata. Source/test evidence remains the Phase 0 basis until safe runtime observation is possible.
