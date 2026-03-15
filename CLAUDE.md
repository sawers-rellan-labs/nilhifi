# NIL HiFi Assembly Pipeline

## Suggested scripts rule

When the user asks for bash commands and the result is multiline, **always write the commands to a script file** at `agent/suggested_script_<YYYYMMDD_HHMMSS>.sh` instead of just displaying them. Copy-pasting multiline commands from the Claude Code CLI terminal corrupts spaces and linebreaks. The user can then run `bash agent/suggested_script_<timestamp>.sh`.

Nextflow pipeline for HiFi-based NIL assembly: hifiasm → ragtag scaffold (B73 + PT) → ragtag merge → liftoff → dotplots.

## Where to find logs

### Per-task resource usage (memory, CPU, runtime)

Each Nextflow task has its own work directory under `nextflow/work/<hash>/`:

- **`.command.log`** — LSF job output with **Resource usage summary** (Max Memory, CPU time, etc.). This is the most reliable source for actual memory consumed by each task.
- **`.command.trace`** — Nextflow memory watcher output (peak_rss, peak_vmem in KB, polled periodically). Can report higher values than LSF since it tracks child processes.
- **`.command.err`** — Task stderr (tool-specific logs, e.g., ragtag/minimap2/hifiasm messages).
- **`.command.out`** — Task stdout.
- **`.command.run`** — The LSF batch script Nextflow generated (shows `#BSUB` resource requests).
- **`.command.sh`** — The actual shell commands executed.

### Pipeline-level logs

- **`nextflow/nil_pipeline_<JOBID>.out`** — Orchestrator LSF job output. Shows which tasks ran/cached/failed and the orchestrator's own resource usage (not the individual tasks).
- **`nextflow/nil_pipeline_<JOBID>.err`** — Orchestrator stderr.
- **`nextflow/.nextflow.log`** — Nextflow engine log (detailed scheduling, caching, error info).

### Mapping work dirs to tasks

The pipeline `.out` log shows task hash → process name mappings, e.g.:
```
[d3/19fef5] Submitted process > RAGTAG_SCAFFOLD_B73 (TMEX_inv4m_B73)
```
This means the task's files are in `nextflow/work/d3/19fef56e.../.command.log` etc.
