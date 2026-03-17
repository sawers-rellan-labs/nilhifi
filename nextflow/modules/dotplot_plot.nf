process DOTPLOT_PLOT {
    tag "${sample}"
    label 'r_plotting'
    publishDir "${params.outdir}/${sample}/dotplot", mode: 'copy'
    cpus 1
    memory '8 GB'
    time '1h'

    input:
    tuple val(sample), path(tab_b73), path(tab_ref2)

    output:
    tuple val(sample), path("*.pdf"), path("*.svg")

    script:
    def ref2_name = (tab_ref2.name =~ /dotplot_vs_(.+)\.tab/)[0][1]
    """
    Rscript ${projectDir}/bin/plot_dotplot.R \
      --sample ${sample} \
      --tab_b73 ${tab_b73} \
      --tab_ref2 ${tab_ref2} \
      --ref2_name ${ref2_name} \
      --outdir .
    """
}
