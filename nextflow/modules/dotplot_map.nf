process DOTPLOT_MAP {
    tag "${sample}_${ref_name}"
    label 'anchorwave'
    publishDir "${params.outdir}/${sample}/dotplot", mode: 'copy'
    cpus 8
    memory '32 GB'
    time '2h'

    input:
    tuple val(sample), path(query_fa), val(ref_name), path(ref_fa), path(ref_gff)

    output:
    tuple val(sample), val(ref_name), path("dotplot_vs_${ref_name}.tab")

    script:
    def fix_pt = ref_name == 'PT' ? "sed 's/^>PT0/>chr/; s/^>PT/>chr/' ${ref_fa} > ref_fixed.fa" : "ln -s ${ref_fa} ref_fixed.fa"
    """
    ${fix_pt}

    anchorwave gff2seq -i ${ref_gff} -r ref_fixed.fa -o cds.fa

    minimap2 -x splice -t ${task.cpus} -k 12 -a -p 0.4 -N 20 \
      ${query_fa} cds.fa > query.sam

    awk '\$1 ~ /^@/ || \$5 >= 60' query.sam > query_mq60.sam

    perl ${projectDir}/bin/alignmentToDotplot.pl ${ref_gff} query_mq60.sam > dotplot_vs_${ref_name}.tab
    """
}
