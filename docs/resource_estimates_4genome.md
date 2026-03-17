# 4-Genome Production Run — ETA & Resource Analysis

**Submitted:** 18:32 EDT, Monday March 16, 2026
**Job ID:** 467191 (orchestrator on sara)
**Samples:** TMEX_NIL, MI21_NIL, BNI_NIL, BDI_NIL

---

## 1. Current HPC Resource Snapshot

| Resource | Value |
|----------|-------|
| sara queue MAX slots | 32 (queue-wide, shared across all users) |
| ntanduk jobs (running since Mar 11) | 2 jobs: 8 cores + 1 core = **9 slots** |
| Orchestrator (nil_pipeline) | **1 slot** |
| **Available for child jobs** | **22 slots** |

### Effective parallelism by process type

| Process cores | Max concurrent jobs | Slots used | Idle slots |
|---------------|---------------------|------------|------------|
| 16 (HIFIASM) | **1** | 16 | 6 |
| 8 (RAGTAG, ORIENT, LIFTOFF, DOTPLOT_MAP, ANCHORWAVE) | **2** | 16 | 6 |
| 4 (RAGTAG_MERGE) | 5 | 20 | 2 |
| 1 (MERGE_FASTQ, GFA_TO_FASTA, DOTPLOT_PLOT) | 22 | 22 | 0 |

**Key constraint:** HIFIASM (16 cores) runs 1 at a time. No 8-core job fits alongside it (16 + 8 = 24 > 22).

---

## 2. Per-Process Resource Requirements & Known Runtimes

Sources: TMEX actual run (handover_full_run.md), MI21 benchmark (resource_estimates_nil_pipeline.md).

| Process | CPUs | Memory (alloc) | Memory (actual) | Runtime (est.) | Notes |
|---------|------|----------------|-----------------|----------------|-------|
| MERGE_FASTQ | 1 | 4 GB | ~5 MB | ~38s | I/O only |
| HIFIASM | 16 | 64 GB | 33 GB | 3.4–5.5h | Scales linearly with FASTQ size |
| GFA_TO_FASTA | 1 | 4 GB | ~0.5 GB | ~6s | |
| RAGTAG_SCAFFOLD (×2/sample) | 8 | 128 GB | 104–110 GB | ~1.8h | Memory-bound (minimap2 index) |
| RAGTAG_MERGE | 4 | 16 GB | 16 GB | ~36s | |
| ORIENT_MERGED_SCAFFOLDS | 8 | 32 GB | ~10 GB | ~15m | |
| LIFTOFF | 8 | 32 GB | 19 GB | ~37m | |
| DOTPLOT_MAP (×2/sample) | 8 | 32 GB | 16–17 GB | ~4–6m | |
| DOTPLOT_PLOT | 1 | 8 GB | <1 GB | ~54s | |
| ANCHORWAVE_B73 | 8 | 128 GB | 83 GB | ~67m | Exceeds 64 GB alloc; bumped to 128 GB |
| ANCHORWAVE_PT | 8 | 128 GB | TBD | ~5h | Long pole of entire pipeline |

---

## 3. Per-Sample HIFIASM Estimates

HIFIASM scales linearly with input FASTQ size at ~0.24h per 1x coverage (16 cores).

| Sample | FASTQ total | Est. coverage | Est. HIFIASM time |
|--------|-------------|---------------|-------------------|
| MI21_NIL | 11.8 GB | ~14x | **3.4h** |
| BNI_NIL | 13.9 GB | ~17x | **4.0h** |
| TMEX_NIL | 15.8 GB | ~19x | **4.3h** (measured) |
| BDI_NIL | 19.0 GB | ~23x | **5.5h** |
| **Sum (serialized)** | | | **17.2h** |

---

## 4. Phase-by-Phase Timeline

### Phase 1: MERGE_FASTQ (T+0 to T+0.02h)

All 4 samples run in parallel (4 cores). Done in ~1 minute.

### Phase 2: HIFIASM — serialized (T+0 to T+17.2h)

Only 1 HIFIASM fits (16 + 1 orch + 9 ntanduk = 26 of 32 slots). The remaining 6 slots sit idle — no 8-core job fits alongside.

Each completed sample's GFA_TO_FASTA runs instantly (1 core), but RAGTAG_SCAFFOLD (8 cores) is blocked until the HIFIASM phase ends.

Assuming submission order TMEX → MI21 → BNI → BDI:

| Job | Start (clock) | End (clock) | Duration |
|-----|---------------|-------------|----------|
| HIFIASM TMEX | Mon 18:33 | Mon 22:51 | 4.3h |
| HIFIASM MI21 | Mon 22:51 | Tue 02:15 | 3.4h |
| HIFIASM BNI | Tue 02:15 | Tue 06:15 | 4.0h |
| HIFIASM BDI | Tue 06:15 | Tue 11:45 | 5.5h |

**All HIFIASM complete: ~Tue 11:45 EDT**

### Phase 3: RAGTAG — pipelined, 2 slots (T+17.2h to T+25.5h)

After HIFIASM, 22 slots are free. 2 × 8-core jobs run concurrently. Each sample's RAGTAG_B73 + RAGTAG_PT fill both slots for 1.8h.

RAGTAG jobs were submitted right after each sample's HIFIASM finished — they've been pending for hours and take priority over post-ORIENT jobs from earlier samples.

**This causes an important scheduling effect:** RAGTAG for all 4 samples runs before any post-RAGTAG jobs (ORIENT, DOTPLOT_MAP, ANCHORWAVE), because the RAGTAG jobs have longer queue wait times and LSF schedules FIFO within a priority level.

| Job pair | Start (clock) | End (clock) |
|----------|---------------|-------------|
| RAGTAG B73+PT TMEX | Tue 11:45 | Tue 13:33 |
| ORIENT TMEX + RAGTAG_B73 MI21 | Tue 13:33 | Tue 13:48 / 15:21 |
| RAGTAG_PT MI21 (after ORIENT frees slot) | Tue 13:48 | Tue 15:36 |
| RAGTAG B73+PT BNI | Tue 15:36 | Tue 17:24 |
| RAGTAG B73+PT BDI | Tue 17:24 | Tue 19:12 |

Minor overlaps from ORIENT (15min) and RAGTAG_MERGE (instant) shave ~30min off.

**All RAGTAG done: ~Tue 19:00 EDT**

### Phase 4: ORIENT + DOTPLOT — fast (T+25.5h to T+26h)

Once RAGTAG clears, all 4 samples run ORIENT → DOTPLOT_MAP → DOTPLOT_PLOT. These are short jobs that cycle through the 2 slots quickly.

| Step | Duration per sample | Total for 4 samples |
|------|---------------------|---------------------|
| ORIENT | 15min | ~30min (2 at a time) |
| DOTPLOT_MAP ×2 | 6min each | ~24min |
| DOTPLOT_PLOT | ~1min | ~4min |

**All dotplots ready: ~Tue 20:00 EDT**

### Phase 5: LIFTOFF + ANCHORWAVE — long tail (T+26h to T+39h)

After dotplots, 12 remaining jobs compete for 2 slots:

| Jobs | Count | Duration each | Slot-hours total |
|------|-------|---------------|------------------|
| LIFTOFF | 4 | 0.6h | 2.4h |
| ANCHORWAVE_B73 | 4 | 1.1h | 4.4h |
| ANCHORWAVE_PT | 4 | 5.0h | 20.0h |
| **Total** | **12** | | **26.8 slot-hours** |

With 2 slots: 26.8 / 2 = **~13.4h** theoretical minimum.

LIFTOFF and ANCHORWAVE_B73 finish first (~3.4h), then 4 ANCHORWAVE_PT jobs take 2 × 5h = 10h.

**Pipeline complete: ~Wed 08:00–09:00 EDT**

---

## 5. Per-Sample Milestone Summary

All times assume submission at Mon 18:32 EDT and ntanduk's 9 slots persist.

| Sample | HIFIASM done | RAGTAG done | Dotplots ready | ANCHORWAVE_PT done | All complete |
|--------|-------------|-------------|----------------|--------------------|--------------|
| TMEX_NIL | Mon 22:51 | Tue 13:33 | Tue ~20:15 | Wed ~03:00 | Wed ~03:00 |
| MI21_NIL | Tue 02:15 | Tue 15:36 | Tue ~20:30 | Wed ~05:00 | Wed ~05:00 |
| BNI_NIL | Tue 06:15 | Tue 17:24 | Tue ~20:45 | Wed ~07:00 | Wed ~07:00 |
| BDI_NIL | Tue 11:45 | Tue 19:12 | Tue ~21:00 | Wed ~09:00 | Wed ~09:00 |

---

## 6. Key Milestones

| Milestone | ETA (clock) | Hours from submission |
|-----------|-------------|---------------------|
| First HIFIASM complete (TMEX) | Mon 22:51 | 4.3h |
| All HIFIASM complete | Tue 11:45 | 17.2h |
| First dotplots ready (TMEX) | Tue ~20:15 | ~25.7h |
| **All dotplots ready** | **Tue ~21:00** | **~26.5h** |
| First sample fully complete (TMEX) | Wed ~03:00 | ~32.5h |
| **Pipeline fully complete** | **Wed ~09:00** | **~38.5h** |

---

## 7. Where Time Is Spent

| Phase | Duration | % of total | Bottleneck |
|-------|----------|-----------|------------|
| HIFIASM (serialized) | 17.2h | 45% | Only 1 fits in 22 available slots |
| RAGTAG (serialized) | 7.3h | 19% | 2 per sample × both slots = 1 sample at a time |
| ORIENT + DOTPLOT | 1.0h | 3% | Short jobs, fast |
| ANCHORWAVE_PT (long tail) | 13.0h | 33% | 5h each, 2 at a time |
| **Total** | **~38.5h** | | |

**Idle slot-hours during HIFIASM phase:** 6 slots × 17.2h = **103 slot-hours wasted** (27% of total capacity).

---

## 8. Scenario: ntanduk's Jobs Finish

ntanduk's `combine_vcf` jobs have been running since Mar 11 (5 days). If they complete:

| Metric | Current (22 slots) | ntanduk done (31 slots) |
|--------|-------------------|------------------------|
| HIFIASM concurrent | 1 | 1 (16+16=32 > 31) |
| 8-core concurrent | 2 | **3** |
| HIFIASM + RAGTAG overlap | No (16+8=24 > 22) | **Yes** (16+8=24 ≤ 31) |
| RAGTAG batches | 4 (1 sample/batch) | 3 (8 jobs / 3 per batch) |
| ANCHORWAVE_PT batches | 2 (5h each) | 2 (same: ceil(4/3)=2) |
| Post-HIFIASM duration | ~21h | **~14h** |
| **Total ETA** | **~38.5h** | **~31h** |
| **All dotplots** | **Tue ~21:00** | **Tue ~18:00** |

The biggest gain is HIFIASM+RAGTAG overlap: completed samples can start RAGTAG while the next HIFIASM runs, saving ~4h of serialization.

---

## 9. Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| ntanduk jobs persist all week | Already priced in (current estimate) | Medium | Talk to ntanduk / lab; their jobs have run 5 days |
| ANCHORWAVE_B73 exceeds 128 GB, OOM killed | Adds 1.1h per rerun | Low | Was 83 GB on TMEX; now allocated 128 GB |
| RAGTAG exceeds 128 GB on BDI (largest input, 19 GB) | Adds 1.8h per rerun | Low | TMEX used 110 GB; BDI genome same size |
| BDI HIFIASM slower than estimated (23x coverage) | Adds 1-2h | Medium | 5.5h is extrapolated; could be 6h+ |
| sara fills up with other users' jobs | Delays all pending jobs | Low | sara typically lightly used |
| Node memory insufficient for 128 GB RAGTAG | Job stays pending | Low | Ran successfully on TMEX |

---

## 10. What Could Speed This Up

| Change | Time saved | Feasibility |
|--------|-----------|-------------|
| Move orchestrator off sara (standard/long queue) | +1 slot → no real gain (22→23, still 2×8) | Blocked: standard needs 8 cores min, long has 480 pending |
| ntanduk jobs finish | ~7h saved (overlap HIFIASM+RAGTAG, 3×8 slots) | Out of our control |
| Reduce HIFIASM to 8 cores | 2 HIFIASM concurrent, but each ~2× slower. Net neutral. | Not helpful |
| Run RAGTAG at 4 cores (slower but more parallel) | Unknown scaling; may double RAGTAG time | Risky |
| Disable ANCHORWAVE (dotplots don't need it) | Saves ~13h of slot-time | Only if annotations not needed |

---

*Analysis generated: March 16, 2026, 18:45 EDT*
*Assumes ntanduk's 9 slots persist for entire run (worst case)*
