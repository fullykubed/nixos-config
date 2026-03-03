# scripts/

Build attempt tracking scripts for history, deduplication, and retry limits.

- `init-history.sh` — Initialize attempt history for a build session.
- `record-attempt.sh` — Log a build attempt with error output and applied fixes.
- `check-attempt.sh` — Query previous attempts to avoid repeating the same fix.
- `list-attempts.sh` — List all recorded build attempts in chronological order.
- `attempt-count.sh` — Get count of build attempts to determine when to stop retrying.
