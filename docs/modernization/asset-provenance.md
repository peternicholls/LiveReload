# Historical Asset Provenance Inventory

**Task:** T046
**Date:** 2026-07-12

The legacy source contains 73 image/interface assets under `mac/` and `LiveReload/`, including status icons, terminal artwork, preference images, nib/xib interfaces, and historical product branding. This inventory deliberately treats every historical visual asset as unavailable for the modern release path unless provenance is later documented.

| ID | Asset group | Evidence | Classification | Modern release treatment |
|---|---|---|---|---|
| AST-001 | Application icons, status/menu images, templates | `mac/Images/`, legacy app `Resources/` | replace | Create original modern iconography. |
| AST-002 | Terminal, background, project-pane, and preference artwork | `mac/Images/Terminal*`, `mac/Images/Preferences/`, legacy app `Resources/` | excluded | Do not copy; create new UI assets only if needed. |
| AST-003 | Nib/XIB UI layouts | `mac/English.lproj/MainMenu.xib`, legacy resources | excluded | New SwiftUI/AppKit UI is independently authored. |
| AST-004 | Bundled framework assets and licence UI resources | legacy app frameworks/resources | excluded | No legacy framework or resource is included in a modern archive. |
| AST-005 | Source code and text licence notices | `README.md:7-33` | reusable with retention | Retain notices and attribution in `NOTICE.md`. |

No asset is classified `reusable` for visual shipping. This is a conservative provenance decision, not a claim about ownership.
