# Project Lifecycle Copy and State Treatment

| State | Copy | Action | Non-colour treatment |
|---|---|---|---|
| Loading | Restoring projects… | Wait | System progress indicator and spoken loading label; no animation-dependent meaning |
| Empty | No projects are selected; monitoring/reload remain deferred | Add Project | Folder-plus icon and heading |
| Available | Selected folder label and enabled placeholder | Rename, enable/disable, remove | Checkmark-circle icon and spoken “available” |
| Needs repair | Access failed; project/settings are preserved | Repair Access | Tool icon, heading, explanatory text |
| Missing folder | Folder unavailable; project retained | Repair or remove configuration | Question-mark folder icon and text |
| Corrupt store | Configuration safely reset; unreadable file preserved | Dismiss and restore/add | Recovery alert with next action |
| Source recovery required | Configuration could not be read or safely moved; source remains write-protected | Restore storage access and relaunch | Recovery alert; project changes remain disabled by the store |
| Newer configuration | Configuration was created by a newer app and remains unchanged | Open with a compatible version | Recovery alert; project changes remain disabled by the store |
| Project mutation pending | Current project state remains visible while its change is saved | Wait; other projects remain independent | Disabled mutation controls and a spoken progress label |
| Removal | Configuration/bookmark only; folder files remain | Cancel or Remove Configuration | Destructive role and explicit confirmation |

All controls use stable accessibility identifiers, labels that include state text, keyboard traversal, and system semantic colours that adapt to light/dark appearance. Layout uses system text styles and resizable split-view/form containers.
Long folder labels use a safe final component, single-line middle truncation, and a complete VoiceOver label. No custom motion is required, so reduced-motion mode preserves every state and action.
