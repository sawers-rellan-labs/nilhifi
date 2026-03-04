# Resource Estimates — NIL Assembly Pipeline

## Empirical Baseline: MI21 (bc2051 + bc2052)

Resource usage from LSF job logs in `sara/DNA_Sequencing_raw/Inv4mNILS/`.

### Input data

| Run | FASTQs | Total size | Coverage | peak_hom |
|-----|--------|------------|----------|----------|
| bc2051 only | bc2051 (7.7 GB) | 7.7 GB | ~9x | 9 |
| bc205X merged | bc2051 + bc2052 (7.7 + 4.1 GB) | 11.8 GB | ~14x | 14 |

### Measured resource usage (from LSF job summaries)

| Step | Job | Wall time | CPU time | Peak RAM | Cores | Requested |
|------|-----|-----------|----------|----------|-------|-----------|
| hifiasm (9x) | 304199 | 1.6h (5,731s) | 22.6h (81,489s) | 33 GB | 16 | 64 GB, 12h |
| hifiasm (14x) | 307246 | 3.4h (12,161s) | 47.3h (170,367s) | 33 GB | 16 | 64 GB, 16h |
| ragtag (B73+PT+merge) | 306896 | 2.0h (7,354s) | 15.3h (55,013s) | 15 GB | 8 | 32 GB, 6h |
| liftoff | 311295 | 23 min | — | — | 8 | 32 GB, 6h |
| anchorwave vs B73 | 310284 | ~27 min | — | — | 8 | 64 GB, 24h |
| anchorwave vs PT | 310285 | ~5h | — | — | 8 | 64 GB, 24h |
| dotplot (R) | 311062 | ~15 min | — | — | 1 | 8 GB, 1h |

### Key observations

1. **hifiasm RAM is genome-bound, not coverage-bound**: Both 9x and 14x peaked at 33 GB. The k-mer hash table is sized by genome complexity (~2.2 Gb maize genome), not by read count. All maize NILs will hit ~33 GB regardless of coverage.

2. **hifiasm wall time scales linearly with coverage**: 9x → 1.6h, 14x → 3.4h. The scaling is ~0.24h per 1x coverage (or ~14 min per GB of compressed FASTQ).

3. **ragtag is query-size-dependent**: The 15 GB peak is driven by minimap2 indexing the ~2.2 Gb reference. All maize assemblies will use similar RAM since the query and reference sizes are constant (~2.2 Gb each).

4. **anchorwave vs PT is 11x slower than vs B73**: PT has ~4,600 more annotated genes (39,274 vs 33,015 CDS sequences) and the proali whole-genome alignment is O(n²) in anchor density. This ratio will hold across all NILs.

## Per-Sample Extrapolation

### FASTQ sizes and estimated coverage

| Genotype | Barcodes | FASTQ sizes | Total | Est. coverage | Source |
|----------|----------|-------------|-------|---------------|--------|
| MI21_inv4m | bc2051 + bc2052 | 7.7 + 4.1 GB | 11.8 GB | ~14x | Inv4mNILS (DONE) |
| TMEX_inv4m | bc2049 + bc2050 | 1.8 + 14.0 GB | 15.8 GB | ~19x | Inv4mNILS |
| Z031E0047 | bc2053 + bc2054 | 4.3 + 9.6 GB | 13.9 GB | ~17x | BDI_BNI_NILS |
| Z031E0050 | bc2055 + bc2056 | 7.0 + 12.0 GB | 19.0 GB | ~23x | BDI_BNI_NILS |

Coverage estimated from FASTQ size: ~2.2 Gb genome, ~18 kb mean HiFi read length, gzip compression ~3.5x.
Formula: coverage ≈ (compressed_size × 3.5) / 2.2e9.

All samples are above the ~15x critical threshold where HiFi assembly contiguity plateaus (see README: "Empirical coverage guidelines"). Z031E0050 at ~23x is the highest — diminishing returns on contiguity but slightly better heterozygous resolution.

### Estimated resource usage per sample

Extrapolated from MI21 baseline using linear scaling for wall time (by FASTQ size) and constant RAM (genome-bound).

#### TMEX_inv4m (15.8 GB, ~19x)

| Step | Cores | RAM (est.) | RAM (request) | Wall time (est.) | Wall time (request) |
|------|-------|------------|---------------|------------------|---------------------|
| MERGE_FASTQ | 1 | <1 GB | 4 GB | ~5 min | 2h |
| HIFIASM | 16 | **33 GB** | 64 GB | **4.5h** | 16h |
| GFA_TO_FASTA | 1 | <1 GB | 4 GB | <1 min | 30m |
| RAGTAG_SCAFFOLD ×2 | 8 | **15 GB** | 32 GB | ~2h | 6h |
| RAGTAG_MERGE | 4 | ~8 GB | 16 GB | ~10 min | 2h |
| LIFTOFF | 8 | ~12 GB | 32 GB | ~25 min | 6h |
| DOTPLOT_MAP ×2 | 8 | ~8 GB | 32 GB | ~15 min each | 2h |
| DOTPLOT_PLOT | 1 | ~2 GB | 8 GB | ~5 min | 1h |
| ANCHORWAVE ×2 (opt) | 8 | ~30 GB | 64 GB | ~30min + ~5h | 24h |

**Total wall time (sequential):** ~8h core pipeline + ~6h anchorwave
**Total wall time (parallel where possible):** ~7h core + ~5h anchorwave

#### Z031E0047 (13.9 GB, ~17x)

| Step | Cores | RAM (est.) | RAM (request) | Wall time (est.) | Wall time (request) |
|------|-------|------------|---------------|------------------|---------------------|
| HIFIASM | 16 | **33 GB** | 64 GB | **4.0h** | 16h |
| RAGTAG_SCAFFOLD ×2 | 8 | **15 GB** | 32 GB | ~2h | 6h |
| LIFTOFF | 8 | ~12 GB | 32 GB | ~25 min | 6h |
| ANCHORWAVE ×2 (opt) | 8 | ~30 GB | 64 GB | ~30min + ~5h | 24h |

#### Z031E0050 (19.0 GB, ~23x)

| Step | Cores | RAM (est.) | RAM (request) | Wall time (est.) | Wall time (request) |
|------|-------|------------|---------------|------------------|---------------------|
| HIFIASM | 16 | **33 GB** | 64 GB | **5.5h** | 16h |
| RAGTAG_SCAFFOLD ×2 | 8 | **15 GB** | 32 GB | ~2h | 6h |
| LIFTOFF | 8 | ~12 GB | 32 GB | ~25 min | 6h |
| ANCHORWAVE ×2 (opt) | 8 | ~30 GB | 64 GB | ~30min + ~6h | 24h |

### RAM scaling rationale

| Step | Peak RAM (MI21) | Scaling factor | Notes |
|------|----------------|----------------|-------|
| HIFIASM | 33 GB | **Genome-bound** (constant) | k-mer hash sized by ~2.2 Gb genome, not read count. Both 9x and 14x peaked at exactly 33 GB |
| RAGTAG | 15 GB | **Reference-bound** (constant) | minimap2 index of ~2.2 Gb reference dominates; query assembly is same size for all NILs |
| ANCHORWAVE | ~30 GB | **Anchor-count-bound** (constant) | CDS anchors come from reference annotation (33k B73, 39k PT) — same for all queries |
| LIFTOFF | ~12 GB | **Annotation-bound** (constant) | B73 annotation size is fixed; query genome size is constant |

All RAM-intensive steps are bounded by the reference genome or annotation, not by the query sample. RAM estimates are the same across all NILs.

### Total cluster allocation (all 3 pending samples)

| Resource | Core pipeline | With anchorwave |
|----------|---------------|-----------------|
| Total wall hours | ~24h | ~40h |
| Peak concurrent cores | 16 (hifiasm) | 16 |
| Peak concurrent RAM | 33 GB actual / 64 GB requested | 33 GB actual / 64 GB requested |
| Storage per sample (see below) | ~15 GB (cleaned) | ~37 GB (cleaned) |
| Total new storage | ~45 GB | ~111 GB |

### Recommended Nextflow resource requests

Values in `nextflow.config`. Requests are 2x expected peak for safety, except hifiasm RAM which is stable at 33 GB (request 64 GB as buffer):

| Process | cpus | memory (request) | memory (est. peak) | time |
|---------|------|-------------------|--------------------|------|
| MERGE_FASTQ | 1 | 4 GB | <1 GB | 2h |
| HIFIASM | 16 | 64 GB | 33 GB | 16h |
| GFA_TO_FASTA | 1 | 4 GB | <1 GB | 30m |
| RAGTAG_SCAFFOLD | 8 | 32 GB | 15 GB | 6h |
| RAGTAG_MERGE | 4 | 16 GB | ~8 GB | 2h |
| LIFTOFF | 8 | 32 GB | ~12 GB | 6h |
| DOTPLOT_MAP | 8 | 32 GB | ~8 GB | 2h |
| DOTPLOT_PLOT | 1 | 8 GB | ~2 GB | 1h |
| ANCHORWAVE | 8 | 64 GB | ~30 GB | 24h |

## Disk Usage Audit — MI21 Pipeline (bc205X)

### Current state: 113 GB across two locations

The MI21 pipeline outputs are split between the project folder and the raw data
folder (where early runs dumped intermediates before the project structure existed).

#### Project folder: `assembly/` — 43 GB

| Directory | Size | Contents | Status |
|-----------|------|----------|--------|
| `hifiasm/bc205X/` | 8.7 GB | GFA files (p_ctg, r_utg, p_utg, a_ctg) + FASTA + bins | Mixed: keep FASTA+GFA, bins are intermediate |
| `hifiasm/bc2051/` | 16 KB | Empty (bc2051 files never copied from raw folder) | Needs cleanup plan action |
| `ragtag/scaffold_B73/` | 2.1 GB | Scaffold AGP + FASTA + minimap2 PAF | Keep AGP+FASTA, PAF is intermediate |
| `ragtag/scaffold_PT/` | 2.1 GB | Same structure | Same |
| `ragtag/merge/` | 6.8 GB | merge FASTA (2.1G) + **minimap2 index** (4.8G) + AGP | **Index is intermediate — 4.8 GB recoverable** |
| `ragtag/correct/` | 16 KB | Empty (correct step was abandoned) | Delete |
| `anchorwave/vs_B73/` | 8.3 GB | MAF (4.1G×2) + SAM (50+49+37M) + CDS + dotplot | MAF files dominate |
| `anchorwave/vs_PT/` | 14 GB | MAF (5.9+5.8G) + SAM (72+66+49M) + PT_chrnames.fa (2G) + CDS + dotplot | **PT_chrnames.fa is intermediate — 2 GB recoverable** |
| `liftoff/B73/` | 754 MB | GFF3 (225M) + intermediate_files/ (529M) | **intermediate_files/ is recoverable — 529 MB** |
| `logs/`, `scripts/`, `agent/`, etc. | ~50 MB | Text files | Keep |

#### Raw data folder: `sara/DNA_Sequencing_raw/Inv4mNILS/` — 70 GB

| Category | Size | Files | Status |
|----------|------|-------|--------|
| **Raw FASTQs (keep)** | 27.5 GB | MI21 bc2051 (7.7G) + bc2052 (4.1G) + TMEX bc2049 (1.8G) + bc2050 (14G) | KEEP — original data |
| **bc2051 hifiasm outputs** | ~15 GB | ec.bin (5.1G), ovlp bins (1.8G), GFA (6.3G), FASTA (2G) | DELETE — superseded by bc205X |
| **bc205X hifiasm outputs** | ~17 GB | ec.bin (7.8G), ovlp bins (4.1G), GFA (6.5G) | DELETE — duplicated in `assembly/hifiasm/bc205X/` |
| **bc2051 ragtag dirs** | 8.3 GB | correct/, scaffold_B73/, scaffold_PT/, merge/ | DELETE — used `ragtag correct` (broken Inv4m), wrong assembly |
| **Scripts + logs** | ~1 MB | assemble.sh, build_scaffold.sh, *.out, *.err | Copy logs to `assembly/logs/`, then delete |
| **Stats file** | 1.5 KB | VG.052-01-0003_stats.csv | KEEP — rrellan's file |

### Disk usage per file type (bc205X pipeline)

| File type | vs B73 | vs PT | Per-sample total | Purpose | Intermediate? |
|-----------|--------|-------|-----------------|---------|---------------|
| **MAF** (proali output) | 8.2 GB | 11.7 GB | 19.9 GB | Whole-genome alignment | Final (if anchorwave enabled) |
| **GFA** (hifiasm) | 6.5 GB | — | 6.5 GB | Assembly graph | Keep p_ctg.gfa only (2.1G), rest intermediate |
| **minimap2 index** (.mmi) | — | — | 4.8 GB | Ragtag merge index | Intermediate — auto-regenerated |
| **FASTA** (assembly) | — | — | 2.1 GB | Primary contigs | Final |
| **FASTA** (ragtag merge) | — | — | 2.1 GB | Scaffolded assembly | Final |
| **SAM** (CDS mappings) | 136 MB | 187 MB | 323 MB | Dotplot input | Intermediate — regenerated from CDS |
| **PT_chrnames.fa** | — | 2.0 GB | 2.0 GB | PT reference with fixed names | Intermediate — regenerated by `sed` |
| **ec.bin** (error correction) | — | — | 7.8 GB | hifiasm error-corrected reads | Intermediate — not needed after assembly |
| **ovlp bins** (overlaps) | — | — | 4.1 GB | hifiasm overlap graph | Intermediate — not needed after assembly |
| **liftoff intermediate_files/** | — | — | 529 MB | Minimap2 alignments for liftoff | Intermediate |
| **Dotplot tabs + plots** | 2 MB | 3 MB | 5 MB | Dotplot data + PDF/SVG | Final |
| **AGP** (scaffold coords) | — | — | ~200 KB | Scaffold placement | Final |

### Recoverable disk space

| What to delete | Size | Risk |
|----------------|------|------|
| **Raw folder intermediates** (bc2051 + bc205X outputs in Inv4mNILS/) | **~40 GB** | None — bc2051 superseded, bc205X duplicated in project folder |
| **hifiasm ec.bin + ovlp bins** (in project folder) | **~12 GB** | Low — only needed to resume interrupted hifiasm; full rerun takes 3-4h |
| **ragtag merge .mmi index** | **4.8 GB** | None — auto-regenerated by minimap2 |
| **PT_chrnames.fa** (anchorwave/vs_PT/) | **2.0 GB** | None — regenerated by `sed` in pipeline |
| **liftoff intermediate_files/** | **529 MB** | None — regenerated by liftoff |
| **SAM files** (query.sam, ref.sam, query_mq1.sam) | **323 MB** | Low — regenerated by minimap2 in dotplot step |
| **ragtag/correct/** (empty) | 16 KB | None |
| **hifiasm r_utg.gfa + p_utg.gfa** (unitig graphs) | **4.4 GB** | Low — only p_ctg.gfa needed for downstream |
| **Total recoverable** | **~64 GB** | |

### Cleaned disk footprint per sample

After cleanup, the MI21 pipeline keeps only final outputs:

| Category | Size | Files |
|----------|------|-------|
| Assembly (p_ctg.gfa + p_ctg.fa) | 4.2 GB | hifiasm primary contig GFA + FASTA |
| Scaffold (B73 + PT + merge) | 6.3 GB | 3× AGP + FASTA (no .mmi index) |
| Liftoff | 225 MB | GFF3 + unmapped list (no intermediates) |
| Dotplots | 5 MB | dotplot.tab + PDF/SVG per reference |
| **Core pipeline total** | **~11 GB** | |
| AnchorWave MAF (if enabled) | 19.9 GB | 2× MAF + filtered MAF per reference |
| AnchorWave intermediates (CDS, SAM, anchors) | ~300 MB | Keep anchors, delete rest |
| **With anchorwave total** | **~31 GB** | |

### Projected disk usage for all NIL runs

| Sample | Core pipeline | With anchorwave | Raw FASTQs | Nextflow work/ |
|--------|---------------|-----------------|------------|----------------|
| MI21 (done) | 11 GB | 31 GB | 11.8 GB | — |
| TMEX | ~11 GB | ~31 GB | 15.8 GB | ~30 GB |
| Z031E0047 | ~11 GB | ~31 GB | 13.9 GB | ~30 GB |
| Z031E0050 | ~11 GB | ~31 GB | 19.0 GB | ~30 GB |
| **Total (all 4)** | **~44 GB** | **~124 GB** | **60.5 GB** | **~90 GB** |

The Nextflow `work/` directory holds intermediate files for `-resume` support.
It grows to ~30 GB per sample during execution and can be cleaned after the
pipeline finishes successfully.

### Cleanup best practices for the Nextflow pipeline

**1. Let Nextflow manage intermediates via `work/`**

Nextflow stores all process outputs in `work/` and copies finals to `publishDir`.
After a successful run, `work/` can be purged:

```bash
nextflow clean -f          # removes work/ for completed runs
# or selectively:
nextflow clean -before <run_name>  # keeps most recent run
```

**2. Avoid publishing intermediate files**

Only add `publishDir` to processes that produce final outputs. Current pipeline
already does this — MERGE_FASTQ has no publishDir (merged FASTQ is intermediate).

**3. hifiasm binary files are the largest intermediates**

The `ec.bin` (7.8 GB) and `ovlp.*.bin` (4.1 GB) files are only needed to resume
a failed hifiasm run. The pipeline should NOT publish these. Only the GFA and
FASTA matter. Current HIFIASM module publishes only `*.gfa` — correct.

**4. AnchorWave MAF files dominate final storage**

At ~20 GB per sample (B73 + PT), MAF files are 65% of total storage. Consider:
- Only run anchorwave on samples where SV/CNV cataloguing is needed
- Compress MAF with `gzip` (MAF compresses ~4x → ~5 GB per sample)
- Delete `*.f.maf` (filtered) if `*.maf` (full) is kept — they're nearly identical in size

**5. Clean the raw data folder**

The `sara/DNA_Sequencing_raw/Inv4mNILS/` folder currently has ~40 GB of
intermediate files from the manual MI21 run (see `agent/cleanup_raw_folder.md`).
The Nextflow pipeline writes to `results/`, not to the raw folder, so this
problem won't recur. But the existing mess should be cleaned.

**6. Ragtag minimap2 index (.mmi) is regenerated automatically**

The 4.8 GB `.mmi` file in `ragtag/merge/` was created by liftoff's internal
minimap2 call. It's regenerated on demand and should not be kept.

## Coverage Scaling Model (from README)

The README documents a phase-transition in HiFi assembly contiguity:

| Metric | bc2051 (~9x) | bc205X (~14x) | Fold change |
|--------|-------------|--------------|-------------|
| N50 | 1.3 Mb | 13.7 Mb | **10.3x** |
| Contigs | 3,124 | 740 | 0.24x |
| Total size | 2.20 Gb | 2.21 Gb | ~1.0x |
| Max contig | 6.5 Mb | 48.0 Mb | 7.4x |

All pending samples (17-23x) are above the ~15x plateau. Expected assembly quality will be comparable to or slightly better than the MI21 bc205X run.

Three mechanisms drive the nonlinear improvement (from README):
1. **Overlap graph connectivity** — Poisson coverage gaps close exponentially
2. **Repeat spanning** — more reads span LTR retrotransposons (5-15 kb)
3. **Lander-Waterman gaps** — 9x: ~15,000 gaps; 14x: ~100 gaps; 20x: ~3 gaps

## Nextflow Bad Practices — Assessment of Existing inv4m Pipeline

The existing Nextflow pipeline at `scripts/01_hpc_pipelines/nextflow/` in the
[inv4m GitHub repo](https://github.com/sawers-rellan-labs/inv4m) has several
issues worth fixing in the new assembly pipeline.

### Issues Found

**1. Config duplication instead of parameterization**

`nextflow.config` and `nextflow_jmj_corrected.config` are nearly identical —
only `ref_transcriptome` and `outdir` differ. This means bug fixes must be
applied to both files.

*Fix:* One config file with params that the run script overrides:
```bash
nextflow run main.nf --ref_transcriptome /path/to/corrected.fa --outdir ./quant_jmj
```

**2. Launcher script duplication**

`run_quantify_psu2022.sh` and `run_quantify_jmj_corrected.sh` are identical
except for the `-c` flag. Same problem: changes in one aren't reflected in the
other.

*Fix:* One launcher script that accepts a config parameter, or better — use
Nextflow's `--param` overrides and a single launcher.

**3. Destructive `rm -rf work/` in launcher**

`run_quantify_jmj_corrected.sh` has `rm -rf work/` — this deletes the Nextflow
work directory containing cached intermediate results from all previous runs.
Combined with `-resume` being absent from this script (but present in the other),
this guarantees full recomputation every time.

*Fix:* Never delete `work/` in a launcher script. Use `-resume` consistently.
If a clean run is truly needed, pass it as a flag, don't hardcode it.

**4. Inconsistent conda activation**

- `nextflow.config` uses `conda = '/share/maize/frodrig4/conda/env/kallisto'`
  inside the `lsf` profile (correct approach)
- `nextflow_jmj_corrected.config` uses `beforeScript = 'source ~/.bashrc && conda activate ...'`
  (fragile — depends on user's `.bashrc` content)
- The original config has `conda { enabled = true }` but the corrected one doesn't

*Fix:* Always use `conda = '/path/to/env'` with `conda.enabled = true`. Never
depend on `.bashrc` — it may not be sourced in batch jobs, and its contents can
change.

**5. Glob pattern baked into workflow instead of sample sheet**

The workflow uses `fromFilePairs("${params.seq_dir}/*_R{1,2}_001.fastq.gz")` —
this only works for Illumina-style naming and discovers samples implicitly.
Adding/removing samples requires changing the glob or moving files.

*Fix:* Use a CSV sample sheet (as in our assembly pipeline). Explicit sample
manifests are reproducible and auditable.

**6. Monolithic workflow file**

All processes and the workflow are in one `quantify_expression.nf`. For 2
processes this is fine, but the pattern doesn't scale. The assembly pipeline has
9 processes.

*Fix:* One `.nf` file per process in a `modules/` directory, imported in
`main.nf` via `include`. This is DSL2 best practice.

**7. Stale/inconsistent environment settings**

- `env { NXF_OFFLINE = 'true' }` and `offline = true` in one config, absent in the other
- `tower { enabled = false }` — deprecated Nextflow Tower syntax (now Seqera Platform)
- `dag.overwrite = true` without `dag.enabled = true`

*Fix:* Remove stale settings. Only set `NXF_OFFLINE` if actually needed (HPC
compute nodes often lack internet — but the login node where Nextflow runs has it).

### What the Existing Pipeline Does Right

- Process names use SCREAMING_SNAKE_CASE (`INDEX_TRANSCRIPTOME_KALLISTO`, `QUANT_KALLISTO`) — correct Nextflow convention
- `publishDir` with `mode: 'copy'` in each process
- Resource allocation per process via `withName:` selectors
- `tag "${sample_id}"` for job labeling
- Required parameter validation at workflow start

### Improvements Applied in Assembly Pipeline

| Issue | Old pipeline | New assembly pipeline |
|-------|--------------|-----------------------|
| Config duplication | 2 near-identical configs | 1 config, params overridden at CLI |
| Launcher duplication | 2 near-identical scripts | 1 launcher (planned) |
| Conda activation | Mix of `conda=` and `beforeScript ~/.bashrc` | Consistent `conda=` + explicit `beforeScript conda.sh` |
| Sample input | Glob pattern in workflow | CSV sample sheet |
| Modularity | Single .nf file | `modules/` directory, 1 file per process |
| Destructive cleanup | `rm -rf work/` hardcoded | Never; use `-resume` |
| Environment settings | Stale `offline`, `tower` | Removed |
