# Agents

| File | Name | Description |
|------|------|-------------|
| [surprise-reviewer.md](./surprise-reviewer.md) | `surprise-reviewer` | Coordinator agent spawned by the Stop hook; reads transcript, deduplicates against existing surprises, and spawns surprise-investigator subagents for each candidate |
| [surprise-investigator.md](./surprise-investigator.md) | `surprise-investigator` | Per-surprise subagent; investigates a candidate discrepancy in depth and writes the surprise file if confirmed |
