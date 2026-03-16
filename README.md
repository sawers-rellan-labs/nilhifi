# NIL Assembly Pipeline

Nextflow DSL2 pipeline for maize Near-Isogenic Line (NIL) genome assembly,
scaffolding, annotation, and dotplot visualization on NCSU HPC (LSF).

## Pipeline Overview

```
barcode1.fq.gz ─┐
                 ├─→ MERGE_FASTQ → HIFIASM → GFA_TO_FASTA
barcode2.fq.gz ─┘                                 │
                                       ┌───────────┴───────────┐
                                       ▼                       ▼
                              RAGTAG_SCAFFOLD_B73    RAGTAG_SCAFFOLD_PT
                                       │                       │
                                       └─────────┬─────────────┘
                                                  ▼
                                            RAGTAG_MERGE
                                                  ▼
                                    ORIENT_MERGED_SCAFFOLDS
                                                  │
                                  ┌───────────────┼───────────────┐
                                  ▼               ▼               ▼
                              LIFTOFF    DOTPLOT_MAP_B73   DOTPLOT_MAP_PT
                                                  │               │
                                                  └───────┬───────┘
                                                          ▼
                                                    DOTPLOT_PLOT
                                                          │
                                           ┌──────────────┴──────────────┐
                                           ▼                             ▼
                                    ANCHORWAVE_B73                ANCHORWAVE_PT
```

## Input

### Sample sheet (`samplesheet.csv`)

```csv
sample,barcode1,barcode2
TMEX_inv4m,/rsstu/.../TMEX_inv4m_bc2049.fastq.gz,/rsstu/.../TMEX_inv4m_bc2050.fastq.gz
```

Each row is one genotype with two HiFi barcode FASTQs to merge.

### Samples and raw data

All HiFi FASTQs are on RSSTU (read-only):

| Sample | Genotype ID | Barcode 1 | Barcode 2 | Total data | Directory |
|--------|-------------|-----------|-----------|------------|-----------|
| TMEX\_inv4m | TMEX | bc2049 (1.8G) | bc2050 (15G) | 16.8 GB | `Inv4mNILS/` |
| BNI\_inv4m | Z031E0047 | bc2053 (4.3G) | bc2054 (9.6G) | 13.9 GB | `BDI_BNI_NILS/` |
| BDI\_inv4m | Z031E0050 | bc2055 (7.1G) | bc2056 (12G) | 19.1 GB | `BDI_BNI_NILS/` |

Raw data base path: `/rsstu/users/r/rrellan/sara/DNA_Sequencing_raw/`

The previous bash-based pipeline (Mi21, Z031E0047/bc2051+bc2052, 12 GB total) is at
`/rsstu/users/r/rrellan/DOE_CAREER/inv4m/nilhifimi21/`. Runtime estimates for this
pipeline are based on that run.

All three samples are maize NILs with ~2.3 Gb genomes. Data volumes are comparable,
so the current resource allocations (HIFIASM 64 GB, RAGTAG\_SCAFFOLD 128 GB) should
be sufficient for all samples. BDI is the largest at 19.1 GB but still well within
the headroom observed for TMEX (HIFIASM peaked at 48 GB / 64 GB allocated).

### Reference genomes

| Reference | Files |
|-----------|-------|
| B73 | `Zm-B73-REFERENCE-NAM-5.0.fa` + `Zm-B73-REFERENCE-NAM-5.0_Zm00001eb.1.gff3` |
| PT | `Zm-PT-REFERENCE-HiLo-1.0.fa` + `Zm-PT-REFERENCE-HiLo-1.0_Zm00109aa.1.gff3` |

Paths configured in `nextflow.config` under `params.ref_*`.

**Note:** The PT FASTA uses `PT01`–`PT10` chromosome names while the PT GFF uses
`chr1`–`chr10`. The DOTPLOT\_MAP and ANCHORWAVE modules automatically rename the
FASTA headers (`PT01→chr1`, etc.) to match the GFF before processing.

## Output

Base directory: `params.outdir` (default: `/rsstu/users/r/rrellan/tlaloc/nilhifi/results`)

```
results/
├── {sample}/
│   ├── assembly/
│   │   ├── {sample}_asm.bp.p_ctg.gfa      # primary contig graph
│   │   ├── {sample}_asm.bp.a_ctg.gfa      # alternate contig graph
│   │   └── {sample}.p_ctg.fa              # primary contigs FASTA
│   ├── scaffold/
│   │   ├── B73/
│   │   │   ├── ragtag.scaffold.agp
│   │   │   └── ragtag.scaffold.fasta
│   │   ├── PT/
│   │   │   ├── ragtag.scaffold.agp
│   │   │   └── ragtag.scaffold.fasta
│   │   └── merge/
│   │       ├── ragtag.merge.fasta          # final scaffolded assembly
│   │       └── ragtag.merge.agp
│   ├── liftoff/
│   │   ├── {sample}_liftoff_B73.gff3       # transferred gene annotations
│   │   └── {sample}_unmapped_B73.txt
│   ├── dotplot/
│   │   ├── dotplot_vs_B73.tab              # CDS anchor coordinates
│   │   ├── dotplot_vs_PT.tab
│   │   ├── {sample}_dotplot_vs_B73.pdf
│   │   ├── {sample}_dotplot_vs_B73.svg
│   │   ├── {sample}_dotplot_vs_PT.pdf
│   │   ├── {sample}_dotplot_vs_PT.svg
│   │   ├── {sample}_chr4_inv4m_dotplot.pdf # Inv4m zoom comparison
│   │   └── {sample}_chr4_inv4m_dotplot.svg
│   └── anchorwave/
│       ├── vs_B73/
│       │   ├── {sample}_vs_B73.maf
│       │   ├── {sample}_vs_B73.f.maf
│       │   └── anchors
│       └── vs_PT/
│           ├── {sample}_vs_PT.maf
│           ├── {sample}_vs_PT.f.maf
│           └── anchors
└── pipeline_info/
    ├── timeline.html
    └── report.html
```

## Running

Submit via the LSF wrapper script — Nextflow runs as a lightweight orchestrator
job (1 CPU, 8 GB) and submits the actual compute jobs to LSF:

```bash
# On HPC
cd /rsstu/users/r/rrellan/tlaloc/nilhifi/nextflow
bsub < run_nil_assembly_pipeline.sh

# Monitor
bjobs          # check orchestrator + child jobs
bpeek <jobid>  # view Nextflow stdout in real time
```

**Do NOT run Nextflow directly on the login node** — use the wrapper script.
Running `nextflow run` interactively on a login node violates HPC AUP and
causes LSF environment issues (missing `bsub`, `lsf.conf`).

## Resource Utilization

Observed memory usage from TMEX_inv4m run (maize ~2.3 Gb genome, ~47 Gb HiFi data).
Peak memory sourced from LSF `.command.log` summaries and Nextflow `.command.trace` files
in each task's work directory.

| Process | CPUs | Memory (allocated) | Memory (LSF peak) | Wall time (allocated) | Wall time (actual) |
|---------|------|--------------------|--------------------|-----------------------|--------------------|
| MERGE\_FASTQ | 1 | 4 GB | ~5 MB | 2h | ~38s |
| HIFIASM | 16 | 64 GB | 48 GB | 16h | ~4.3h |
| GFA\_TO\_FASTA | 1 | 4 GB | ~0.5 GB | 30m | ~6s |
| RAGTAG\_SCAFFOLD | 8 | 128 GB | 104–110 GB | 8h | ~1.8h |
| RAGTAG\_MERGE | 4 | 16 GB | 16 GB | 2h | ~36s |
| ORIENT\_MERGED\_SCAFFOLDS | 8 | 32 GB | — | 2h | ~35s (standalone test) |
| LIFTOFF | 8 | 32 GB | 19 GB | 6h | ~37m |
| DOTPLOT\_MAP (B73) | 8 | 32 GB | 16 GB | 2h | ~4m |
| DOTPLOT\_MAP (PT) | 8 | 32 GB | 17 GB | 2h | ~6m |
| DOTPLOT\_PLOT | 1 | 8 GB | — | 1h | ~54s |
| ANCHORWAVE (B73) | 8 | 64 GB | 83 GB | 24h | ~67m |
| ANCHORWAVE (PT) | 8 | 64 GB | — | 24h | — |

Note: ANCHORWAVE\_B73 exceeded its 64 GB allocation (peaked at 83 GB) but was not killed
by LSF on this cluster. ORIENT\_MERGED\_SCAFFOLDS runtime is from standalone test (Python
only, no CDS mapping); the Nextflow module also runs anchorwave gff2seq + minimap2.

### Expected runtimes (from Mi21 bash-based run)

The previous bash pipeline for Mi21 (12 GB HiFi, same references) provides runtime
baselines for the steps that have not yet completed in the Nextflow pipeline:

| Process | Mi21 runtime | Notes |
|---------|-------------|-------|
| RAGTAG\_MERGE | ~10 sec | Trivial merge of two AGPs |
| LIFTOFF | ~23 min | 8 cores |
| DOTPLOT\_MAP (B73) | ~27 min | CDS mapping + filtering |
| DOTPLOT\_MAP (PT) | ~30 min | PT has more CDS anchors (39k vs 33k) |
| DOTPLOT\_PLOT | < 5 min | R/ggplot2, lightweight |
| ANCHORWAVE (B73) | ~27 min | proali whole-genome alignment |
| ANCHORWAVE (PT) | ~5 hours | Slower due to larger PT CDS set |

Critical path: RAGTAG\_MERGE → then LIFTOFF, DOTPLOT\_MAP, ANCHORWAVE run in parallel
→ DOTPLOT\_PLOT waits for both DOTPLOT\_MAPs. AnchorWave PT is the long pole at ~5 hours.

### Pipeline reports

Nextflow generates HTML reports each run (overwritten on re-run):

- **Execution report:** [`results/pipeline_info/report.html`](results/pipeline_info/report.html) — per-task resource usage, durations, status
- **Timeline:** [`results/pipeline_info/timeline.html`](results/pipeline_info/timeline.html) — Gantt chart of task execution

Per-sample copies are also written to `results/<sample>/pipeline_info/`.

## Known Issues and Fixes

### 1. RAGTAG\_MERGE filename collision (fixed)

**Symptom:** `Process RAGTAG_MERGE input file name collision -- There are multiple input files for each of the following file names: ragtag.scaffold.agp`

**Cause:** Both `RAGTAG_SCAFFOLD_B73` and `RAGTAG_SCAFFOLD_PT` emit identically-named
output files (`ragtag.scaffold.agp`, `ragtag.scaffold.fasta`). When Nextflow staged
both sets into the RAGTAG\_MERGE work directory, the names collided.

**Fix:** RAGTAG\_MERGE now uses Nextflow's `path('subdir/filename')` input staging to
place each scaffold's outputs into separate subdirectories (`scaffold_B73/` and
`scaffold_PT/`). The `ragtag.py merge` command receives these directories as arguments,
which is its expected input format. The main workflow was also updated to pass both AGP
and FASTA files (not just AGP) from each scaffold to the merge process.

**Affected files:** `nextflow/modules/ragtag_merge.nf`, `nextflow/main.nf`

### 2. RAGTAG\_SCAFFOLD memory underprovisioned (fixed)

**Symptom:** RAGTAG\_SCAFFOLD was originally allocated 32 GB but minimap2 (asm5 mode on
maize-sized genomes) peaked at 104–114 GB. Tasks happened to succeed because the compute
nodes had sufficient physical memory, but this is not guaranteed.

**Fix:** Memory allocation increased from 32 GB to 128 GB (~12% headroom above the
observed ~114 GB peak).

**Affected file:** `nextflow/modules/ragtag_scaffold.nf`

### 3. Nextflow cache invalidated after pipeline code changes

**Symptom:** After fixing issues #1 and #2, re-running with `-resume` re-submitted
HIFIASM from scratch (~4.3 h) instead of using the cached result from the previous
successful run.

**Cause:** The fixes changed `main.nf` and `ragtag_merge.nf`, producing a new pipeline
revision (`825171e912` vs `75fa3f5b01`). Nextflow computes task cache hashes from the
script content, inputs, and configuration. When `main.nf` changed (workflow wiring),
the cache hashes for all tasks — including upstream tasks like HIFIASM whose process
code did not change — no longer matched, invalidating the entire cache.

**Impact:** The Mar-11 resumed run re-ran MERGE\_FASTQ and HIFIASM despite both having
completed successfully in the Mar-03/04 runs. This added ~4.5 h of redundant compute.

**Lesson:** When fixing downstream processes, be aware that changes to `main.nf` (the
workflow block) can invalidate caches for all processes, not just the ones you modified.
Consider testing workflow-level changes with `-preview` first.

### 4. RAGTAG\_MERGE received directories instead of AGP files (fixed 2026-03-15)

**Symptom:** `ValueError: Input AGPs do not have the same set of components.`

**Cause:** `ragtag.py merge` was called with directory arguments (`scaffold_B73 scaffold_PT`)
instead of explicit AGP file paths. When given a directory, ragtag merge parses files
differently than when given AGP paths directly, leading to a component set mismatch error
even though both AGPs contained identical contig sets.

**Root cause found by:** Comparing with the working bash implementation in
`/rsstu/users/r/rrellan/DOE_CAREER/inv4m/nilhifimi21/scripts/build_scaffold.sh`,
which passes AGP file paths explicitly.

**Fix:** Changed the merge command from:
```
ragtag.py merge -u -o merge_out query.fa scaffold_B73 scaffold_PT
```
to:
```
ragtag.py merge -u -o merge_out query.fa scaffold_B73/ragtag.scaffold.agp scaffold_PT/ragtag.scaffold.agp
```

**Affected file:** `nextflow/modules/ragtag_merge.nf`

### 5. Output directory pointed to old project path (fixed 2026-03-15)

**Symptom:** Pipeline reports (`report.html`, `timeline.html`) written to
`/rsstu/users/r/rrellan/tlaloc/nil_pipeline/results/` instead of the current
project directory.

**Cause:** `params.outdir` in `nextflow.config` still pointed to the old
`nil_pipeline` path from before the project was reorganized into `nilhifi`.

**Fix:** Updated `params.outdir` to `/rsstu/users/r/rrellan/tlaloc/nilhifi/results`.
Copied the Mar-11 report files to the new location.

**Affected file:** `nextflow/nextflow.config`

## Claude Code Setup (HPC)

Claude Code requires sandbox configuration to interact with LSF on NCSU HPC.
Run the setup script once (or after any settings reset), then restart Claude Code:

```bash
cd /rsstu/users/r/rrellan/tlaloc/nilhifi
bash agent/fix_claude_settings.sh
```

This configures:
- **`excludedCommands`** — LSF commands (`bsub`, `bjobs`, `bpeek`, `bhist`, `bkill`, `bqueues`) bypass the sandbox so they can write to `/tmp` and reach the LSF master
- **`allowedDomains`** — Network access to `servlsf`, `10.1.16.42` (LSF master), and `github.com`
- **`autoAllowBashIfSandboxed`** — Auto-approve bash commands within sandbox restrictions

See [`agent/claude_hpc_setup_guide.md`](agent/claude_hpc_setup_guide.md) for full setup details (git identity, push authentication, debugging).

## Key Design Decisions

- **No `ragtag correct`** — misinterprets the Inv4m inversion as misassembly
- **hifiasm `-l0`** — disables purge-dups for inbred NILs
- **Dual-reference scaffolding** — B73 (NIL background) + PT (Inv4m arrangement)
- **MAPQ>=60 filtering** on dotplot SAMs to remove multi-mapper noise
- **Liftoff with `-copies`** for CNV detection at JMJ cluster
- **AnchorWave enabled** — whole-genome alignment against B73 and PT for synteny analysis
- **`executor.perJobMemLimit = true`** — NCSU HPC sets `LSF_UNIT_FOR_LIMITS=GB`.
  Without this flag, Nextflow's LSF executor divides the requested memory by the
  number of CPUs for the `-M` (hard kill limit) directive, while `rusage[mem=]`
  (reservation) gets the full amount. For example, a process requesting 32 GB
  and 8 CPUs produces `-M 4 -R "rusage[mem=32]"` — LSF reserves 32 GB but kills
  the process at 4 GB. Setting `perJobMemLimit = true` makes `-M` use the total
  requested memory, matching the reservation.
