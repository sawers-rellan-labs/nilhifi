# 4-Genome Production Run — ETA & Resource Analysis

**Original submission:** 19:28 EDT, Monday March 16, 2026
**Orchestrator job:** 467654 (sara queue) — **DONE** (completed Wed Mar 18 ~12:58)
**Rerun job:** 479302 (orient_fix_rerun) — **RUN** (started Wed Mar 18 ~12:59)
**Samples:** TMEX_NIL, MI21_NIL, BNI_NIL, BDI_NIL

---

## 1. HPC Resource Snapshot

| Resource | At submission (Mar 16) | Current (Mar 18 ~13:00) |
|----------|----------------------|------------------------|
| sara queue MAX slots | 32 | 32 |
| ntanduk jobs | 9 slots (since Mar 11) | finished |
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

All values measured from completed original run (job 467654).

| Process | CPUs | Mem (alloc) | Mem (actual range) | Runtime (range) | CPU eff. | Notes |
|---------|------|-------------|-------------------|-----------------|----------|-------|
| MERGE_FASTQ | 1 | 4 GB | <1 GB | 69–118s | — | I/O only (cat) |
| HIFIASM | 16 | 64 GB | 33–46 GB | 2.7–4.7h | 0.88–0.93 | Scales with FASTQ size |
| GFA_TO_FASTA | 1 | 4 GB | <1 GB | 12–39s | — | Trivial |
| RAGTAG_SCAFFOLD (×2) | 8 | **192 GB** | 66–144 GB | 0.9–3.3h | ~0.54 | BDI exceeded 128 GB; bumped |
| RAGTAG_MERGE | 4 | 16 GB | <1 GB | 33–64s | — | BDI now skips merge |
| ORIENT | 8 | 32 GB | 12–25 GB | ~4 min | 0.57–0.60 | |
| LIFTOFF | 8 | 32 GB | 18–20 GB | 25–34 min | 0.60–0.62 | |
| DOTPLOT_MAP (×2) | 8 | 32 GB | 11–13 GB | 4–5 min | 0.50–0.75 | |
| DOTPLOT_PLOT | 1 | 8 GB | <1 GB | 41–63s | — | Single-threaded R |
| ANCHORWAVE_B73 | 8 | 128 GB | 78–91 GB | 28–81 min | 0.57–0.72 | |
| ANCHORWAVE_REF2 | 8 | 128 GB | 103–111 GB | 5.6–5.9h | 0.72 | Long pole; 128 GB adequate |

---

## 3. HIFIASM Actuals

| Sample | FASTQ size | Est. time | Actual time | Max Memory |
|--------|-----------|-----------|-------------|------------|
| BNI_NIL | 13.9 GB | 4.0h | **3.0h** | 35 GB |
| BDI_NIL | 19.0 GB | 5.5h | **4.7h** | 46 GB |
| MI21_NIL | 11.8 GB | 3.4h | **2.7h** | 33 GB |
| TMEX_NIL | 15.8 GB | 4.3h | **4.1h** | 44 GB |
| **Total (serialized)** | | **17.2h** | **14.5h** | |

---

## 4. ANCHORWAVE Actuals

| Sample | Reference | Max Memory | Wall Time | CPU Time | CPU Eff. |
|--------|-----------|------------|-----------|----------|----------|
| BNI_NIL | B73 | 85 GB (66%) | 49 min | 2.3h | 0.36 |
| BDI_NIL | B73 | 91 GB (71%) | 81 min | 4.9h | 0.48 |
| MI21_NIL | B73 | 78 GB (61%) | 28 min | 1.5h | 0.42 |
| TMEX_NIL | B73 | 83 GB (65%) | 42 min | 2.1h | 0.38 |
| BNI_NIL | parviglumis | 111 GB (87%) | 5.8h | 31.6h | 0.68 |
| BDI_NIL | parviglumis | 109 GB (85%) | 5.9h | 30.9h | 0.65 |
| MI21_NIL | PT | 103 GB (80%) | 5.6h | 30.8h | 0.69 |
| TMEX_NIL | mexicana | 104 GB (81%) | 5.9h | 33.7h | 0.71 |

128 GB allocation is adequate — peak was 111 GB (87%). REF2 jobs are ~5x longer and
~30% more memory than B73 jobs due to divergent reference genomes increasing DP matrix size.

---

## 5. LIFTOFF Actuals

| Sample | Max Memory | Wall Time | CPU Time | CPU Eff. |
|--------|------------|-----------|----------|----------|
| BNI_NIL | 20 GB (63%) | 26.8 min | 2.2h | 0.61 |
| BDI_NIL | 20 GB (63%) | 24.9 min | 2.0h | 0.60 |
| MI21_NIL | 18 GB (56%) | 26.6 min | 2.2h | 0.62 |
| TMEX_NIL | 19 GB (59%) | 33.8 min | 2.4h | 0.56 |

---

## 6. Original Run Timeline (job 467654) — Completed

| Phase | Actual completion | Duration | Notes |
|-------|------------------|----------|-------|
| MERGE_FASTQ (4 samples) | Mon Mar 16 19:30 | ~2 min | Instant |
| HIFIASM (4 samples, serialized) | Tue Mar 17 10:16 | 14.5h | ~2.7h ahead of estimate |
| RAGTAG_SCAFFOLD (8 jobs) | Tue ~17:00 | ~7h | BDI took longest (3.3h, exceeded 128 GB) |
| RAGTAG_MERGE (4 samples) | Tue ~17:00 | <1 min each | |
| ORIENT (4 samples) | Tue ~17:00 | ~4 min each | |
| DOTPLOT (4 samples) | Tue ~17:00 | ~5 min each | Completed with wrong labels (old code) |
| LIFTOFF (4 samples) | Tue ~18:00 | 25–34 min each | |
| ANCHORWAVE_B73 (4 samples) | Tue ~19:30 | 28–81 min each | |
| ANCHORWAVE_REF2 (4 samples) | **Wed Mar 18 12:58** | 5.6–5.9h each | Last task: TMEX_mexicana |
| **Total original run** | | **~41.5h** | |

---

## 7. Rerun Status (job 479302) — In Progress

### What happened

The rerun was submitted with `-w "done(467654)"` and started at Wed Mar 18 12:59.
However, `-resume` picked up the wrong Nextflow cache session (`851ff7ee`, a `-preview`
dry run) instead of the production session (`bb66a028`). This means **all tasks are
re-executing from scratch**, including HIFIASM and RAGTAG which should have been cached.

Root cause: Nextflow's `-resume` defaults to the most recent session. A `-preview
-with-dag` run on Mar 16 20:20 created session `851ff7ee` which was more recent than
the production session `bb66a028`. The fix would have been:
```bash
nextflow run main.nf -profile lsf -resume bb66a028-4dc7-4e81-9a4e-f71610ca69bb
```

### Rerun timeline (full re-execution, ~38h)

| Phase | Jobs | Concurrency | Wall time/job | Phase duration |
|-------|------|-------------|---------------|----------------|
| MERGE_FASTQ | 4 | all fit | ~2 min | ~2 min |
| HIFIASM | 4 | 1-wide (16 CPUs) | 2.7–4.7h | ~14.5h |
| GFA_TO_FASTA | 4 | all fit | ~30s | ~1 min |
| RAGTAG_SCAFFOLD | 8 | 3-wide | 0.9–3.3h | ~7h |
| RAGTAG_MERGE | 3 (+BDI skip) | all fit | ~1 min | ~1 min |
| ORIENT | 4 | 3-wide | ~4 min | ~8 min |
| DOTPLOT_MAP | 8 | 3-wide | ~5 min | ~15 min |
| DOTPLOT_PLOT | 4 | all fit | ~1 min | ~1 min |
| LIFTOFF | 4 | 3-wide | ~34 min | ~68 min |
| ANCHORWAVE_B73 | 4 | 3-wide | ~81 min | ~162 min |
| ANCHORWAVE_REF2 | 4 | 3-wide | ~5.9h | ~11.8h |
| **Total rerun** | | | | **~38h** |

### Rerun milestones

| Milestone | ETA |
|-----------|-----|
| Rerun started | Wed Mar 18 12:59 |
| HIFIASM complete | Thu Mar 19 ~03:30 |
| RAGTAG complete | Thu Mar 19 ~10:30 |
| **Dotplots ready** (with correct labels + BDI fixes) | **Thu Mar 19 ~11:00** |
| LIFTOFF complete | Thu Mar 19 ~12:00 |
| ANCHORWAVE_B73 complete | Thu Mar 19 ~14:30 |
| **Rerun complete (all ANCHORWAVE_REF2)** | **Fri Mar 20 ~03:00** |

---

## 8. Disk Usage

### Current (Wed Mar 18, after cache cleanup)

| Directory | Size | Notes |
|-----------|------|-------|
| `results/work/` | 62 GB | Nextflow intermediates (after cleaning old sessions) |
| `results/BDI_NIL/` | 36 GB | Published outputs |
| `results/BNI_NIL/` | 35 GB | Published outputs |
| `results/TMEX_NIL/` | 35 GB | Published outputs |
| `results/MI21_NIL/` | 33 GB | Published outputs |
| `results/log/` | 36 KB | LSF orchestrator logs |
| `nextflow/` + `docs/` + `agent/` | ~1.5 MB | Code + docs |
| **Total project** | **~201 GB** | |

### Disk usage history

| Timepoint | `results/work/` | Total project | Notes |
|-----------|----------------|---------------|-------|
| Pre-cleanup (Mar 18 13:16) | 401 GB | 538 GB | 6 old Nextflow sessions |
| Post-cleanup (Mar 18 13:17) | 62 GB | ~201 GB | Cleaned all except active session `851ff7ee` |
| Est. rerun complete (Mar 20) | ~450 GB | ~590 GB | Full pipeline re-execution adds ~400 GB |

### Per-sample published output breakdown (estimated)

Each sample's published results include assembly FASTA, scaffold AGP, oriented FASTA,
dotplot PDFs/SVGs, liftoff GFF3, and AnchorWave MAF files. The AnchorWave MAF files
(B73 + REF2) account for ~70% of per-sample disk usage.

### Cleanup procedure

After the rerun completes and results are validated, old sessions can be cleaned:
```bash
cd nextflow && nextflow clean -but astonishing_brown -f
```

To clean ALL sessions after final results are published elsewhere:
```bash
cd nextflow && nextflow clean -f
```
This would reclaim the entire `results/work/` directory (~450 GB projected).

---

## 9. Original vs Actual vs Rerun — Time Comparison

| Phase | Original estimate | Actual (original run) | Rerun (full re-execution) |
|-------|------------------|----------------------|--------------------------|
| HIFIASM | 17.2h | 14.5h | 14.5h (not cached — wrong session) |
| RAGTAG | 7.3h | ~7h | ~7h (not cached) |
| MERGE + ORIENT + DOTPLOT | 1.5h | ~1h | ~0.5h |
| LIFTOFF | 1.5h | ~1h | ~1.1h |
| ANCHORWAVE_B73 | 2.2h | ~2.7h | ~2.7h |
| ANCHORWAVE_REF2 | 10h | ~11.8h | ~11.8h |
| **Total** | **38.5h** | **~41.5h** | **~38h** |
| **Cumulative (run + rerun)** | | | **~79.5h** |

The cache miss due to wrong session selection doubled the total wall time. Had the
rerun correctly resumed from session `bb66a028`, it would have taken ~16h instead of
~38h, for a cumulative total of ~57.5h instead of ~79.5h.

---

## 10. Risks (updated)

| Risk | Impact | Status |
|------|--------|--------|
| ~~RAGTAG exceeds 128 GB on BDI~~ | ~~Adds 1.8h per rerun~~ | **Occurred.** 144 GB peak. Bumped to 192 GB. |
| ~~BDI HIFIASM slower than estimated~~ | ~~Adds 1-2h~~ | **OK.** 4.7h actual vs 5.5h est. |
| ~~ntanduk's jobs persist~~ | ~~ETAs +7h~~ | **Resolved.** Jobs no longer visible. |
| ~~ANCHORWAVE_REF2 OOM~~ | ~~Re-run adds ~5h~~ | **OK.** Peak 111 GB vs 128 GB alloc. |
| ~~Rerun duplicate job~~ | ~~Wastes 1 slot~~ | **Resolved.** Job 479381 EXIT. |
| ~~Rerun cache miss~~ | ~~Adds ~22h~~ | **Occurred.** Wrong session resumed. Full re-execution. |
| BNI chr2/chr8 assembly gaps | No pipeline fix | Known limitation — document |
| Disk usage grows to ~590 GB | May hit quota | Clean old sessions after validation |

---

## 11. What to Verify After Rerun

1. **BDI chr4:** `scaffold_correspondence.tsv` should show 1000+ anchors, FLIPPED
2. **BDI chr9:** should be ~186 MB (B73-only scaffold) vs 47 MB (old merge)
3. **Dotplot labels:** parviglumis/mexicana/PT (not "PT" for all)
4. **TMEX dotplots:** first review — check for anomalies
5. **BNI chr2/chr8:** document assembly gaps as known limitations

---

*Original analysis: March 16, 2026, 18:45 EDT.*
*Updated: March 17, 2026, ~19:00 EDT — with 4-genome actuals and fix rerun timeline.*
*Updated: March 18, 2026, ~13:20 EDT — with complete ANCHORWAVE/LIFTOFF actuals, disk usage, rerun cache miss diagnosis, and revised ETAs.*
