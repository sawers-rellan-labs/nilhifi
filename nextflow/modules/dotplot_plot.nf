process DOTPLOT_PLOT {
    tag "${sample}"
    label 'r_plotting'
    publishDir "${params.outdir}/${sample}/dotplot", mode: 'copy'
    cpus 1
    memory '8 GB'
    time '1h'

    input:
    tuple val(sample), path(tab_b73), path(tab_pt)

    output:
    tuple val(sample), path("*.pdf"), path("*.svg")

    script:
    """
    Rscript ${projectDir}/bin/plot_dotplot.R \
      --sample ${sample} \
      --tab_b73 ${tab_b73} \
      --tab_pt ${tab_pt} \
      --outdir .
    """
}
