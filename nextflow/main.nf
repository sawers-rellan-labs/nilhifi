#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

// --- Module imports ---
include { MERGE_FASTQ      } from './modules/merge_fastq'
include { HIFIASM           } from './modules/hifiasm'
include { GFA_TO_FASTA      } from './modules/gfa_to_fasta'
include { RAGTAG_SCAFFOLD as RAGTAG_SCAFFOLD_B73 } from './modules/ragtag_scaffold'
include { RAGTAG_SCAFFOLD as RAGTAG_SCAFFOLD_PT  } from './modules/ragtag_scaffold'
include { RAGTAG_MERGE      } from './modules/ragtag_merge'
include { ORIENT_MERGED_SCAFFOLDS } from './modules/orient_merged_scaffolds'
include { LIFTOFF           } from './modules/liftoff'
include { DOTPLOT_MAP as DOTPLOT_MAP_B73 } from './modules/dotplot_map'
include { DOTPLOT_MAP as DOTPLOT_MAP_PT  } from './modules/dotplot_map'
include { DOTPLOT_PLOT      } from './modules/dotplot_plot'
include { ANCHORWAVE as ANCHORWAVE_B73 } from './modules/anchorwave'
include { ANCHORWAVE as ANCHORWAVE_PT  } from './modules/anchorwave'

// --- Main workflow ---
workflow {

    // Parse sample sheet
    Channel
        .fromPath(params.samplesheet)
        .splitCsv(header: true)
        .map { row -> tuple(row.sample, file(row.barcode1), file(row.barcode2)) }
        .set { samples_ch }

    // Reference files
    ref_b73_fa  = file(params.ref_b73_fa)
    ref_b73_gff = file(params.ref_b73_gff)
    ref_pt_fa   = file(params.ref_pt_fa)
    ref_pt_gff  = file(params.ref_pt_gff)

    // 1. Merge barcodes
    MERGE_FASTQ(samples_ch)

    // 2. De novo assembly
    HIFIASM(MERGE_FASTQ.out)

    // 3. GFA → FASTA
    GFA_TO_FASTA(HIFIASM.out.gfa)

    // 4. Scaffold against B73 and PT (in parallel)
    scaffold_b73_in = GFA_TO_FASTA.out.map { sample, fa -> tuple(sample, fa, 'B73', ref_b73_fa) }
    scaffold_pt_in  = GFA_TO_FASTA.out.map { sample, fa -> tuple(sample, fa, 'PT',  ref_pt_fa)  }

    RAGTAG_SCAFFOLD_B73(scaffold_b73_in)
    RAGTAG_SCAFFOLD_PT(scaffold_pt_in)

    // 5. Merge scaffoldings
    b73_scaffold = RAGTAG_SCAFFOLD_B73.out.map { sample, ref_name, agp, fasta -> tuple(sample, agp, fasta) }
    pt_scaffold  = RAGTAG_SCAFFOLD_PT.out.map  { sample, ref_name, agp, fasta -> tuple(sample, agp, fasta) }

    merge_in = GFA_TO_FASTA.out
        .join(b73_scaffold)
        .join(pt_scaffold)

    RAGTAG_MERGE(merge_in)

    // 6. Orient scaffolds to B73 convention, rename to chr1..chr10, sort
    ORIENT_MERGED_SCAFFOLDS(RAGTAG_MERGE.out, ref_b73_fa, ref_b73_gff)

    // Oriented FASTA for all downstream steps: [sample, oriented_fasta]
    oriented_fa = ORIENT_MERGED_SCAFFOLDS.out.map { sample, fasta, table -> tuple(sample, fasta) }

    // 7. Liftoff (B73 annotations → query)
    LIFTOFF(oriented_fa, ref_b73_fa, ref_b73_gff)

    // 8. CDS-based dotplots (B73 and PT, in parallel)
    dotplot_b73_in = oriented_fa.map { sample, fa -> tuple(sample, fa, 'B73', ref_b73_fa, ref_b73_gff) }
    dotplot_pt_in  = oriented_fa.map { sample, fa -> tuple(sample, fa, 'PT',  ref_pt_fa,  ref_pt_gff)  }

    DOTPLOT_MAP_B73(dotplot_b73_in)
    DOTPLOT_MAP_PT(dotplot_pt_in)

    // Collect both dotplot tabs per sample for R plotting
    tab_b73 = DOTPLOT_MAP_B73.out.map { sample, ref_name, tab -> tuple(sample, tab) }
    tab_pt  = DOTPLOT_MAP_PT.out.map  { sample, ref_name, tab -> tuple(sample, tab) }

    plot_in = tab_b73.join(tab_pt)

    DOTPLOT_PLOT(plot_in)

    // 9. AnchorWave whole-genome alignment
    if (params.run_anchorwave) {
        aw_b73_in = oriented_fa.map { sample, fa -> tuple(sample, fa, 'B73', ref_b73_fa, ref_b73_gff) }
        aw_pt_in  = oriented_fa.map { sample, fa -> tuple(sample, fa, 'PT',  ref_pt_fa,  ref_pt_gff)  }

        ANCHORWAVE_B73(aw_b73_in)
        ANCHORWAVE_PT(aw_pt_in)
    }
}
