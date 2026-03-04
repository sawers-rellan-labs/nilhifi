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

```bash
# On HPC (via SSH from laptop)
cd /rsstu/users/r/rrellan/tlaloc/nil_pipeline/nextflow
nextflow run main.nf -profile lsf -resume

# With AnchorWave
nextflow run main.nf -profile lsf -resume --run_anchorwave true
```

## Key Design Decisions

- **No `ragtag correct`** — misinterprets the Inv4m inversion as misassembly
- **hifiasm `-l0`** — disables purge-dups for inbred NILs
- **Dual-reference scaffolding** — B73 (NIL background) + PT (Inv4m arrangement)
- **MAPQ>=60 filtering** on dotplot SAMs to remove multi-mapper noise
- **Liftoff with `-copies`** for CNV detection at JMJ cluster
- **AnchorWave optional** (`params.run_anchorwave = false` by default)
