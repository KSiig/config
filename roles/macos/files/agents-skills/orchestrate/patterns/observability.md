# Observability

Tracking what happened during orchestration — both per-task and end-of-session.

## Per-task log

After each worker round-trip, log:

```
TASK #N [worker-M]: <what you delegated>
  Brief: inline / tasks/worker-task-N.md
  Result: <1-sentence summary>
  Rework: yes/no — <why>
```

With multiple workers, note which worker handled which task.

## End-of-task retro

After the PR is up, write a retro:

```
## Orchestration Retro

### Stats
- Workers used: N
- Tasks delegated: M
- Rework rate: X/M
- Self-tasks: K
- Parallel slices: P (tasks that ran concurrently)

### Where the pattern helped
- <observations about context sharing, parallel execution, worker autonomy>

### Where it was wasteful
- <observations about over-slicing, signaling friction, unnecessary delegation>

### Opus/Sonnet quota split estimate
- Opus: ~X% (research, planning, review, git ops)
- Sonnet: ~Y% (implementation)

### Verdict
<use again / modify / abandon — and why>
```
