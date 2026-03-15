#!/usr/bin/env bash
#BSUB -J test_orient_mi21
#BSUB -n 1
#BSUB -R "rusage[mem=8]"
#BSUB -W 15
#BSUB -q sara
#BSUB -o /rsstu/users/r/rrellan/tlaloc/nilhifi/agent/test/orient_mi21/test_orient_mi21.out
#BSUB -e /rsstu/users/r/rrellan/tlaloc/nilhifi/agent/test/orient_mi21/test_orient_mi21.err
set -euo pipefail

PROJ=/rsstu/users/r/rrellan/tlaloc/nilhifi
OUTDIR=$PROJ/agent/test/orient_mi21
SCRIPT=$PROJ/nextflow/bin/orient_scaffolds.py

TAB=/rsstu/users/r/rrellan/DOE_CAREER/inv4m/nilhifimi21/anchorwave/vs_B73/dotplot.tab
FASTA=/rsstu/users/r/rrellan/DOE_CAREER/inv4m/nilhifimi21/ragtag/merge/ragtag.merge.fasta

echo "=== Test 2: orient_scaffolds.py on Mi21 data ==="
echo "Started: $(date)"

python3 "$SCRIPT" \
    --tab "$TAB" \
    --fasta "$FASTA" \
    --sample Mi21 \
    --out-fasta "$OUTDIR/Mi21.oriented.fa" \
    --out-table "$OUTDIR/scaffold_correspondence.tsv"

echo ""
echo "orient_scaffolds.py completed: $(date)"
echo ""

# Run validation — Mi21 also has scf00000010_RagTag as chr4
bash "$PROJ/test/validate_orient.sh" \
    "$OUTDIR/Mi21.oriented.fa" \
    "$OUTDIR/scaffold_correspondence.tsv" \
    "$FASTA" \
    "scf00000010_RagTag"

echo ""
echo "Finished: $(date)"
