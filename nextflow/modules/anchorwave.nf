process ANCHORWAVE {
    tag "${sample}_${ref_name}"
    label 'anchorwave'
    publishDir "${params.outdir}/${sample}/anchorwave/vs_${ref_name}", mode: 'copy'
    cpus 8
    memory '128 GB'
    time '24h'

    input:
    tuple val(sample), path(query_fa), val(ref_name), path(ref_fa), path(ref_gff)

    output:
    tuple val(sample), val(ref_name), path("${sample}_vs_${ref_name}.maf"), path("${sample}_vs_${ref_name}.f.maf"), path("anchors")

    script:
    def fix_pt = ref_name == 'PT' ? "sed 's/^>PT0/>chr/; s/^>PT/>chr/' ${ref_fa} > ref_fixed.fa" : "ln -s ${ref_fa} ref_fixed.fa"
    """
    ${fix_pt}

    anchorwave gff2seq -i ${ref_gff} -r ref_fixed.fa -o cds.fa

    minimap2 -x splice -t ${task.cpus} -k 12 -a -p 0.4 -N 20 \
      ref_fixed.fa cds.fa > ref.sam

    minimap2 -x splice -t ${task.cpus} -k 12 -a -p 0.4 -N 20 \
      ${query_fa} cds.fa > query.sam

    anchorwave proali \
      -i ${ref_gff} \
      -r ref_fixed.fa \
      -as cds.fa \
      -a query.sam \
      -ar ref.sam \
      -s ${query_fa} \
      -n anchors \
      -o ${sample}_vs_${ref_name}.maf \
      -f ${sample}_vs_${ref_name}.f.maf \
      -t ${task.cpus} -R 1 -Q 1
    """
}
