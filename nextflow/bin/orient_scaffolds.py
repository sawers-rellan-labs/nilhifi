#!/usr/bin/env python3
"""
Orient and rename merged ragtag scaffolds to match B73 chromosome convention.

Reads a dotplot.tab (from alignmentToDotplot.pl) which has:
  col1=refChr  col2=refPos  col3=queryChr  col4=queryPos  col5=strand

For each scaffold:
1. Find the B73 chromosome with the most CDS anchor hits
2. If minus-strand hits dominate for that chromosome, reverse-complement
3. Rename to chr1..chr10; unassigned scaffolds keep original names

Outputs:
  - Oriented FASTA with chr1..chr10 names
  - Correspondence table (TSV)
"""

import argparse
import sys
from collections import defaultdict


def reverse_complement(seq):
    comp = str.maketrans("ACGTacgtNnMRWSYKVHDBmrwsykvhdb",
                         "TGCAtgcaNnKYWSRMBDHVkywsrmbdhv")
    return seq.translate(comp)[::-1]


def read_fasta(path):
    """Read FASTA into dict of {name: sequence}."""
    seqs = {}
    name = None
    chunks = []
    with open(path) as f:
        for line in f:
            line = line.rstrip('\n')
            if line.startswith('>'):
                if name is not None:
                    seqs[name] = ''.join(chunks)
                name = line[1:].split()[0]
                chunks = []
            else:
                chunks.append(line)
    if name is not None:
        seqs[name] = ''.join(chunks)
    return seqs


def write_fasta(path, name, seq, line_width=80):
    """Append one sequence to FASTA file."""
    with open(path, 'a') as f:
        f.write(f'>{name}\n')
        for i in range(0, len(seq), line_width):
            f.write(seq[i:i+line_width] + '\n')


def main():
    parser = argparse.ArgumentParser(
        description="Orient and rename scaffolds to B73 chromosome convention")
    parser.add_argument("--tab", required=True,
                        help="dotplot.tab from alignmentToDotplot.pl (B73 CDS vs assembly)")
    parser.add_argument("--fasta", required=True,
                        help="Merged assembly FASTA")
    parser.add_argument("--sample", required=True,
                        help="Sample name")
    parser.add_argument("--out-fasta", required=True,
                        help="Output oriented FASTA")
    parser.add_argument("--out-table", required=True,
                        help="Output correspondence TSV")
    args = parser.parse_args()

    chrlevels = [f"chr{i}" for i in range(1, 11)]

    # Parse dotplot.tab: scaffold -> b73_chr -> {'+': n, '-': n}
    counts = defaultdict(lambda: defaultdict(lambda: {'+': 0, '-': 0}))
    with open(args.tab) as f:
        for line in f:
            fields = line.rstrip('\n').split('\t')
            if len(fields) < 5:
                continue
            b73_chr = fields[0]
            scaffold = fields[2]
            strand = fields[4]
            if b73_chr in chrlevels and strand in ('+', '-'):
                counts[scaffold][b73_chr][strand] += 1

    # For each scaffold, find dominant B73 chromosome
    assignments = {}  # scaffold -> (b73_chr, total_hits, plus, minus, flip)
    used_chrs = set()

    # Sort scaffolds by total hit count (greedy assignment)
    scaffold_totals = []
    for scf, chr_counts in counts.items():
        total = sum(c['+'] + c['-'] for c in chr_counts.values())
        scaffold_totals.append((scf, total))
    scaffold_totals.sort(key=lambda x: -x[1])

    for scf, _ in scaffold_totals:
        # Find best B73 chromosome not yet assigned
        best_chr = None
        best_total = 0
        for b73_chr in chrlevels:
            if b73_chr in used_chrs:
                continue
            t = counts[scf][b73_chr]['+'] + counts[scf][b73_chr]['-']
            if t > best_total:
                best_total = t
                best_chr = b73_chr
        if best_chr and best_total > 0:
            plus = counts[scf][best_chr]['+']
            minus = counts[scf][best_chr]['-']
            flip = minus > plus
            assignments[scf] = (best_chr, best_total, plus, minus, flip)
            used_chrs.add(best_chr)

    # Read assembly FASTA
    print(f"Reading {args.fasta}...", file=sys.stderr)
    seqs = read_fasta(args.fasta)

    # Clear output FASTA
    open(args.out_fasta, 'w').close()

    # Write correspondence table and FASTA sorted: chr1..chr10, then unplaced alphabetically
    with open(args.out_table, 'w') as table:
        table.write("new_name\told_scaffold\tb73_chromosome\tlength\tplus_anchors\tminus_anchors\tflipped\n")

        # Assigned scaffolds in chr1..chr10 order
        scf_by_chr = {v[0]: k for k, v in assignments.items()}
        for chrname in chrlevels:
            if chrname not in scf_by_chr:
                continue
            scf = scf_by_chr[chrname]
            b73_chr, total, plus, minus, flip = assignments[scf]
            seq = seqs[scf]
            if flip:
                seq = reverse_complement(seq)
            write_fasta(args.out_fasta, chrname, seq)
            table.write(f"{chrname}\t{scf}\t{b73_chr}\t{len(seq)}\t{plus}\t{minus}\t{flip}\n")
            print(f"  {scf} -> {chrname} ({plus}+/{minus}-) {'FLIPPED' if flip else 'ok'}",
                  file=sys.stderr)

        # Unplaced scaffolds sorted alphabetically
        unplaced = sorted(scf for scf in seqs if scf not in assignments)
        for scf in unplaced:
            write_fasta(args.out_fasta, scf, seqs[scf])
            table.write(f"{scf}\t{scf}\t-\t{len(seqs[scf])}\t0\t0\tFalse\n")

        print(f"{len(assignments)} scaffolds assigned to chromosomes, "
              f"{len(unplaced)} unplaced", file=sys.stderr)

    print(f"Wrote {args.out_fasta} and {args.out_table}", file=sys.stderr)


if __name__ == "__main__":
    main()
