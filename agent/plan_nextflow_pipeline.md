# Nextflow Pipeline Plan — NIL Assembly & Annotation

## Overview

A DSL2 Nextflow pipeline to automate the assembly, scaffolding, annotation, and
dotplot workflow for maize NIL (Near-Isogenic Line) genotypes. Each genotype has
two HiFi barcodes that must be merged, assembled with hifiasm, scaffolded
against dual references (B73 + PT), annotated via Liftoff, and visualized with
CDS-based dotplots. An optional AnchorWave whole-genome alignment step is
available for SV/CNV cataloguing.

## Samples

### Immediate (Inv4m NILs)

| Genotype    | Barcodes     | FASTQs                                          | Status      |
|-------------|--------------|--------------------------------------------------|-------------|
| MI21_inv4m  | bc2051+bc2052| `MI21_inv4m_bc2051.fastq.gz`, `..._bc2052.fastq.gz` | DONE        |
| TMEX_inv4m  | bc2049+bc2050| `TMEX_inv4m_bc2049.fastq.gz`, `..._bc2050.fastq.gz` | NOT YET     |

Raw: `/rsstu/users/r/rrellan/sara/DNA_Sequencing_raw/Inv4mNILS/`

### Deferred (BDI/BNI NILs)

| Genotype                  | Barcodes     | FASTQs                                                     |
|---------------------------|--------------|------------------------------------------------------------|
| Z031E0047_21MOB_1471_80   | bc2053+bc2054| `Z031E0047_21MOB_1471_80_bc2053.fastq.gz`, `..._bc2054.fastq.gz` |
| Z031E0050_2021MOB_1506_10 | bc2055+bc2056| `Z031E0050_2021MOB_1506_10_bc2055.fastq.gz`, `..._bc2056.fastq.gz` |

Raw: `/rsstu/users/r/rrellan/sara/DNA_Sequencing_raw/BDI_BNI_NILS/`

## Pipeline Architecture

### Input: Sample Sheet (CSV)

```csv
sample,barcode1,barcode2
TMEX_inv4m,/rsstu/users/r/rrellan/sara/DNA_Sequencing_raw/Inv4mNILS/TMEX_inv4m_bc2049.fastq.gz,/rsstu/users/r/rrellan/sara/DNA_Sequencing_raw/Inv4mNILS/TMEX_inv4m_bc2050.fastq.gz
```

Current samplesheet has only TMEX_inv4m. MI21 was already assembled manually.
Add BDI/BNI rows when ready:

```csv
Z031E0047_21MOB_1471_80,/rsstu/.../BDI_BNI_NILS/Z031E0047_21MOB_1471_80_bc2053.fastq.gz,/rsstu/.../BDI_BNI_NILS/Z031E0047_21MOB_1471_80_bc2054.fastq.gz
Z031E0050_2021MOB_1506_10,/rsstu/.../BDI_BNI_NILS/Z031E0050_2021MOB_1506_10_bc2055.fastq.gz,/rsstu/.../BDI_BNI_NILS/Z031E0050_2021MOB_1506_10_bc2056.fastq.gz
```

### Process Flow (per sample)

```
barcode1.fq.gz ─┐
                 ├─→ [MERGE_FASTQ] ─→ [HIFIASM] ─→ [GFA_TO_FASTA]
barcode2.fq.gz ─┘                                        │
                                                          ▼
                                              ┌── [RAGTAG_SCAFFOLD_B73]
                                              │
                                              ├── [RAGTAG_SCAFFOLD_PT]
                                              │
                                              └───────────┬──────────┘
                                                          ▼
                                                  [RAGTAG_MERGE]
                                                          │
                                          ┌───────────────┼───────────────┐
                                          ▼               ▼               ▼
                                    [LIFTOFF]    [DOTPLOT_B73]    [DOTPLOT_PT]
                                                          │               │
                                                          ▼               ▼
                                                  [PLOT_DOTPLOT_R]────────┘
                                                          │
                                              (optional)  ▼
                                              ┌── [ANCHORWAVE_B73]
                                              └── [ANCHORWAVE_PT]
```

### Nextflow DSL2 Structure

```
nextflow/
├── main.nf                  # Entry point, includes all workflows
├── nextflow.config          # Profiles (lsf, local), params, resource defaults
├── samplesheet.csv          # Input sample manifest
├── modules/
│   ├── merge_fastq.nf       # Cat barcodes → merged FASTQ
│   ├── hifiasm.nf           # De novo assembly
│   ├── gfa_to_fasta.nf      # GFA → FASTA conversion
│   ├── ragtag_scaffold.nf   # Scaffold against one reference
│   ├── ragtag_merge.nf      # Merge two scaffoldings
│   ├── liftoff.nf           # Gene annotation transfer
│   ├── dotplot_map.nf       # minimap2 CDS mapping + MAPQ filter + dotplot.tab
│   ├── dotplot_plot.nf      # R plotting from dotplot.tab
│   └── anchorwave.nf        # Optional whole-genome alignment
└── bin/
    ├── alignmentToDotplot.pl # CDS anchor → dotplot table (existing script)
    └── plot_dotplot.R        # R dotplot script (parameterized version)
```

## Process Definitions

### 1. MERGE_FASTQ

```
Input:  tuple val(sample), path(barcode1), path(barcode2)
Output: tuple val(sample), path("${sample}_merged.fastq.gz")
```

```bash
cat ${barcode1} ${barcode2} > ${sample}_merged.fastq.gz
```

Resources: 1 core, 4 GB, 2h (I/O bound)

### 2. HIFIASM

```
Input:  tuple val(sample), path(merged_fastq)
Output: tuple val(sample), path("${sample}_asm.bp.p_ctg.gfa"), emit: gfa
        tuple val(sample), path("${sample}_asm.bp.a_ctg.gfa"), emit: alt_gfa
```

```bash
hifiasm -o ${sample}_asm -t ${task.cpus} -l0 ${merged_fastq}
```

Resources: 16 cores, 64 GB, 16h
Conda: `/share/maize/frodrig4/conda/env/assembly`

### 3. GFA_TO_FASTA

```
Input:  tuple val(sample), path(gfa)
Output: tuple val(sample), path("${sample}.p_ctg.fa")
```

```bash
awk '/^S/{print ">"$2; print $3}' ${gfa} > ${sample}.p_ctg.fa
```

Resources: 1 core, 4 GB, 30min

### 4. RAGTAG_SCAFFOLD (parameterized by reference)

```
Input:  tuple val(sample), path(query_fa), val(ref_name), path(ref_fa)
Output: tuple val(sample), val(ref_name), path("ragtag.scaffold.agp"), path("ragtag.scaffold.fasta")
```

```bash
ragtag.py scaffold -u -t ${task.cpus} -o scaffold_out ${ref_fa} ${query_fa}
cp scaffold_out/ragtag.scaffold.agp .
cp scaffold_out/ragtag.scaffold.fasta .
```

Resources: 8 cores, 32 GB, 6h
Conda: `/share/maize/frodrig4/conda/env/assembly`
Key: `-u` places unlocalized contigs; NO `ragtag correct` (misinterprets Inv4m inversion)

### 5. RAGTAG_MERGE

```
Input:  tuple val(sample), path(query_fa), path(agp_b73), path(agp_pt)
Output: tuple val(sample), path("ragtag.merge.fasta"), path("ragtag.merge.agp")
```

```bash
ragtag.py merge -u -o merge_out ${query_fa} ${agp_b73} ${agp_pt}
cp merge_out/ragtag.merge.fasta .
cp merge_out/ragtag.merge.agp .
```

Resources: 4 cores, 16 GB, 2h
Conda: `/share/maize/frodrig4/conda/env/assembly`

### 6. LIFTOFF

```
Input:  tuple val(sample), path(query_fa)
        path ref_fa
        path ref_gff
Output: tuple val(sample), path("${sample}_liftoff_B73.gff3"), path("${sample}_unmapped_B73.txt")
```

```bash
liftoff \
  -g ${ref_gff} \
  -o ${sample}_liftoff_B73.gff3 \
  -u ${sample}_unmapped_B73.txt \
  -dir intermediate_files \
  -p ${task.cpus} -s 0.5 -a 0.5 -flank 0.1 \
  -cds -copies \
  ${query_fa} ${ref_fa}
```

Resources: 8 cores, 32 GB, 6h
Conda: `/share/maize/frodrig4/conda/env/liftoff`
Key: `-copies` flag for CNV detection at JMJ cluster

### 7. DOTPLOT_MAP (per reference: B73 and PT)

```
Input:  tuple val(sample), path(query_fa), val(ref_name), path(ref_fa), path(ref_gff)
Output: tuple val(sample), val(ref_name), path("dotplot.tab")
```

```bash
# Extract CDS from reference
anchorwave gff2seq -i ${ref_gff} -r ${ref_fa} -o cds.fa

# Map CDS to query
minimap2 -x splice -t ${task.cpus} -k 12 -a -p 0.4 -N 20 ${query_fa} cds.fa > query.sam

# MAPQ>=60 filter
awk '\$1 ~ /^@/ || \$5 >= 60' query.sam > query_mq60.sam

# Generate dotplot table
perl ${projectDir}/bin/alignmentToDotplot.pl ${ref_gff} query_mq60.sam > dotplot.tab
```

Resources: 8 cores, 32 GB, 2h
Conda: `/share/maize/frodrig4/conda/env/anchorwave`
Key: MAPQ>=60 filtering removes multi-mapper noise

**PT reference preprocessing**: The PT FASTA uses `>PT01..PT10` but GFF3 uses
`chr1..chr10`. The pipeline will preprocess PT FASTA with
`sed 's/^>PT0/>chr/; s/^>PT/>chr/'` before CDS extraction. This happens inside
the process (not mutating the shared reference file).

### 8. DOTPLOT_PLOT (R)

```
Input:  tuple val(sample), path(dotplot_tab_b73), path(dotplot_tab_pt)
Output: tuple val(sample), path("*.pdf"), path("*.svg")
```

```bash
Rscript ${projectDir}/bin/plot_dotplot.R \
  --sample ${sample} \
  --tab_b73 ${dotplot_tab_b73} \
  --tab_pt ${dotplot_tab_pt} \
  --outdir .
```

Resources: 1 core, 8 GB, 1h
Conda: `/share/maize/frodrig4/conda/env/r_plotting`

The R script will be parameterized (accept `--sample`, `--tab_b73`, `--tab_pt`,
`--outdir` arguments) instead of hardcoding paths. Produces:
- Whole-genome dotplot vs B73 (PDF+SVG)
- Whole-genome dotplot vs PT (PDF+SVG)
- Chr4 Inv4m zoom side-by-side (PDF+SVG)

### 9. ANCHORWAVE (optional, per reference)

```
Input:  tuple val(sample), path(query_fa), val(ref_name), path(ref_fa), path(ref_gff)
Output: tuple val(sample), val(ref_name), path("*.maf"), path("anchors")
```

```bash
# Fix PT names if needed (same preprocessing as dotplot)
REF=${ref_fa}
if [ "${ref_name}" = "PT" ]; then
  sed 's/^>PT0/>chr/; s/^>PT/>chr/' ${ref_fa} > ref_fixed.fa
  REF=ref_fixed.fa
fi

anchorwave gff2seq -i ${ref_gff} -r \$REF -o cds.fa
minimap2 -x splice -t ${task.cpus} -k 12 -a -p 0.4 -N 20 \$REF cds.fa > ref.sam
minimap2 -x splice -t ${task.cpus} -k 12 -a -p 0.4 -N 20 ${query_fa} cds.fa > query.sam

anchorwave proali \
  -i ${ref_gff} -r \$REF -as cds.fa \
  -a query.sam -ar ref.sam -s ${query_fa} \
  -n anchors \
  -o ${sample}_vs_${ref_name}.maf \
  -f ${sample}_vs_${ref_name}.f.maf \
  -t ${task.cpus} -R 1 -Q 1
```

Resources: 8 cores, 64 GB, 24h
Conda: `/share/maize/frodrig4/conda/env/anchorwave`
Enabled via `params.run_anchorwave = false` (default off)

## Configuration

### nextflow.config

```groovy
params {
    samplesheet    = "${projectDir}/samplesheet.csv"
    outdir         = "/rsstu/users/r/rrellan/tlaloc/nil_pipeline/results"
    ref_b73_fa     = "/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/B73/Zm-B73-REFERENCE-NAM-5.0.fa"
    ref_b73_gff    = "/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/B73/Zm-B73-REFERENCE-NAM-5.0_Zm00001eb.1.gff3"
    ref_pt_fa      = "/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/PT/Zm-PT-REFERENCE-HiLo-1.0.fa"
    ref_pt_gff     = "/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/PT/Zm-PT-REFERENCE-HiLo-1.0_Zm00109aa.1.gff3"
    run_anchorwave = false
}

profiles {
    lsf {
        process.executor       = 'lsf'
        process.clusterOptions = '-R "span[hosts=1]"'
    }
}

process {
    errorStrategy = 'retry'
    maxRetries    = 1
    beforeScript  = 'source /usr/local/apps/miniconda20240526/etc/profile.d/conda.sh'

    withLabel: assembly {
        conda = '/share/maize/frodrig4/conda/env/assembly'
    }
    withLabel: anchorwave {
        conda = '/share/maize/frodrig4/conda/env/anchorwave'
    }
    withLabel: liftoff {
        conda = '/share/maize/frodrig4/conda/env/liftoff'
    }
    withLabel: r_plotting {
        conda = '/share/maize/frodrig4/conda/env/r_plotting'
    }
}

conda.enabled = true

timeline {
    enabled   = true
    file      = "${params.outdir}/pipeline_info/timeline.html"
    overwrite = true
}
report {
    enabled   = true
    file      = "${params.outdir}/pipeline_info/report.html"
    overwrite = true
}
```

### Conda Strategy

The pipeline uses **pre-existing conda environments** on the HPC (not Nextflow-managed
conda). This avoids environment creation overhead and ensures tool versions match
the validated manual runs. A global `beforeScript` sources miniconda's conda.sh so
`conda activate` works inside all LSF jobs. `conda.enabled = true` is set at the
top level. Each label specifies only `conda = '/path/to/env'`.

The config also sets `errorStrategy = 'retry'` with `maxRetries = 1` globally,
which handles transient LSF failures (e.g., node eviction).

## Reference Paths (HPC)

| File | HPC Path |
|------|----------|
| B73 FASTA | `/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/B73/Zm-B73-REFERENCE-NAM-5.0.fa` |
| B73 GFF3 | `/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/B73/Zm-B73-REFERENCE-NAM-5.0_Zm00001eb.1.gff3` |
| PT FASTA | `/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/PT/Zm-PT-REFERENCE-HiLo-1.0.fa` |
| PT GFF3 | `/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/PT/Zm-PT-REFERENCE-HiLo-1.0_Zm00109aa.1.gff3` |

**PT naming quirk:** FASTA headers `>PT01..PT10`, GFF uses `chr1..chr10`.
Handled in-process with `sed 's/^>PT0/>chr/; s/^>PT/>chr/'`.

## Key Design Decisions

1. **No `ragtag correct`** — The Inv4m inversion is misinterpreted as misassembly,
   fragmenting contigs. Skip entirely.
2. **Merge barcodes before assembly** — Same genotype, different library preps.
   Simple `cat` is sufficient (hifiasm handles mixed coverage).
3. **Dual-reference scaffolding** — B73 (NIL background) + PT (standard Inv4m
   arrangement). Merged with `ragtag merge` for consensus.
4. **MAPQ>=60 filtering** on dotplot SAMs — Removes multi-mapper CDS noise from
   duplicated gene families.
5. **Liftoff with `-copies`** — Detects copy-number variation at the JMJ gene
   cluster (Inv4m breakpoint region).
6. **AnchorWave as optional** — Whole-genome alignment is expensive (5h for PT)
   and only needed for SV/CNV cataloguing, not routine QC.

## LSF Resource Estimates

| Process            | Cores | Memory | Wall time | Actual (MI21) |
|--------------------|-------|--------|-----------|---------------|
| MERGE_FASTQ        | 1     | 4 GB   | 2:00      | ~10min        |
| HIFIASM            | 16    | 64 GB  | 16:00     | 3.4h          |
| GFA_TO_FASTA       | 1     | 4 GB   | 0:30      | <1min         |
| RAGTAG_SCAFFOLD    | 8     | 32 GB  | 6:00      | ~1h each      |
| RAGTAG_MERGE       | 4     | 16 GB  | 2:00      | ~30min        |
| LIFTOFF            | 8     | 32 GB  | 6:00      | 23min         |
| DOTPLOT_MAP        | 8     | 32 GB  | 2:00      | ~15min        |
| DOTPLOT_PLOT       | 1     | 8 GB   | 1:00      | ~5min         |
| ANCHORWAVE (opt)   | 8     | 64 GB  | 24:00     | 27min-5h      |

## Output Directory Structure

```
results/
└── {sample}/
    ├── assembly/
    │   ├── {sample}.bp.p_ctg.gfa
    │   └── {sample}.bp.p_ctg.fa
    ├── scaffold/
    │   ├── B73/ragtag.scaffold.{agp,fasta}
    │   ├── PT/ragtag.scaffold.{agp,fasta}
    │   └── merge/ragtag.merge.{agp,fasta}
    ├── liftoff/
    │   ├── {sample}_liftoff_B73.gff3
    │   └── {sample}_unmapped_B73.txt
    ├── dotplot/
    │   ├── dotplot_vs_B73.{pdf,svg,tab}
    │   ├── dotplot_vs_PT.{pdf,svg,tab}
    │   └── chr4_inv4m_dotplot.{pdf,svg}
    └── anchorwave/   (if enabled)
        ├── vs_B73/{sample}_vs_B73.{maf,f.maf}
        └── vs_PT/{sample}_vs_PT.{maf,f.maf}
```

## Implementation Status

All pipeline code is built and located at `nextflow/`. The following are complete:

- [x] `nextflow/` directory structure created
- [x] `samplesheet.csv` with TMEX_inv4m
- [x] `nextflow.config` with LSF profile, conda, timeline/report
- [x] All 9 modules implemented in `modules/`
- [x] `main.nf` wiring all modules with DSL2 includes
- [x] `bin/alignmentToDotplot.pl` copied
- [x] `bin/plot_dotplot.R` parameterized with `optparse` CLI arguments
- [ ] Test with TMEX_inv4m (pending — requires Nextflow on HPC)
- [ ] Add BDI/BNI samples when ready

### Remaining prerequisites

1. **Nextflow availability on HPC**: Need to verify `module avail nextflow` or
   install to a conda env.
2. **First run test**: Submit TMEX_inv4m via `ssh hazel` with the `lsf` profile.
