#!/usr/bin/env bash
#BSUB -J test_orient_tmex
#BSUB -n 1
#BSUB -R "rusage[mem=8]"
#BSUB -W 15
#BSUB -q sara
#BSUB -o /rsstu/users/r/rrellan/tlaloc/nilhifi/agent/test/orient_tmex/test_orient_tmex.out
#BSUB -e /rsstu/users/r/rrellan/tlaloc/nilhifi/agent/test/orient_tmex/test_orient_tmex.err
set -euo pipefail

PROJ=/rsstu/users/r/rrellan/tlaloc/nilhifi
OUTDIR=$PROJ/agent/test/orient_tmex
SCRIPT=$PROJ/nextflow/bin/orient_scaffolds.py

TAB=$PROJ/results/TMEX_inv4m/dotplot/dotplot_vs_B73.tab
FASTA=$PROJ/results/TMEX_inv4m/scaffold/merge/ragtag.merge.fasta

echo "=== Test 1: orient_scaffolds.py on TMEX data ==="
echo "Started: $(date)"

python3 "$SCRIPT" \
    --tab "$TAB" \
    --fasta "$FASTA" \
    --sample TMEX_inv4m \
    --out-fasta "$OUTDIR/TMEX_inv4m.oriented.fa" \
    --out-table "$OUTDIR/scaffold_correspondence.tsv"

echo ""
echo "orient_scaffolds.py completed: $(date)"
echo ""

# Run validation
bash "$PROJ/test/validate_orient.sh" \
    "$OUTDIR/TMEX_inv4m.oriented.fa" \
    "$OUTDIR/scaffold_correspondence.tsv" \
    "$FASTA" \
    "scf00000010_RagTag"

echo ""
echo "Finished: $(date)"
