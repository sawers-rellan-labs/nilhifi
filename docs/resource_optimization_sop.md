# Resource Usage Optimization SOP for Nextflow HPC Pipelines

## Context

This document captures lessons learned from debugging and optimizing the NIL HiFi Assembly Pipeline across 21 commits and ~14 days of iterative development (2026-03-03 to 2026-03-17). It provides a standard operating procedure for an agent to analyze resource usage and optimize CPU/memory allocations during the debug-one-sample-through-the-full-pipeline phase.

---

## 1. Development Timeline and Iteration Count

### Phase 1: Initial pipeline build + first bugs (Mar 3, 5 commits)
- Initial commit with all modules, README, agent docs
- Immediate fixes: dotplot filename collision, LSF wrapper script, non-interactive shell issues, LSF config (`span[hosts=1]` duplication, `perJobMemLimit`)
- **No sample ran end-to-end.** Pipeline was wired but untested on the cluster.

### Phase 2: First sample debug run — TMEX (Mar 6–11, 3 commits)
- `perJobMemLimit` fix (LSF was dividing memory by CPU count)
- RAGTAG_SCAFFOLD OOM: estimated 15 GB, actual 104–110 GB → bumped 32 GB → 128 GB
- RAGTAG_MERGE failure: Nextflow staged two identically-named `ragtag.scaffold.agp` files → collision. Fixed with subdirectory staging.
- `outdir` still pointed to old project path → results published to wrong directory
- **Cache invalidation:** fixing `main.nf` changed the script hash for ALL tasks, forcing HIFIASM to re-run (~4.3h wasted)
- **TMEX got through RAGTAG_MERGE** but required 3 pipeline submissions (2 kills + restarts).

### Phase 3: TMEX full completion + new modules (Mar 15, 8 commits)
- Added ORIENT_MERGED_SCAFFOLDS module (new requirement discovered during analysis)
- Enabled AnchorWave (`run_anchorwave = true`), discovered ANCHORWAVE_B73 used 83 GB against 64 GB allocation → bumped to 128 GB
- Fixed chr4 zoom dynamic bounds in dotplot R script
- TMEX completed full pipeline end-to-end for the first time
- Collected actual resource measurements for all processes

### Phase 4: 4-genome production run (Mar 15–16, 3 commits)
- Per-sample ref2 support (mexicana, parviglumis instead of PT-for-all)
- 4-genome samplesheet
- Production run submitted; currently in RAGTAG phase

### Summary: 7 pipeline submissions to get 1 sample (TMEX) through all steps

| Submission | Outcome | Root cause |
|------------|---------|------------|
| 1 (Mar 3) | LSF config errors | `span[hosts=1]` duplication, memory division |
| 2 (Mar 6) | perJobMemLimit fix applied | Config-only change |
| 3 (Mar 11) | RAGTAG_SCAFFOLD OOM killed | 32 GB alloc, 110 GB actual |
| 4 (Mar 11) | RAGTAG_MERGE filename collision | Nextflow staging conflict |
| 5 (Mar 11) | Cache invalidated, HIFIASM re-ran | Code change to main.nf |
| 6 (Mar 15) | TMEX complete through dotplots | First success |
| 7 (Mar 15) | TMEX complete including AnchorWave | Full pipeline validated |

---

## 2. Resource Estimation vs Actuals

### Initial estimates (from MI21 bash pipeline, pre-Nextflow)

| Process | Est. Memory | Actual Memory (TMEX) | Est. CPUs | Issue |
|---------|-------------|----------------------|-----------|-------|
| HIFIASM | 33 GB (correct) | 33–48 GB | 16 | Accurate — genome-bound |
| RAGTAG_SCAFFOLD | **15 GB** | **104–110 GB** | 8 | **7x underestimate** — MI21 bash script ran ragtag+merge in one job; minimap2 index size was masked |
| RAGTAG_MERGE | ~8 GB | 16 GB | 4 | 2x underestimate |
| LIFTOFF | ~12 GB | 19 GB | 8 | Reasonable |
| ANCHORWAVE_B73 | ~30 GB | **83 GB** | 8 | **2.7x underestimate** — proali DP matrix scales with genome size |
| ANCHORWAVE_REF2 | ~30 GB | TBD (est. 100+ GB) | 8 | Same issue expected |
| DOTPLOT_MAP | ~8 GB | 16–17 GB | 8 | 2x underestimate |

### 4-Genome production run actuals (March 17, 2026)

Complete resource measurements from the 4-genome run. ANCHORWAVE jobs are still PEND at time of writing; TMEX RAGTAG_REF2 (mexicana) still running.

#### MERGE_FASTQ (1 CPU, 4 GB allocated)

| Sample | FASTQ size | Max Memory | CPU time | Wall time |
|--------|-----------|------------|----------|-----------|
| BNI_NIL | 13.9 GB | <1 GB | 30s | 91s |
| BDI_NIL | 19.0 GB | <1 GB | 39s | 118s |
| MI21_NIL | 11.8 GB | <1 GB | 26s | 69s |
| TMEX_NIL | 15.8 GB | <1 GB | 35s | 105s |

Pure I/O (cat). Memory negligible. Wall time dominated by disk write.

#### HIFIASM (16 CPUs, 64 GB allocated)

| Sample | FASTQ size | Max Memory | CPU time | Wall time | CPU efficiency |
|--------|-----------|------------|----------|-----------|----------------|
| BNI_NIL | 13.9 GB | 35 GB (55%) | 44.3h | 3.0h | 0.92 |
| BDI_NIL | 19.0 GB | **46 GB (72%)** | 66.5h | 4.7h | 0.88 |
| MI21_NIL | 11.8 GB | 33 GB (52%) | 40.1h | 2.7h | 0.93 |
| TMEX_NIL | 15.8 GB | 44 GB (69%) | 60.0h | 4.1h | 0.91 |

Highly CPU-bound (efficiency 0.88–0.93). Memory scales with input size: ~2.3 GB per GB of FASTQ input. BDI at 46 GB is the peak — 64 GB allocation provides adequate 28% headroom. No changes needed.

#### GFA_TO_FASTA (1 CPU, 4 GB allocated)

| Sample | Max Memory | Wall time |
|--------|------------|-----------|
| BNI_NIL | <1 GB | 39s |
| BDI_NIL | 1 GB | 12s |
| MI21_NIL | <1 GB | 35s |
| TMEX_NIL | <1 GB | 34s |

Trivial awk + sed processing. No changes needed.

#### RAGTAG_SCAFFOLD (8 CPUs, 128 GB allocated)

| Sample | Reference | Max Memory | CPU time | Wall time | CPU eff. | Notes |
|--------|-----------|------------|----------|-----------|----------|-------|
| BNI_NIL | B73 | 95 GB (74%) | — | 1.1h | — | |
| BNI_NIL | parviglumis | 105 GB (82%) | — | 1.1h | — | |
| BDI_NIL | B73 | **136 GB (106%)** | — | 2.2h | — | **Exceeded allocation** |
| BDI_NIL | parviglumis | **144 GB (113%)** | — | 3.3h | — | **Exceeded allocation** |
| MI21_NIL | B73 | 66 GB (52%) | — | 0.9h | — | |
| MI21_NIL | PT | 70 GB (55%) | — | 0.9h | — | |
| TMEX_NIL | B73 | 111 GB (87%) | 5.6h | 1.3h | 0.54 | |
| TMEX_NIL | mexicana | — | — | running | — | |

Memory-bound (minimap2 `asm5` index). BDI_NIL exceeded 128 GB on both references — its 2510-contig assembly creates a larger alignment problem. Range: 66–144 GB.

**Action needed:** Bump to **192 GB** for safety. BDI at 144 GB leaves no margin at 128 GB. Even with purge_dups reducing contig count, other fragmented assemblies could hit similar levels.

#### RAGTAG_MERGE (4 CPUs, 16 GB allocated)

| Sample | Max Memory | Wall time |
|--------|------------|-----------|
| BNI_NIL | <1 GB | 33s |
| BDI_NIL | <1 GB | 45s |
| MI21_NIL | <1 GB | 64s |

Pure text processing. Memory negligible. 4 CPUs wasted — could be 1.

#### ORIENT_MERGED_SCAFFOLDS (8 CPUs, 32 GB allocated)

| Sample | Max Memory | CPU time | Wall time | CPU eff. |
|--------|------------|----------|-----------|----------|
| BNI_NIL | 25 GB (78%) | 18.3m | 4.0m | 0.57 |
| BDI_NIL | 16 GB (50%) | 17.5m | 3.9m | 0.56 |
| MI21_NIL | 12 GB (38%) | 19.2m | 4.0m | 0.60 |

Moderate CPU efficiency. minimap2 splice mapping of ~50 MB CDS uses 8 threads effectively for the alignment phase but index is small. Memory varies with assembly size (BNI 25 GB peak). 32 GB allocation adequate.

#### DOTPLOT_MAP (8 CPUs, 32 GB allocated)

| Sample | Reference | Max Memory | CPU time | Wall time | CPU eff. |
|--------|-----------|------------|----------|-----------|----------|
| BNI_NIL | B73 | 11 GB (34%) | 15.9m | 4.0m | 0.50 |
| BNI_NIL | parviglumis | 11 GB (34%) | 21.1m | 3.8m | 0.70 |
| BDI_NIL | B73 | 11 GB (34%) | 16.5m | 3.8m | 0.54 |
| BDI_NIL | parviglumis | 13 GB (41%) | 22.6m | 4.7m | 0.60 |
| MI21_NIL | B73 | 11 GB (34%) | 19.0m | 3.9m | 0.61 |
| MI21_NIL | PT | 11 GB (34%) | 30.7m | 5.1m | 0.75 |

Consistent 11–13 GB peak across all samples/references. 32 GB allocation has 59–66% headroom — could reduce to **16 GB**. CPU efficiency moderate (0.50–0.75); 8 CPUs reasonable for the minimap2 alignment phase.

#### DOTPLOT_PLOT (1 CPU, 8 GB allocated)

| Sample | Max Memory | CPU time | Wall time |
|--------|------------|----------|-----------|
| BNI_NIL | <1 GB | 25s | 63s |
| BDI_NIL | <1 GB | 25s | 41s |
| MI21_NIL | <1 GB | 28s | 48s |

Single-threaded R. Memory negligible. Could reduce to 2 GB.

#### LIFTOFF (8 CPUs, 32 GB allocated)

| Sample | Max Memory | CPU time | Wall time | CPU eff. |
|--------|------------|----------|-----------|----------|
| BNI_NIL | 20 GB (63%) | 2.2h | 26.8m | 0.61 |
| BDI_NIL | 20 GB (63%) | 2.0h | 24.9m | 0.60 |
| MI21_NIL | 18 GB (56%) | 2.2h | 26.6m | 0.62 |

Consistent 18–20 GB peak. CPU efficiency ~0.60 — moderate benefit from 8 threads. 32 GB provides adequate 37–44% headroom.

#### ANCHORWAVE (8 CPUs, 128 GB allocated)

All 6 ANCHORWAVE jobs (BNI, BDI, MI21 × B73, REF2) are still **PEND** at time of writing. Previous TMEX single-sample run baseline:

| Sample | Reference | Max Memory | Wall time | Notes |
|--------|-----------|------------|-----------|-------|
| TMEX_NIL | B73 | 83 GB | ~67m | From Phase 3 run |
| TMEX_NIL | PT | — | ~5h (est.) | Not measured — long pole |

ANCHORWAVE_REF2 is expected to be the longest-running process in the pipeline (~5h per sample). Update this section after the current jobs complete.

### Why estimates were wrong

1. **Bash scripts bundled multiple steps** — ragtag scaffold+merge ran in one LSF job, so the peak memory of the most expensive sub-step (minimap2 indexing during scaffold) was never isolated.
2. **Different minimap2 preset** — ragtag uses `asm5` (whole-genome alignment with large index), not `splice` (CDS mapping). The `asm5` index of a 2.2 Gb maize genome is ~100 GB.
3. **proali memory scales non-linearly** — AnchorWave's whole-genome DP is O(n) in memory with genome size, and the constant factor is large for maize.

---

## 3. Tool Computational Profiles

Understanding whether a bioinformatics tool is CPU-bound, memory-bound, or I/O-bound determines whether extra CPUs help or waste slots.

### CPU-bound (scales with thread count)

| Tool | Used by | Why | Evidence |
|------|---------|-----|----------|
| **hifiasm** | HIFIASM | Read overlap detection + graph construction. CPU time = 47h vs wall time = 3.4h at 16 threads → 13.9x parallelism efficiency. | Linear speedup observed from 9x to 14x coverage |
| **anchorwave proali** | ANCHORWAVE | Whole-genome dynamic programming. Partitions DP matrix across threads. | 5h wall time at 8 threads; high CPU utilization throughout |
| **liftoff** (internal minimap2) | LIFTOFF | Gene model mapping. minimap2 alignment phase parallelizes well. | 37min at 8 threads, moderate CPU efficiency |

### Memory-bound (extra CPUs mostly idle)

| Tool | Used by | Why | Evidence |
|------|---------|-----|----------|
| **minimap2 asm5** (via ragtag) | RAGTAG_SCAFFOLD | Reference index construction is single-threaded and allocates ~100 GB for a 2.2 Gb genome. Alignment phase uses threads but is short relative to indexing. | 104–110 GB peak; most time spent in index loading |

### I/O-bound (trivial compute)

| Tool | Used by | Why | Evidence |
|------|---------|-----|----------|
| **minimap2 splice** (CDS only) | ORIENT, DOTPLOT_MAP | Maps ~50 MB of CDS sequences — tiny input. Index is small. Runtime dominated by disk read/write. | 4–15 min total at 8 CPUs |
| **ragtag merge** | RAGTAG_MERGE | AGP coordinate manipulation. Pure text processing. | 36 seconds |
| **anchorwave gff2seq** | ORIENT, DOTPLOT_MAP, ANCHORWAVE | Extracts CDS from FASTA by GFF coordinates. Sequential file scan. | Seconds |
| **cat** | MERGE_FASTQ | File concatenation. | 38 seconds |
| **R plotting** | DOTPLOT_PLOT | Single-threaded R script generating PDFs. | 54 seconds |

---

## 4. Optimization Recommendations

### CPU and memory reallocation table (updated with 4-genome actuals)

| Process | Current CPUs | Current Memory | Rec. CPUs | Rec. Memory | Rationale |
|---------|-------------|---------------|-----------|-------------|-----------|
| MERGE_FASTQ | 1 | 4 GB | **1** | **4 GB** | I/O-only (cat). No change needed. |
| HIFIASM | 16 | 64 GB | **16** | **64 GB** | CPU-bound (eff 0.88–0.93). Peak 46 GB. Keep. |
| GFA_TO_FASTA | 1 | 4 GB | **1** | **4 GB** | Trivial. No change. |
| RAGTAG_SCAFFOLD | 8 | 128 GB | **4** | **192 GB** | Memory-bound. BDI exceeded 128 GB (144 GB peak). Reduce CPUs (index is single-threaded), bump memory for fragmented assemblies. |
| RAGTAG_MERGE | 4 | 16 GB | **1** | **4 GB** | Pure text, <1 GB actual, <1 min. |
| ORIENT | 8 | 32 GB | **8** | **32 GB** | CPU eff 0.57. Peak 25 GB. Acceptable. |
| LIFTOFF | 8 | 32 GB | **8** | **32 GB** | CPU eff 0.60. Peak 20 GB. Keep. |
| DOTPLOT_MAP | 8 | 32 GB | **8** | **16 GB** | CPU eff 0.50–0.75. Peak 11–13 GB consistently. Halve memory. |
| DOTPLOT_PLOT | 1 | 8 GB | **1** | **2 GB** | <1 GB actual. Single-threaded R. |
| ANCHORWAVE | 8 | 128 GB | **8** | **128 GB** | B73 at 83 GB. REF2 TBD. Keep until measured. |

### Key change: RAGTAG_SCAFFOLD memory bump (128 → 192 GB)

BDI_NIL RAGTAG exceeded 128 GB on both references (136 GB vs B73, 144 GB vs parviglumis). The job survived because LSF didn't enforce the hard limit, but this is unreliable — under node memory pressure, the job would be OOM-killed. The high memory correlates with BDI's 2510-contig assembly (vs 740–1290 for other samples). Even after purge_dups, future assemblies with similar fragmentation could hit this. 192 GB provides 33% headroom above the observed 144 GB peak.

### Impact on parallelism (sara queue, 32 total slots)

Assuming ntanduk's jobs (9 slots) have finished, 31 slots available (1 for orchestrator):

| Scenario | Current allocation | Optimized allocation |
|----------|-------------------|---------------------|
| RAGTAG phase (8 jobs) | 2 concurrent × 8 CPUs = 16 slots | **7 concurrent × 4 CPUs = 28 slots** |
| ORIENT/LIFTOFF/DOTPLOT_MAP | 3 concurrent × 8 CPUs = 24 slots | 3 concurrent × 8 CPUs = 24 slots |
| RAGTAG_MERGE | 7 concurrent × 4 CPUs = 28 slots | **31 concurrent × 1 CPU** (all fit) |
| ANCHORWAVE | 3 concurrent × 8 CPUs = 24 slots | 3 concurrent × 8 CPUs = 24 slots |

The main win is RAGTAG: going from 2-wide to 7-wide at 4 CPUs per job, since the process is memory-bound and the extra 4 CPUs per job were mostly idle.

### Estimated time savings on 4-sample run (revised)

| Phase | Current duration | Optimized duration | Savings |
|-------|-----------------|-------------------|---------|
| RAGTAG (8 jobs) | ~7.3h (2-wide × ~1.8h × 4 batches) | **~2.6h** (7-wide × ~2.2h × 2 batches) | **~4.7h** |
| RAGTAG_MERGE (4 jobs) | ~0.1h (2-wide) | instant (all fit) | ~0.1h |
| ORIENT + DOTPLOT | ~1h | ~1h (unchanged) | 0 |
| LIFTOFF | ~1.5h | ~1.5h (unchanged) | 0 |
| ANCHORWAVE | ~13h (TBD) | ~13h (TBD) | 0 |
| **Total pipeline** | **~38.5h** | **~33.5h** | **~5h** |

Note: RAGTAG wall time may increase slightly at 4 CPUs vs 8 (the minimap2 alignment phase uses threads), but the 3.5x increase in concurrency more than compensates. ANCHORWAVE savings will be assessed after current jobs complete.

---

## 5. SOP: Resource Optimization During Debug Iterations

### When to optimize

Do NOT optimize during initial pipeline wiring. Focus on getting the pipeline to run end-to-end first with generous allocations. Optimize after the first successful sample completes all steps.

### Step-by-step procedure

#### Step 1: Collect actuals after first successful run

For each completed task, read the LSF resource summary:

```bash
# Find task work directories from orchestrator log
grep "Submitted process" results/log/nil_pipeline_<JOBID>.out

# For each task hash, read the resource summary
cat results/work/<hash>/.command.log | grep -A 20 "Resource usage summary"

# Key fields to extract:
#   Max Memory: actual peak RSS
#   CPU time: total CPU seconds consumed
#   Run time: wall clock seconds
```

Compute **CPU efficiency** = CPU_time / (wall_time × num_cores). Values below 0.3 indicate the process is not CPU-bound and cores are being wasted.

#### Step 2: Classify each process

For each process, determine the bottleneck type:

| CPU efficiency | Peak memory vs allocation | Classification |
|---------------|--------------------------|----------------|
| > 0.5 | < 50% of allocation | **CPU-bound** — add more cores |
| < 0.3 | > 70% of allocation | **Memory-bound** — reduce cores, keep memory |
| < 0.3 | < 30% of allocation | **I/O-bound** — reduce both cores and memory |
| > 0.5 | > 70% of allocation | **CPU + memory bound** — keep both high |

Also consider the tool's known computational profile (see Section 3) — some tools have single-threaded bottleneck phases that won't show in aggregate CPU efficiency.

#### Step 3: Check queue slot math

```bash
# Queue limits
bqueues -l <queue_name> | grep -E "NJOBS|PJOBS|MAX"

# Current usage
bjobs -u all -q <queue_name> -w | awk '{print $2}' | sort | uniq -c
```

Calculate: `available_slots = queue_max - other_users_slots - orchestrator_slots`

Then for each candidate CPU allocation, check how many jobs fit:
`concurrent_jobs = floor(available_slots / cpus_per_job)`

The goal is to maximize `concurrent_jobs × jobs_per_second`, not just `concurrent_jobs`.

#### Step 4: Model the phase timeline

Map out the pipeline phases and calculate duration under current vs optimized allocations:

```
phase_duration = ceil(num_jobs / concurrent_jobs) × wall_time_per_job
```

For CPU-bound tools, reducing cores increases wall_time_per_job. The optimization is only worthwhile if:
```
ceil(N / new_concurrent) × new_wall_time < ceil(N / old_concurrent) × old_wall_time
```

#### Step 5: Apply changes and validate

1. Edit the `.nf` module files (cpus, memory directives)
2. Run one sample with `-resume` — only affected processes re-execute
3. Compare new actuals against predictions
4. If a process was too aggressive (OOM or excessive slowdown), revert that specific change

**Important:** Changing `cpus` in a module changes the Nextflow task hash, which invalidates the cache for that process. Batch all CPU changes together to minimize cache invalidation across resumes.

---

## 6. Common Pitfalls

1. **Bash pipeline memory was misleading.** When multiple tools run in one bash script, LSF reports the peak of the entire job. Splitting into Nextflow processes reveals per-tool memory that may be much higher than expected (ragtag scaffold: 15 GB estimated → 110 GB actual).

2. **minimap2 presets have wildly different memory profiles.** `splice` (CDS mapping) uses ~1 GB index. `asm5` (whole-genome) uses ~100 GB for maize. Same tool, 100x difference.

3. **Nextflow cache invalidation is aggressive.** Any change to `main.nf` channel wiring invalidates ALL downstream task hashes, even if the process script is unchanged. Edit module `.nf` files directly when possible. See git commit `02e1418` where a ragtag_merge fix caused HIFIASM to re-run (4.3h wasted).

4. **Memory overruns may not kill jobs immediately.** LSF on some clusters (like this one) doesn't enforce hard memory limits strictly. A job using 83 GB against a 64 GB allocation may survive — until the node is under memory pressure from other jobs, then it gets OOM-killed unpredictably. In the 4-genome run, BDI_NIL RAGTAG used 136–144 GB against 128 GB and completed successfully, but this is fragile. Overruns may also cause subtle data corruption (e.g., incomplete scaffolding results) without any error — the BDI_NIL chr4 merge failure may be partly attributable to memory pressure during ragtag merge graph construction.

5. **Slot math matters more than per-job speed.** Halving a process's cores might make it 30% slower, but doubling the number that run concurrently gives a net 40% improvement in phase duration. Always do the math.

6. **Assembly fragmentation drives resource variance across samples.** In the 4-genome run, BDI_NIL (2510 contigs) used 2–3x more memory and wall time for RAGTAG than MI21_NIL (740 contigs). Resource estimates from one sample don't transfer to another if assembly quality differs significantly. Allocate based on the worst-case sample, not the average. The contig count from HIFIASM (`grep -c "^S" *.p_ctg.gfa`) is a leading indicator — check it before RAGTAG runs and consider bumping memory for samples with >1500 contigs.

---

## 7. Agent Prompt: Resource Optimization During Pipeline Debugging

Use the following prompt/procedure when an agent is iterating on a Nextflow pipeline to get a sample running end-to-end. This should be invoked after the first successful full-pipeline completion of one sample.

---

### Prompt

```
You are optimizing resource allocations for a Nextflow pipeline running on an
LSF HPC cluster. A single sample has just completed all pipeline steps
successfully. Your goal is to analyze actual resource usage and recommend
CPU/memory changes that maximize throughput for the upcoming multi-sample
production run.

PROCEDURE:

1. COLLECT ACTUALS
   - Read the orchestrator log to find all task hashes:
     grep "Completed process" results/log/nil_pipeline_<JOBID>.out
   - For each task, read results/work/<hash>/.command.log and extract:
     - Max Memory (from LSF "Resource usage summary")
     - CPU time and Run time (to compute CPU efficiency)
     - Exit status
   - Also read results/work/<hash>/.command.trace for Nextflow's own
     peak_rss and peak_vmem measurements (in KB).
   - Record these in a table: process name, allocated CPUs, allocated
     memory, actual peak memory, wall time, CPU time, CPU efficiency.

2. CLASSIFY EACH PROCESS
   - CPU efficiency = CPU_time / (wall_time * num_cores)
   - Memory pressure = actual_peak / allocated_memory
   - Use these plus knowledge of the bioinformatics tool to classify as:
     CPU-bound, memory-bound, I/O-bound, or CPU+memory-bound.
   - For tools using minimap2: check which preset is used (-x splice,
     -x asm5, -x map-hifi, etc.) as this determines index memory.

3. CHECK QUEUE CONSTRAINTS
   - Run: bqueues -l <queue> to get slot limits
   - Run: bjobs -u all -q <queue> -w to get current occupancy
   - Calculate available slots for child jobs

4. MODEL OPTIMIZATION
   - For each process, propose new CPU count based on classification:
     - CPU-bound: keep or increase CPUs
     - Memory-bound: reduce CPUs to minimum needed (often 4 for minimap2
       alignment, 1-2 for pure I/O)
     - I/O-bound: reduce to 1-2 CPUs
   - For memory: set to 1.3x actual peak (safety margin)
   - Calculate concurrent jobs under old vs new allocations
   - Estimate phase durations: ceil(num_jobs / concurrent) * wall_time
   - Only recommend changes where the net phase duration decreases

5. OUTPUT
   - Table of current vs recommended allocations with rationale
   - Phase-by-phase timeline comparison (current vs optimized)
   - Total estimated time savings
   - List of specific .nf files and lines to change
   - Warning about cache invalidation: note which changes will cause
     task re-execution on -resume

IMPORTANT NOTES:
- Do NOT optimize during initial debugging. Wait until one sample runs
  through completely.
- Memory estimates from bash scripts that bundle multiple tools are
  unreliable. Trust only per-process Nextflow measurements.
- Changing cpus in a .nf module invalidates the Nextflow cache for that
  process. Batch changes together.
- Check minimap2 preset before assuming memory is transferable between
  processes that both use minimap2.
- Factor in other users' queue usage — check bjobs -u all, not just
  your own jobs.
```

---

*Generated: 2026-03-17. Updated: 2026-03-17 with 4-genome production run actuals (BNI, BDI, MI21, TMEX partial). ANCHORWAVE actuals pending. Based on NIL HiFi Assembly Pipeline development history (21 commits, 7 pipeline submissions, 14 days).*
