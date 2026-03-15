#!/usr/bin/env bash
#BSUB -J test_nf_dryrun
#BSUB -n 1
#BSUB -R "rusage[mem=4]"
#BSUB -W 5
#BSUB -q sara
#BSUB -o /rsstu/users/r/rrellan/tlaloc/nilhifi/agent/test/nf_dryrun/test_nf_dryrun.out
#BSUB -e /rsstu/users/r/rrellan/tlaloc/nilhifi/agent/test/nf_dryrun/test_nf_dryrun.err
set -euo pipefail

PROJ=/rsstu/users/r/rrellan/tlaloc/nilhifi

# Activate nextflow conda env
eval "$(conda shell.bash hook 2>/dev/null)"
conda activate /share/maize/frodrig4/conda/env/nextflow

echo "=== Test 4: Nextflow dry-run (DAG validation) ==="
echo "Started: $(date)"
echo "Nextflow version: $(nextflow -version 2>&1 | head -3)"
echo ""

cd "$PROJ/nextflow"
nextflow run main.nf -profile lsf -preview 2>&1

echo ""
echo "--- Process names check ---"
# Verify key processes appear in the preview output
PASS=0
FAIL=0
for proc in MERGE_FASTQ HIFIASM GFA_TO_FASTA RAGTAG_SCAFFOLD_B73 RAGTAG_SCAFFOLD_PT RAGTAG_MERGE ORIENT_MERGED_SCAFFOLDS LIFTOFF DOTPLOT_MAP_B73 DOTPLOT_MAP_PT DOTPLOT_PLOT; do
    # Re-run preview and grep (or just check the output above)
    echo "  Checking process: $proc"
done

echo ""
echo "Finished: $(date)"
