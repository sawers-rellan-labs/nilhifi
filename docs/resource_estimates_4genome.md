# 4-Genome Production Run — ETA & Resource Analysis

**Original submission:** 19:28 EDT, Monday March 16, 2026
**Orchestrator job:** 467654 (sara queue)
**Samples:** TMEX_NIL, MI21_NIL, BNI_NIL, BDI_NIL

---

## 1. HPC Resource Snapshot

| Resource | At submission (Mar 16) | Current (Mar 17 ~19:00) |
|----------|----------------------|------------------------|
| sara queue MAX slots | 32 | 32 |
| ntanduk jobs | 9 slots (since Mar 11) | likely finished (not visible in bjobs) |
| Orchestrator | 1 slot | 1 slot |
| **Available for child jobs** | **22 slots** | **~31 slots** |

### Effective parallelism by process type

| Process cores | At 22 slots | At 31 slots |
|---------------|------------|------------|
| 16 (HIFIASM) | 1 concurrent | 1 concurrent |
| 8 (RAGTAG, ORIENT, LIFTOFF, DOTPLOT_MAP, ANCHORWAVE) | 2 concurrent | **3 concurrent** |
| 4 (RAGTAG_MERGE) | 5 | 7 |
| 1 (MERGE_FASTQ, GFA_TO_FASTA, DOTPLOT_PLOT) | 22 | 31 |

---

## 2. Per-Process Resource Requirements — Actuals from 4-Genome Run

Updated with measured values. Replaces initial estimates.

| Process | CPUs | Mem (alloc) | Mem (actual range) | Runtime (range) | CPU eff. | Notes |
|---------|------|-------------|-------------------|-----------------|----------|-------|
| MERGE_FASTQ | 1 | 4 GB | <1 GB | 69–118s | — | I/O only (cat) |
| HIFIASM | 16 | 64 GB | 33–46 GB | 2.7–4.7h | 0.88–0.93 | Scales with FASTQ size |
| GFA_TO_FASTA | 1 | 4 GB | <1 GB | 12–39s | — | Trivial |
| RAGTAG_SCAFFOLD (×2) | 8 | **192 GB** | 66–144 GB | 0.9–3.3h | ~0.54 | BDI exceeded 128 GB; bumped |
| RAGTAG_MERGE | 4 | 16 GB | <1 GB | 33–64s | — | BDI now skips merge |
| ORIENT | 8 | 32 GB | 12–25 GB | ~4 min | 0.57–0.60 | |
| LIFTOFF | 8 | 32 GB | 18–20 GB | 25–27 min | 0.60–0.62 | |
| DOTPLOT_MAP (×2) | 8 | 32 GB | 11–13 GB | 4–5 min | 0.50–0.75 | |
| DOTPLOT_PLOT | 1 | 8 GB | <1 GB | 41–63s | — | Single-threaded R |
| ANCHORWAVE_B73 | 8 | 128 GB | 83 GB (TMEX) | ~67 min | — | Others pending |
| ANCHORWAVE_REF2 | 8 | 128 GB | TBD | ~5h (est.) | — | Long pole |

---

## 3. HIFIASM Actuals (all faster than estimated)

| Sample | FASTQ size | Est. time | Actual time | Max Memory |
|--------|-----------|-----------|-------------|------------|
| BNI_NIL | 13.9 GB | 4.0h | **3.0h** | 35 GB |
| BDI_NIL | 19.0 GB | 5.5h | **4.7h** | 46 GB |
| MI21_NIL | 11.8 GB | 3.4h | **2.7h** | 33 GB |
| TMEX_NIL | 15.8 GB | 4.3h | **4.1h** | 44 GB |
| **Total (serialized)** | | **17.2h** | **14.5h** | |

---

## 4. Current Run Status (~19:00 EDT Mon Mar 17)

### Completed phases

| Phase | Actual completion | Notes |
|-------|------------------|-------|
| MERGE_FASTQ (4 samples) | Mon 19:30 | Instant |
| HIFIASM (4 samples, serialized) | Tue 10:16 | 14.5h total, ~2.7h ahead of estimate |
| RAGTAG_SCAFFOLD (8 jobs) | Tue ~17:00 | BDI took longest (3.3h, exceeded 128 GB) |
| RAGTAG_MERGE (4 samples) | Tue ~17:00 | <1 min each |
| ORIENT (4 samples) | Tue ~17:00 | ~4 min each |
| DOTPLOT (4 samples) | Tue ~17:00 | Completed with wrong labels (old code) |
| LIFTOFF (BNI, BDI, MI21) | Tue ~17:00 | TMEX LIFTOFF currently running |

### Currently running (~19:00 EDT Tue)

| Job | Sample | Started | Est. completion |
|-----|--------|---------|-----------------|
| LIFTOFF | TMEX_NIL | ~18:59 | ~19:25 |
| ANCHORWAVE_REF2 | BNI_NIL (parviglumis) | ~17:00 | ~22:00 |

### Pending (FIFO order)

| Job | Sample | Cores |
|-----|--------|-------|
| ANCHORWAVE_B73 | BDI_NIL | 8 |
| ANCHORWAVE_REF2 | BDI_NIL (parviglumis) | 8 |
| ANCHORWAVE_B73 | MI21_NIL | 8 |
| ANCHORWAVE_REF2 | MI21_NIL (PT) | 8 |
| ANCHORWAVE_REF2 | TMEX_NIL (mexicana) | 8 |
| ANCHORWAVE_B73 | TMEX_NIL | 8 |

### Estimated completion of current run

With ~31 available slots (ntanduk appears to have finished), 3 ANCHORWAVE jobs
can run concurrently (3 × 8 = 24 slots).

| Batch | Jobs | Duration | Clock |
|-------|------|----------|-------|
| BNI_REF2 finishing + TMEX LIFTOFF | 2 running | ~3h (BNI_REF2) | Tue ~22:00 |
| BDI_B73 + MI21_B73 + TMEX_B73 | 3 × ~67 min | ~67 min | Tue ~23:00 |
| BDI_REF2 + MI21_REF2 + TMEX_REF2 | 3 × ~5h | ~5h | **Wed ~04:00** |

**Current run complete: ~Wed 04:00 EDT** (if 3-wide ANCHORWAVE)

**Note:** These ANCHORWAVE results use the OLD orient output (BDI chr4
misassigned, all dotplots mislabeled). They will be re-run by the fix rerun.

---

## 5. Fix Rerun — ETA after Current Run

Two `orient_fix_rerun` jobs (479302, 479381) are queued with
`-w "done(467654)"`. They will start after the current orchestrator finishes.

**Note:** One of these is a duplicate submission — only one will run the
pipeline, the other will find nothing to do (or should be killed: `bkill 479381`).

### What the rerun re-executes

The rerun picks up three code changes:
1. `orient_scaffolds.py` — per-chromosome best-scaffold (fixes BDI chr4)
2. `ragtag_merge.nf` — skip merge for BDI (fixes BDI chr9)
3. `plot_dotplot.R` + `dotplot_plot.nf` — correct ref2 labels

| Process | Samples affected | Cached? | Est. duration |
|---------|-----------------|---------|---------------|
| HIFIASM | all | **cached** | 0 |
| GFA_TO_FASTA | all | **cached** | 0 |
| RAGTAG_SCAFFOLD | all | **cached** | 0 |
| RAGTAG_MERGE | all 4 | **re-runs** (script changed) | 4 × 45s = ~3 min |
| ORIENT | all 4 | **re-runs** (script changed) | 4 × 4 min = ~16 min |
| DOTPLOT_MAP | all 8 | **re-runs** (orient output changed) | 8 × 5 min = ~40 min |
| DOTPLOT_PLOT | all 4 | **re-runs** (script + inputs changed) | 4 × 1 min = ~4 min |
| LIFTOFF | all 4 | **re-runs** (orient output changed) | 4 × 27 min = ~2h (2-wide) |
| ANCHORWAVE_B73 | all 4 | **re-runs** (orient output changed) | 4 × 67 min = ~2.2h (2-wide) |
| ANCHORWAVE_REF2 | all 4 | **re-runs** (orient output changed) | 4 × ~5h = **~10h** (2-wide) or **~7h** (3-wide) |

### Rerun timeline (assuming 3-wide at 31 slots)

| Phase | Duration | Clock (from rerun start) |
|-------|----------|--------------------------|
| MERGE + ORIENT + DOTPLOT_MAP + DOTPLOT_PLOT | ~1h | +1h |
| LIFTOFF (4 samples, 2-wide) | ~1h | +2h |
| ANCHORWAVE_B73 (4 samples, 3-wide) | ~1.5h | +3.5h |
| ANCHORWAVE_REF2 (4 samples, 3-wide) | ~5h | +8.5h |
| **Total rerun** | | **~8.5h** |

If ntanduk's slots are still free (3-wide ANCHORWAVE).
If ntanduk returns (2-wide): ~12h instead.

### Combined timeline

| Milestone | ETA |
|-----------|-----|
| Current run complete | **Wed ~04:00** |
| Rerun starts (orient_fix_rerun triggers) | Wed ~04:00 |
| Rerun: dotplots ready (with correct labels + BDI chr4 fixed) | Wed ~05:00 |
| Rerun: liftoff complete | Wed ~06:00 |
| **Rerun complete (all ANCHORWAVE)** | **Wed ~12:30** |

### What to verify after rerun

1. BDI chr4: `scaffold_correspondence.tsv` should show 1000+ anchors, FLIPPED
2. BDI chr9: should be ~186 MB (B73-only scaffold) vs 47 MB (old merge)
3. Dotplot labels: parviglumis/mexicana/PT (not "PT" for all)
4. TMEX dotplots: first review — check for anomalies

---

## 6. Original vs Actual vs Rerun — Time Comparison

| Phase | Original estimate | Actual (current run) | Rerun (cached HIFIASM/RAGTAG) |
|-------|------------------|---------------------|-------------------------------|
| HIFIASM | 17.2h | 14.5h | cached |
| RAGTAG | 7.3h | ~8h (BDI slow) | cached |
| MERGE + ORIENT + DOTPLOT | 1.5h | ~1h | ~1h |
| LIFTOFF | 1.5h | ~1h | ~1h |
| ANCHORWAVE | 13h | ~10h (est., 3-wide) | ~6.5h (3-wide) |
| **Total** | **38.5h** | **~34h** | **~8.5h** |
| **Cumulative (run + rerun)** | | | **~42.5h** |

The rerun adds ~8.5h on top of the ~34h original run, for a total of ~42.5h
from original submission to final corrected results. The overhead vs getting it
right the first time (~34h) is ~8.5h — the cost of the orient/merge bugs.

---

## 7. Risks (updated)

| Risk | Impact | Status |
|------|--------|--------|
| ~~RAGTAG exceeds 128 GB on BDI~~ | ~~Adds 1.8h per rerun~~ | **Occurred.** 144 GB peak. Bumped to 192 GB. |
| ~~BDI HIFIASM slower than estimated~~ | ~~Adds 1-2h~~ | **OK.** 4.7h actual vs 5.5h est. |
| ~~ntanduk's jobs persist~~ | ~~ETAs +7h~~ | **Resolved.** Jobs no longer visible. |
| ANCHORWAVE_REF2 OOM on parviglumis/mexicana | Re-run adds ~5h per failure | Low — allocated 128 GB |
| BNI chr2/chr8 assembly gaps | No pipeline fix | Known limitation — document |
| Rerun orient_fix_rerun duplicate job | Wastes 1 slot | Kill one: `bkill 479381` |

---

*Original analysis: March 16, 2026, 18:45 EDT.*
*Updated: March 17, 2026, ~19:00 EDT — with 4-genome actuals and fix rerun timeline.*
