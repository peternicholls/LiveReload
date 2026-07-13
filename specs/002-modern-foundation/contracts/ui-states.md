# Project Lifecycle UI-State Contract

| State | Required user-visible content | Required action |
|---|---|---|
| Loading | Project configuration is being restored without blocking the main actor | Wait; no destructive action |
| Empty | What LiveReload will manage and that no project is selected | Add project |
| Available | Display name, enabled state, safe folder label | Rename, enable/disable, remove |
| Needs repair | What access failed, what configuration is preserved, safe next step | Repair access |
| Missing folder | Folder is unavailable; project is retained | Repair access or remove configuration |
| Corrupt configuration recovery | Safe configuration reset and diagnostic preservation notice | Dismiss and add/restore projects |
| Configuration source recovery | Source could not be read or safely preserved; no project changes are written | Restore storage access and relaunch |
| Newer configuration | Newer schema remains unchanged and write-protected | Open with a compatible version |
| Project mutation pending | Existing project state remains visible; controls for that project are disabled without blocking other project IDs | Wait for the current mutation to finish |
| Removal confirmation | Configuration-only removal and explicit statement that files remain | Cancel or remove project |

All interactive controls require accessibility labels, stable UI-test identifiers, logical VoiceOver order, keyboard operation, reduced-motion compatibility, long/path-overflow handling, and appearance-independent state communication. Errors must identify what was preserved and the next safe action.
