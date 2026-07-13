# Monitoring and Reload UI States

| State | User-visible meaning | Safe action | Required identifier/test |
|---|---|---|---|
| Stopped | This project is not observing files | Start monitoring | `monitoring.stopped` |
| Starting | LiveReload is preparing access and observation | Wait or stop | `monitoring.starting` |
| Watching | Supported changes can trigger a reload | Stop monitoring or manual reload | `monitoring.watching` |
| Recovering | Folder/root/event state needs recovery; configuration is preserved | Repair access or retry after restoring the folder | `monitoring.recovering` |
| Failed | Monitoring could not start safely | Read safe reason, repair, or retry | `monitoring.failed` |
| Local server starting | Browser endpoint is preparing | Wait | `server.starting` |
| Local server ready | Compatible browsers may connect locally | Inspect connection count | `server.listening` |
| Port conflict | The local endpoint is in use; projects remain monitored | Retry after resolving the local conflict | `server.port-conflict` |
| No clients | Monitoring is active but no browser is ready | Connect a compatible browser | `server.no-clients` |
| Client connected | One or more compatible browsers are ready | Use manual reload or save a file | `server.clients` |

Every state uses text plus an icon, is keyboard operable, and uses a safe activity summary. The UI never claims `Watching` after folder, stream, or recovery failure.
