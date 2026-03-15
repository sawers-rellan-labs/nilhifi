#!/usr/bin/env bash
#BSUB -J test_dotplot_replot
#BSUB -n 1
#BSUB -R "rusage[mem=8]"
#BSUB -W 15
#BSUB -q sara
#BSUB -o /rsstu/users/r/rrellan/tlaloc/nilhifi/agent/test/dotplot_replot/test_dotplot_replot.out
#BSUB -e /rsstu/users/r/rrellan/tlaloc/nilhifi/agent/test/dotplot_replot/test_dotplot_replot.err
set -euo pipefail

PROJ=/rsstu/users/r/rrellan/tlaloc/nilhifi
OUTDIR=$PROJ/agent/test/dotplot_replot
SCRIPT=$PROJ/nextflow/bin/plot_dotplot.R

TAB_B73=$PROJ/results/TMEX_inv4m/dotplot/dotplot_vs_B73.tab
TAB_PT=$PROJ/results/TMEX_inv4m/dotplot/dotplot_vs_PT.tab

# Activate r_plotting conda env
eval "$(conda shell.bash hook 2>/dev/null)"
conda activate /share/maize/frodrig4/conda/env/r_plotting

echo "=== Test 3: plot_dotplot.R chr4 zoom fix ==="
echo "Started: $(date)"
echo "R version: $(R --version | head -1)"
echo ""

Rscript "$SCRIPT" \
    --sample TMEX_inv4m \
    --tab_b73 "$TAB_B73" \
    --tab_pt "$TAB_PT" \
    --outdir "$OUTDIR"

echo ""
echo "plot_dotplot.R completed: $(date)"
echo ""

# Validate outputs
echo "--- Output file check ---"
PASS=0
FAIL=0
for ext in pdf svg; do
    for name in TMEX_inv4m_dotplot_vs_B73 TMEX_inv4m_dotplot_vs_PT TMEX_inv4m_chr4_inv4m_dotplot; do
        f="$OUTDIR/${name}.${ext}"
        if [ -f "$f" ] && [ -s "$f" ]; then
            SIZE=$(ls -lh "$f" | awk '{print $5}')
            echo "  PASS: $name.$ext ($SIZE)"
            PASS=$((PASS + 1))
        else
            echo "  FAIL: $name.$ext missing or empty"
            FAIL=$((FAIL + 1))
        fi
    done
done

echo ""
echo "=== SUMMARY: $PASS passed, $FAIL failed ==="
echo "Finished: $(date)"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
