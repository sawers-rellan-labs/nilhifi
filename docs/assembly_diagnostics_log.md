# Assembly Problem Discussion — 4-Genome Production Run

**Date:** 2026-03-17
**Run:** Orchestrator job 467654 (sara queue, submitted Mon Mar 16 19:28 EDT)
**Samples:** BNI_NIL, BDI_NIL, MI21_NIL, TMEX_NIL

This document records the chain of reasoning from initial dotplot review through
diagnosis, rejected hypotheses, and the final actionable fixes. Written as a lab
notebook for reference when resubmitting jobs.

---

## 1. Initial Dotplot Review

After ORIENT + DOTPLOT completed for BNI, BDI, and MI21 (TMEX still in RAGTAG),
the dotplots were inspected. Two categories of problems were found: labeling bugs
and genuine assembly/scaffolding anomalies.

### Labeling bugs (cosmetic, already fixed in repo)

- All ref2 dotplots labeled **"PT"** regardless of the actual reference. BNI and
  BDI should say "parviglumis", TMEX should say "mexicana". Cause: the running
  pipeline used the old `--tab_pt` R script flag. The fix (`--tab_ref2` +
  `--ref2_name` + `find_dominant_scaffold()`) was already in the repo but hadn't
  been loaded by the running Nextflow orchestrator (it caches `bin/` at launch).

- The chr4 zoom panel used a hardcoded `scaffold_10 → chr4` mapping from the
  original TMEX test run. Now uses dynamic scaffold-chromosome correspondence
  derived from anchor density.

### Chromosome anomalies observed in dotplots

**BDI_NIL:**
- chr4: inverted relative to B73, labeled as `scf00000012_RagTag` instead of
  `chr4`. Clearly has chr4 content (~150 Mb of synteny) but was not renamed or
  oriented by the orient step.
- chr9: very short (~47 Mb visible in dotplot vs expected ~150 Mb).
- Overall: the whole-genome dotplot had more noise and unplaced scaffolds than
  BNI or MI21.

**BNI_NIL:**
- chr2: very short (~68 Mb vs expected ~230 Mb).
- chr8: missing synteny in B73 coordinates 0–50 Mb. The BNI chr8 shows a small
  abnormal inverted section at the start (50–100 Mb region).

**MI21_NIL:**
- Clean. All 10 chromosomes well-assigned with 1000–3500 anchors each.

---

## 2. Orient Script Bug — Root Cause of BDI chr4

### What happened

The orient script (`orient_scaffolds.py`) assigns scaffolds to B73 chromosomes
by mapping B73 CDS to the merged assembly and counting anchor hits. It then
renames the best scaffold for each chromosome to `chr1`–`chr10`, flipping
orientation if needed.

For BDI_NIL, the orient log showed:

```
scf00000001_RagTag -> chr1 (2974+/0-) ok
scf00000006_RagTag -> chr2 (1863+/0-) ok
scf00000009_RagTag -> chr3 (1751+/0-) ok
scf00000002_RagTag -> chr4 (2+/1-)    ok        ← 3 anchors!
scf00000039_RagTag -> chr5 (14+/2754-) FLIPPED
scf00000040_RagTag -> chr6 (2+/2426-) FLIPPED
scf00000041_RagTag -> chr7 (2378+/0-) ok
scf00000042_RagTag -> chr8 (0+/2750-) FLIPPED
scf00000045_RagTag -> chr9 (0+/1011-) FLIPPED
scf00000003_RagTag -> chr10 (2068+/0-) ok
10 scaffolds assigned to chromosomes, 2394 unplaced
```

`scf00000002_RagTag` (81 MB) got chr4 with **only 3 CDS anchors**. Meanwhile,
`scf00000012_RagTag` (150.7 MB, the real chr4 content with 1327 anchors in the
dotplot) was left in the 2394 unplaced scaffolds — keeping its scaffold name,
never oriented.

### Why the greedy algorithm failed

The old algorithm (lines 91–114):

1. Sort scaffolds by **total CDS hit count across ALL chromosomes** (descending)
2. For each scaffold, assign it to the best **remaining** chromosome

`scf00000002_RagTag` is an 81 MB chimeric scaffold from ragtag merge. It contains
contigs like `ptg000005l` (33.8 MB), `ptg000044l` (22 MB), etc. — pieces of
multiple chromosomes. Its **total** CDS hit count (summed across all chromosomes)
is high, so it gets processed early in the queue.

By the time `scf00000002_RagTag` is processed, all the chromosomes where it has
real content (chr1, chr5, etc.) are already assigned to their correct scaffolds.
The only remaining chromosome is chr4, and scf00000002 has 3 hits for chr4. The
threshold was `> 0`, so it takes chr4.

When `scf00000012_RagTag` (the real chr4, 1327 anchors) is finally processed,
chr4 is already taken. It becomes unplaced.

### The fix

Replaced the per-scaffold greedy algorithm with a **per-chromosome best-scaffold**
approach:

1. For each B73 chromosome, collect all scaffolds with ≥ 50 CDS anchors
2. Sort candidates by hit count descending
3. Process chromosomes in order of their best candidate's strength
4. Assign the top unassigned scaffold to each chromosome

Validated against BDI_NIL orient data:

```
OLD: scf00000002_RagTag -> chr4 (2+/1-)    [3 anchors, 81 MB chimeric]
NEW: scf00000012_RagTag -> chr4 (8+/1319-) [1327 anchors, 150 MB, FLIPPED]
```

All other chromosome assignments unchanged. The chimeric `scf00000002_RagTag`
correctly becomes unplaced (doesn't meet the 50-anchor threshold for any single
chromosome).

**File changed:** `nextflow/bin/orient_scaffolds.py`

---

## 3. Ragtag Merge Failure — Why BDI chr4 Was Dropped

### What ragtag merge did

The merge step combines scaffolding from two references (B73 + parviglumis for
BDI) into a consensus. I checked both individual scaffoldings:

**B73 scaffold AGP — chr4:**
```
chr4_RagTag  ...  ptg000023l  1  150615076  -   (at position 43.5–194.2 Mb)
```

**Parviglumis scaffold AGP — chr4:**
```
chr4_RagTag  ...  ptg000023l  1  150615076  -   (at position 45.7–196.3 Mb)
```

**Both references agree:** `ptg000023l` (150.6 MB) belongs in chr4, in minus
orientation. The positioning differs slightly (43.5 vs 45.7 Mb start) but the
contig and chromosome are the same.

**Yet the merge output placed `ptg000023l` as unplaced** (`scf00000012_RagTag`).

### Why merge dropped it

The merged chr4 (`scf00000002_RagTag`, 81 MB) contains completely different
contigs:

```
scf00000002_RagTag:
  ptg000014l  (9.4 MB)
  ptg000229l  (1.9 MB)
  ptg000034l  (3.9 MB)
  ptg000005l  (33.8 MB)
  ptg000066l  (3.3 MB)
  ptg000053l  (5.4 MB)
  ptg000044l  (22.1 MB)
  ptg000104l  (1.5 MB)
```

None of these are the main chr4 contig. The merge scaffold graph (a beta feature
of ragtag — it prints `WARNING: This is a beta version of ragtag merge` on every
run) likely had conflicting edges from the 2510 small contigs. When constructing
the merged graph, contigs that appeared in different orders or orientations between
the two scaffoldings create cycles. Ragtag merge resolves cycles conservatively by
dropping contigs — and the 150 MB `ptg000023l` got dropped.

### Why BDI has 2510 contigs

This is the key question. The other samples:

| Sample | Primary contigs | RAGTAG memory (B73/ref2) |
|--------|----------------|-------------------------|
| MI21_NIL | 740 | 66 / 70 GB |
| TMEX_NIL | 1043 | 111 / running |
| BNI_NIL | 1290 | 95 / 105 GB |
| BDI_NIL | **2510** | **136 / 144 GB** |

BDI's contig count is 2–3.4x higher than the other samples. More contigs =
more edges in the merge scaffold graph = more conflicts = more dropped contigs.
Also more memory consumed by RAGTAG (which exceeded 128 GB on both runs).

---

## 4. Initial Hypothesis: Haplotig Retention

### The reasoning

With 2510 primary contigs from hifiasm `-l0` (purge-dups disabled), the initial
hypothesis was **haplotig retention**: hifiasm keeping both haplotype copies as
separate contigs instead of collapsing them.

For inbred NILs, `-l0` is appropriate because there should be minimal
heterozygosity. But near the introgression boundary (the inv4m region where the
wild relative genome meets the B73 background), there could be residual
heterozygosity. If hifiasm sees two distinct haplotypes in that region, it emits
both as separate primary contigs.

This would explain:
- Inflated contig count (duplicated regions appear twice)
- Ragtag merge confusion (two contigs covering the same genomic region compete
  for placement, creating conflicting edges)
- The high memory usage (more sequence to align)

### Suggested fixes under this hypothesis

1. **purge_dups post-processing** — identify and remove haplotig duplicates
   based on read depth, then re-run from RAGTAG onward
2. **hifiasm `-l 2` or `-l 3`** — re-run assembly with aggressive purging
   (re-runs the most expensive step, ~4.7h for BDI)
3. **Increase RAGTAG memory to 192 GB** — doesn't fix root cause but prevents
   memory exceedance
4. **Skip ragtag merge for BDI** — use B73-only scaffold as a workaround

---

## 5. Testing the Hypothesis: Assembly Size Check

### Method

If haplotigs are retained, the total primary assembly size should be significantly
larger than the expected haploid genome size (~2.3 Gb for maize). A fully retained
diploid would be ~4.6 Gb; partial retention would fall somewhere between 2.3 and
4.6 Gb.

Extracted total assembly size and contig statistics from the hifiasm GFA files:

```bash
awk '/^S/{n++; len+=length($3)} END{...}' *.p_ctg.gfa
```

### Results

| Sample | Contigs | Total size | vs expected | N50 | Largest contig |
|--------|---------|-----------|-------------|-----|---------------|
| MI21_NIL | 740 | 2.21 Gb | -4% | 13.7 Mb | 48 Mb |
| TMEX_NIL | 1043 | 2.24 Gb | -3% | 31.3 Mb | 174 Mb |
| BNI_NIL | 1290 | 2.28 Gb | -1% | 19.4 Mb | 87 Mb |
| BDI_NIL | 2510 | 2.32 Gb | +1% | 68.7 Mb | 187 Mb |

### Interpretation

**Haplotig retention is ruled out.** All four assemblies are within 1–4% of the
expected ~2.3 Gb haploid size. If haplotigs were retained, BDI would be 3–4+ Gb.

BDI is paradoxical: it has the **best** contiguity metrics (N50 = 68.7 Mb,
largest contig = 187 Mb) but the **most** contigs (2510). This means the assembly
has a few very large, high-quality chromosome-scale contigs plus a long tail of
~2400 small fragments. These small fragments are likely:

- Repetitive/centromeric sequences that hifiasm couldn't place
- Organellar contaminants (mitochondrial/chloroplast)
- Low-complexity junk from read errors

The total size of these small fragments is modest — the difference between BDI
(2.32 Gb) and MI21 (2.21 Gb) is only ~110 Mb, which is within normal assembly
variation for maize.

### Why BDI fragments despite good contiguity

BDI has the largest input (19.0 GB FASTQ) and highest hifiasm memory usage
(46 GB). Higher coverage can produce better large contigs (higher N50) while
simultaneously generating more small noise contigs from repetitive regions that
get multiple overlapping assemblies. The contigs are real sequence — just not
useful for scaffolding.

### Impact on the diagnosis

- **purge_dups: would NOT help.** There are no haplotigs to purge. The total
  assembly size is correct.
- **hifiasm `-l 2`: would NOT help.** Same reasoning — no duplicates to remove.
- **The 2510 small contigs are the problem for ragtag merge, but not because
  they're duplicates.** They create noise in the merge scaffold graph, causing
  edge conflicts that lead to large contigs being dropped.

---

## 6. Revised Diagnosis and Fixes

### BDI_NIL chr4 — two independent problems, both now addressed

1. **Ragtag merge dropped `ptg000023l` from chr4** despite both references
   agreeing on its placement. Root cause: the 2510 contigs created a noisy
   merge scaffold graph. The merge (beta feature) resolved conflicts
   conservatively by dropping the contig. **No code fix available** — this is
   a limitation of ragtag merge with fragmented assemblies.

2. **Orient script assigned the wrong scaffold to chr4.** The chimeric
   `scf00000002_RagTag` (81 MB, 3 anchors) stole the chr4 assignment from
   `scf00000012_RagTag` (150 MB, 1327 anchors). **Fixed** with per-chromosome
   best-scaffold algorithm and 50-anchor minimum threshold.

With the orient fix applied, the `-resume` will correctly assign
`scf00000012_RagTag` to chr4 and flip it to match B73 orientation. The
underlying scaffold is the same (the merge still dropped it from the merged
chr4 scaffold), but it will now be named `chr4` and oriented correctly in the
output FASTA. The dotplot should then show a clean, properly oriented chr4.

### BDI_NIL chr9 — undersized (47 MB)

`scf00000045_RagTag` was assigned to chr9 with 1011 anchors. The orient fix
doesn't change this assignment (1011 > 50 threshold, and it's the best scaffold
for chr9). The undersized chr9 is a ragtag merge issue — chr9 content is likely
split across multiple scaffolds that the merge didn't join.

**Fix:** Check the B73-only scaffold to see if chr9 is intact there. If so,
skipping the merge step for BDI would fix both chr4 and chr9.

### BNI_NIL chr2 and chr8 — genuine assembly gaps

- chr2 (68 MB): correctly assigned, just undersized. The missing ~160 MB of
  chr2 content was not assembled by hifiasm. Total assembly size (2.28 Gb)
  is slightly under expected, consistent with missing content.
- chr8: assigned correctly (1780 anchors, 234 MB), but the 0–50 MB region
  of B73 chr8 has no synteny. An abnormal small inverted section at the start.

These are hifiasm assembly limitations, not scaffolding or orient bugs. No
pipeline fix will recover missing sequence. Would require additional sequencing
or alternative assembler (e.g., hifiasm with Hi-C data for phasing) to improve.

**No action needed** — the orient fix ensures correct chromosome naming. The
gaps will be visible in downstream analyses (liftoff, anchorwave) and should
be documented as assembly limitations.

---

## 7. Action Plan for Resubmission

### What's already done (code changes in repo, not yet run)

1. `orient_scaffolds.py` — per-chromosome best-scaffold, min 50 anchors
2. `plot_dotplot.R` — dynamic ref2 labels, dynamic scaffold correspondence
3. `dotplot_plot.nf` — extracts ref2 name from tab filename

### When the current run finishes

The current run is completing ANCHORWAVE (all 6 jobs PEND, blocked by TMEX
RAGTAG_REF2 still running). After it finishes:

**Option A: Simple `-resume` (recommended first)**

```bash
cd /rsstu/users/r/rrellan/tlaloc/nilhifi/nextflow && bsub < q_nil_assembly_pipeline.sh
```

This re-runs ORIENT → DOTPLOT → LIFTOFF → ANCHORWAVE for all 4 samples
(orient script changed = cascade invalidation). HIFIASM, GFA_TO_FASTA,
RAGTAG, and MERGE are cached.

After this, check:
- BDI chr4: should now be `chr4` (not `scf00000012_RagTag`), oriented to
  match B73
- BDI chr9: still likely undersized (merge problem, not orient)
- BNI chr2/chr8: unchanged (assembly gaps)
- All ref2 labels correct in dotplots

**Option B: Skip merge for BDI (if chr9 is still broken after Option A)**

Would require modifying `main.nf` to use the B73-only scaffold output for
BDI_NIL instead of the merged scaffold. This is a per-sample override — the
other three samples would continue using the merge path.

Before implementing, verify BDI's B73-only scaffold has good chr9:

```bash
# Find BDI B73 scaffold work dir
# Hash from orchestrator log: fd/7b84bc
grep "chr9" results/work/fd/7b84bc*/scaffold_out/ragtag.scaffold.agp
```

If chr9 is well-placed in the B73-only scaffold (with the full ~150 MB of
content), then skipping merge for BDI is the right call.

**Option C: Bump RAGTAG memory to 192 GB (independent of A/B)**

BDI exceeded 128 GB (136/144 GB actual). Bump to 192 GB in
`nextflow/modules/ragtag_scaffold.nf` before any resubmission. This is a
safety measure — it won't fix the merge problem but prevents silent
corruption from memory pressure on future runs. Note: changing the memory
directive does NOT invalidate the Nextflow cache (only script/input changes
do), so existing RAGTAG results stay cached.

---

## 8. Open Questions

1. **What does BDI chr9 look like in the B73-only scaffold?** If the B73
   scaffold has a full chr9, the merge step is solely to blame and skipping
   it is justified.

2. **Is the BNI chr8 0–50 Mb gap visible in the B73 scaffold too, or did
   the merge step create it?** Check the B73-only scaffold to distinguish
   assembly gap from scaffolding artifact.

3. **TMEX_NIL assembly quality** — not yet evaluated. TMEX had 1043 contigs
   (moderate). It ran clean in the single-sample test, but that was with PT
   as ref2; this run uses mexicana. Check dotplots after completion.

4. **ANCHORWAVE on the broken BDI assembly** — the currently running
   ANCHORWAVE jobs use the pre-fix oriented FASTA (with chr4 misassigned).
   These results will be meaningless for BDI chr4/chr9. They'll be
   re-executed on `-resume` anyway.

---

*Written: 2026-03-17, during 4-genome production run analysis.*
