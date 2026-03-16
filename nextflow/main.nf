#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

// --- Module imports ---
include { MERGE_FASTQ      } from './modules/merge_fastq'
include { HIFIASM           } from './modules/hifiasm'
include { GFA_TO_FASTA      } from './modules/gfa_to_fasta'
include { RAGTAG_SCAFFOLD as RAGTAG_SCAFFOLD_B73  } from './modules/ragtag_scaffold'
include { RAGTAG_SCAFFOLD as RAGTAG_SCAFFOLD_REF2 } from './modules/ragtag_scaffold'
include { RAGTAG_MERGE      } from './modules/ragtag_merge'
include { ORIENT_MERGED_SCAFFOLDS } from './modules/orient_merged_scaffolds'
include { LIFTOFF           } from './modules/liftoff'
include { DOTPLOT_MAP as DOTPLOT_MAP_B73  } from './modules/dotplot_map'
include { DOTPLOT_MAP as DOTPLOT_MAP_REF2 } from './modules/dotplot_map'
include { DOTPLOT_PLOT      } from './modules/dotplot_plot'
include { ANCHORWAVE as ANCHORWAVE_B73  } from './modules/anchorwave'
include { ANCHORWAVE as ANCHORWAVE_REF2 } from './modules/anchorwave'

// --- Build ref2 lookup from samplesheet (Groovy map, not a channel) ---
def ref2_map = new groovy.json.JsonSlurper()  // dummy — built below in workflow

// --- Main workflow ---
workflow {

    // Parse sample sheet into reads channel and ref2 map
    def sheet = file(params.samplesheet).splitCsv(header: true)
    ref2_lookup = sheet.collectEntries { row -> [(row.sample): row.ref2] }

    Channel
        .fromPath(params.samplesheet)
        .splitCsv(header: true)
        .map { row -> tuple(row.sample, file(row.barcode1), file(row.barcode2)) }
        .set { samples_ch }

    // B73 reference (global, same for all samples)
    ref_b73_fa  = file(params.refs.B73.fa)
    ref_b73_gff = file(params.refs.B73.gff)

    // 1. Merge barcodes
    MERGE_FASTQ(samples_ch)

    // 2. De novo assembly
    HIFIASM(MERGE_FASTQ.out)

    // 3. GFA → FASTA
    GFA_TO_FASTA(HIFIASM.out.gfa)

    // 4. Scaffold against B73 (global) and ref2 (per-sample)
    scaffold_b73_in = GFA_TO_FASTA.out.map { sample, fa ->
        tuple(sample, fa, 'B73', ref_b73_fa)
    }

    scaffold_ref2_in = GFA_TO_FASTA.out.map { sample, fa ->
        def r2 = ref2_lookup[sample]
        tuple(sample, fa, r2, file(params.refs[r2].fa))
    }

    RAGTAG_SCAFFOLD_B73(scaffold_b73_in)
    RAGTAG_SCAFFOLD_REF2(scaffold_ref2_in)

    // 5. Merge scaffoldings
    b73_scaffold  = RAGTAG_SCAFFOLD_B73.out.map  { sample, ref_name, agp, fasta -> tuple(sample, agp, fasta) }
    ref2_scaffold = RAGTAG_SCAFFOLD_REF2.out.map { sample, ref_name, agp, fasta -> tuple(sample, agp, fasta) }

    merge_in = GFA_TO_FASTA.out
        .join(b73_scaffold)
        .join(ref2_scaffold)

    RAGTAG_MERGE(merge_in)

    // 6. Orient scaffolds to B73 convention, rename to chr1..chr10, sort
    ORIENT_MERGED_SCAFFOLDS(RAGTAG_MERGE.out, ref_b73_fa, ref_b73_gff)

    // Oriented FASTA for all downstream steps: [sample, oriented_fasta]
    oriented_fa = ORIENT_MERGED_SCAFFOLDS.out.map { sample, fasta, table -> tuple(sample, fasta) }

    // 7. Liftoff (B73 annotations → query)
    LIFTOFF(oriented_fa, ref_b73_fa, ref_b73_gff)

    // 8. CDS-based dotplots (B73 and ref2, in parallel)
    dotplot_b73_in = oriented_fa.map { sample, fa ->
        tuple(sample, fa, 'B73', ref_b73_fa, ref_b73_gff)
    }

    dotplot_ref2_in = oriented_fa.map { sample, fa ->
        def r2 = ref2_lookup[sample]
        tuple(sample, fa, r2, file(params.refs[r2].fa), file(params.refs[r2].gff))
    }

    DOTPLOT_MAP_B73(dotplot_b73_in)
    DOTPLOT_MAP_REF2(dotplot_ref2_in)

    // Collect both dotplot tabs per sample for R plotting
    tab_b73  = DOTPLOT_MAP_B73.out.map  { sample, ref_name, tab -> tuple(sample, tab) }
    tab_ref2 = DOTPLOT_MAP_REF2.out.map { sample, ref_name, tab -> tuple(sample, tab) }

    plot_in = tab_b73.join(tab_ref2)

    DOTPLOT_PLOT(plot_in)

    // 9. AnchorWave whole-genome alignment
    if (params.run_anchorwave) {
        aw_b73_in = oriented_fa.map { sample, fa ->
            tuple(sample, fa, 'B73', ref_b73_fa, ref_b73_gff)
        }

        aw_ref2_in = oriented_fa.map { sample, fa ->
            def r2 = ref2_lookup[sample]
            tuple(sample, fa, r2, file(params.refs[r2].fa), file(params.refs[r2].gff))
        }

        ANCHORWAVE_B73(aw_b73_in)
        ANCHORWAVE_REF2(aw_ref2_in)
    }
}
