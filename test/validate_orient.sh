#!/usr/bin/env bash
# Shared validation for orient_scaffolds.py output
# Usage: bash validate_orient.sh <oriented.fa> <correspondence.tsv> <input.fa> [expected_chr4_scaffold]
set -euo pipefail

ORIENTED_FA="$1"
CORR_TSV="$2"
INPUT_FA="$3"
EXPECTED_CHR4="${4:-}"

PASS=0
FAIL=0

check() {
    local desc="$1" result="$2"
    if [ "$result" = "PASS" ]; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Validating orient_scaffolds.py output ==="
echo "  Oriented FASTA: $ORIENTED_FA"
echo "  Correspondence: $CORR_TSV"
echo "  Input FASTA:    $INPUT_FA"
echo ""

# 1. Check all 10 chromosomes present in FASTA headers
echo "--- Chromosome presence ---"
for i in $(seq 1 10); do
    if grep -q "^>chr${i}$" "$ORIENTED_FA"; then
        check "chr${i} present in FASTA" "PASS"
    else
        check "chr${i} present in FASTA" "FAIL"
    fi
done

# 2. Sequence count matches
echo ""
echo "--- Sequence counts ---"
OUT_COUNT=$(grep -c '^>' "$ORIENTED_FA")
IN_COUNT=$(grep -c '^>' "$INPUT_FA")
echo "  Input sequences:  $IN_COUNT"
echo "  Output sequences: $OUT_COUNT"
check "Sequence count matches ($IN_COUNT == $OUT_COUNT)" "$([ "$IN_COUNT" -eq "$OUT_COUNT" ] && echo PASS || echo FAIL)"

# 3. Total base count matches (revcomp preserves length)
echo ""
echo "--- Base counts ---"
OUT_BASES=$(grep -v '^>' "$ORIENTED_FA" | tr -d '\n' | wc -c)
IN_BASES=$(grep -v '^>' "$INPUT_FA" | tr -d '\n' | wc -c)
echo "  Input bases:  $IN_BASES"
echo "  Output bases: $OUT_BASES"
check "Total base count matches" "$([ "$IN_BASES" -eq "$OUT_BASES" ] && echo PASS || echo FAIL)"

# 4. Correspondence table has 10 assigned chromosomes
echo ""
echo "--- Correspondence table ---"
ASSIGNED=$(awk -F'\t' 'NR>1 && $3 != "-"' "$CORR_TSV" | wc -l)
echo "  Assigned chromosomes: $ASSIGNED"
check "10 chromosomes assigned" "$([ "$ASSIGNED" -eq 10 ] && echo PASS || echo FAIL)"

# 5. Check expected chr4 scaffold if provided
if [ -n "$EXPECTED_CHR4" ]; then
    echo ""
    echo "--- Known assignments ---"
    CHR4_SCF=$(awk -F'\t' '$1 == "chr4"' "$CORR_TSV" | cut -f2)
    echo "  chr4 scaffold: $CHR4_SCF (expected: $EXPECTED_CHR4)"
    check "chr4 = $EXPECTED_CHR4" "$([ "$CHR4_SCF" = "$EXPECTED_CHR4" ] && echo PASS || echo FAIL)"
fi

# 6. FASTA is sorted: chr1 before chr2 before ... chr10 before unplaced
echo ""
echo "--- Sort order ---"
HEADERS=$(grep -m 10 '^>' "$ORIENTED_FA" | sed 's/>//')
EXPECTED_ORDER="chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 chr9 chr10"
ACTUAL_ORDER=$(echo "$HEADERS" | tr '\n' ' ' | sed 's/ $//')
check "Chromosomes in order (chr1..chr10)" "$([ "$ACTUAL_ORDER" = "$EXPECTED_ORDER" ] && echo PASS || echo FAIL)"

# 7. Print correspondence table for review
echo ""
echo "--- Full correspondence table ---"
column -t -s$'\t' "$CORR_TSV"

# Summary
echo ""
echo "=== SUMMARY: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
