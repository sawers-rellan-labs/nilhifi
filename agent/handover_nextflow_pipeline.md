# Handover: Nextflow Pipeline for NIL Assemblies

## What was done this session

1. **SMB mount setup** — Configured auto-mount of rrellan group folder to `~/mnt/rrellan` via `scripts/mount_rrellan.sh` + LaunchAgent + `.zshrc` trigger. Mount uses `oitrspprd.hpc.ncsu.edu` (not `rsstu.unity.ncsu.edu`).

2. **Permissions and sandbox** — Updated `.claude/settings.json` with:
   - Read/Write scoped to SMB mount paths (not HPC paths)
   - Bash permissions for SSH-prefixed LSF and conda commands (`ssh hazel "..."`)
   - macOS seatbelt sandbox enabled with write restricted to project folder only
   - SSH excluded from sandbox (falls back to permission rules)
   - Sara's raw data deny-listed for writes

3. **Documentation** — Updated `agent/hpc_claude_code_setup.md` and `agent/mac_smb_mount_setup.md` to reflect the active local+SMB+SSH architecture.

## What the next agent needs to do

### Task: Plan and build a Nextflow pipeline for the NIL assembly workflow

**Pipeline stages (in order):**
1. Merge replicate barcodes per genotype (cat FASTQs)
2. hifiasm de novo assembly (`-l0 -t 16`)
3. GFA → FASTA conversion
4. ragtag scaffold vs B73 + vs PT (dual reference, NO `ragtag correct`)
5. ragtag merge
6. liftoff gene annotation transfer (B73 → assembly)
7. CDS-based dotplots (minimap2 CDS mapping + alignmentToDotplot.pl + R plotting)
8. **Optional:** anchorwave proali whole-genome alignment (for CNV/SV cataloguing — make this a flag)

### Samples to process

**Immediate (Inv4m NILs):**

| Genotype | Barcodes | FASTQs | Status |
|----------|----------|--------|--------|
| MI21_inv4m | bc2051 + bc2052 | `MI21_inv4m_bc2051.fastq.gz`, `MI21_inv4m_bc2052.fastq.gz` | DONE (N50=13.7 Mb) |
| TMEX_inv4m | bc2049 + bc2050 | `TMEX_inv4m_bc2049.fastq.gz`, `TMEX_inv4m_bc2050.fastq.gz` | NOT YET ASSEMBLED |

Raw data: `/rsstu/users/r/rrellan/sara/DNA_Sequencing_raw/Inv4mNILS/`

**Deferred (BDI/BNI NILs):**

| Genotype | Barcodes | FASTQs | Status |
|----------|----------|--------|--------|
| 2 BNI/BDI genotypes | UNKNOWN | UNKNOWN | FASTQs transferred, filenames not shared |

Raw data: `/rsstu/users/r/rrellan/sara/DNA_Sequencing_raw/BDI_BNI_NILS/`
**Action needed:** `ssh hazel "ls /rsstu/users/r/rrellan/sara/DNA_Sequencing_raw/BDI_BNI_NILS/"` to get filenames.

### Reference genomes (HPC paths)

- B73: `/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/B73/Zm-B73-REFERENCE-NAM-5.0.fa`
- B73 GFF3: `/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/B73/Zm-B73-REFERENCE-NAM-5.0_Zm00001eb.1.gff3`
- PT: `/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/PT/Zm-PT-REFERENCE-HiLo-1.0.fa`
- PT GFF3: `/rsstu/users/r/rrellan/DOE_CAREER/inv4m/synteny/ref/PT/Zm-PT-REFERENCE-HiLo-1.0_Zm00109aa.1.gff3`

**PT naming quirk:** FASTA uses `>PT01..PT10` but GFF3 uses `chr1..chr10`. Needs `sed 's/^>PT0/>chr/; s/^>PT/>chr/'` preprocessing.

### Conda environments (HPC paths)

| Step | Environment |
|------|-------------|
| hifiasm, ragtag | `/share/maize/frodrig4/conda/env/assembly` |
| anchorwave | `/share/maize/frodrig4/conda/env/anchorwave` |
| liftoff | `/share/maize/frodrig4/conda/env/liftoff` |
| R dotplots | `/share/maize/frodrig4/conda/env/r_plotting` |

**Conda init:** All jobs need `source /usr/local/apps/miniconda20240526/etc/profile.d/conda.sh` before `conda activate`.

### LSF resource requirements (from bc205X run)

| Job | Cores | Memory | Wall time | Actual |
|-----|-------|--------|-----------|--------|
| hifiasm | 16 | 64 GB | 16h | 3.4h |
| ragtag (B73+PT+merge) | 8 | 32 GB | 6h | 2h |
| liftoff | 8 | 32 GB | 6h | 23min |
| dotplot (R) | 1 | 8 GB | 1h | ~15min |
| anchorwave vs B73 | 8 | 64 GB | 24h | 27min |
| anchorwave vs PT | 8 | 64 GB | 24h | 5h |

### Key design decisions to preserve

1. **Skip `ragtag correct`** — Inv4m inversion is misinterpreted as misassembly, fragments contigs
2. **Merge barcodes before assembly** — same genotype, different library preps
3. **Dual reference scaffolding** — B73 (NIL background) + PT (standard Inv4m)
4. **MAPQ≥60 filtering** on dotplot SAM files to remove multi-mapper noise
5. **Liftoff with `-copies`** flag for CNV detection at JMJ cluster

### First steps for the next agent

1. **Test the SSH debugging setup** — run exploratory commands via `ssh hazel "..."`:
   - Check if Nextflow is available: `ssh hazel "which nextflow"` or `ssh hazel "module avail nextflow"`
   - List BDI/BNI FASTQs: `ssh hazel "ls -lh /rsstu/users/r/rrellan/sara/DNA_Sequencing_raw/BDI_BNI_NILS/"`
   - Verify conda envs: `ssh hazel "ls /share/maize/frodrig4/conda/env/"`
2. **Explore input data** via SMB mount (local reads, no SSH needed):
   - `ls ~/mnt/rrellan/sara/DNA_Sequencing_raw/Inv4mNILS/`
   - `ls ~/mnt/rrellan/sara/DNA_Sequencing_raw/BDI_BNI_NILS/`
3. **Read existing scripts** for exact commands to translate to Nextflow processes:
   - `scripts/assemble.sh`, `scripts/build_scaffold.sh`, `scripts/liftoff_B73_to_Mi21.sh`
   - `scripts/anchorwave_vs_B73.sh`, `scripts/run_dotplot.sh`, `scripts/plot_dotplot.R`
4. **Path translation rule**: files found at `~/mnt/rrellan/X` on the laptop correspond to `/rsstu/users/r/rrellan/X` on the HPC. Nextflow scripts run on the HPC, so all paths in Nextflow processes must use `/rsstu/...` paths.
5. **Write the plan** to `agent/` folder, then build the Nextflow pipeline

### How this session's remote setup works

- **File I/O**: Read/write files via SMB mount at `~/mnt/rrellan/`
- **HPC commands**: All via `ssh hazel "..."` (SSH alias defined in `~/.ssh/config`)
- **ControlMaster**: SSH connections multiplex over one socket for 60 minutes
- **Sandbox**: macOS seatbelt restricts writes to project folder only
- **Permissions**: See `.claude/settings.json` for pre-approved commands
- **Deny rules**: `rm -rf` and `mv` via SSH are always blocked (deny overrides allow)
- **Git**: All git commands must go through SSH (`ssh hazel "cd /rsstu/... && git ..."`), NOT locally on the SMB mount
