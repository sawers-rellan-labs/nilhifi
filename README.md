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
                                                  │
                                  ┌───────────────┼───────────────┐
                                  ▼               ▼               ▼
                              LIFTOFF    DOTPLOT_MAP_B73   DOTPLOT_MAP_PT
                                                  │               │
                                                  └───────┬───────┘
                                                          ▼
                                                    DOTPLOT_PLOT
                                                          │
                                              (optional)  ▼
                                              ANCHORWAVE_B73 / ANCHORWAVE_PT
```

## Input

### Sample sheet (`samplesheet.csv`)

```csv
sample,barcode1,barcode2
TMEX_inv4m,/rsstu/.../TMEX_inv4m_bc2049.fastq.gz,/rsstu/.../TMEX_inv4m_bc2050.fastq.gz
```

Each row is one genotype with two HiFi barcode FASTQs to merge.

### Reference genomes

| Reference | Files |
|-----------|-------|
| B73 | `Zm-B73-REFERENCE-NAM-5.0.fa` + `Zm-B73-REFERENCE-NAM-5.0_Zm00001eb.1.gff3` |
| PT | `Zm-PT-REFERENCE-HiLo-1.0.fa` + `Zm-PT-REFERENCE-HiLo-1.0_Zm00109aa.1.gff3` |

Paths configured in `nextflow.config` under `params.ref_*`.

## Output

Base directory: `params.outdir` (default: `/rsstu/users/r/rrellan/tlaloc/nil_pipeline/results`)

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
│   └── anchorwave/                         # only if params.run_anchorwave = true
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
cd /rsstu/users/r/rrellan/tlaloc/nil_pipeline/nextflow
bsub < run_nil_pipeline.sh

# Monitor
bjobs          # check orchestrator + child jobs
bpeek <jobid>  # view Nextflow stdout in real time
```

To enable AnchorWave, edit `nextflow.config` and set `params.run_anchorwave = true`
before submitting.

**Do NOT run Nextflow directly on the login node** — use the wrapper script.
Running `nextflow run` interactively on a login node violates HPC AUP and
causes LSF environment issues (missing `bsub`, `lsf.conf`).

## Key Design Decisions

- **No `ragtag correct`** — misinterprets the Inv4m inversion as misassembly
- **hifiasm `-l0`** — disables purge-dups for inbred NILs
- **Dual-reference scaffolding** — B73 (NIL background) + PT (Inv4m arrangement)
- **MAPQ>=60 filtering** on dotplot SAMs to remove multi-mapper noise
- **Liftoff with `-copies`** for CNV detection at JMJ cluster
- **AnchorWave optional** (`params.run_anchorwave = false` by default)
- **`executor.perJobMemLimit = true`** — NCSU HPC sets `LSF_UNIT_FOR_LIMITS=GB`.
  Without this flag, Nextflow's LSF executor divides the requested memory by the
  number of CPUs for the `-M` (hard kill limit) directive, while `rusage[mem=]`
  (reservation) gets the full amount. For example, a process requesting 32 GB
  and 8 CPUs produces `-M 4 -R "rusage[mem=32]"` — LSF reserves 32 GB but kills
  the process at 4 GB. Setting `perJobMemLimit = true` makes `-M` use the total
  requested memory, matching the reservation.
