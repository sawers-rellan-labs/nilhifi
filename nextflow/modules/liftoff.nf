process LIFTOFF {
    tag "${sample}"
    label 'liftoff'
    publishDir "${params.outdir}/${sample}/liftoff", mode: 'copy'
    cpus 8
    memory '32 GB'
    time '6h'

    input:
    tuple val(sample), path(query_fa)
    path ref_fa
    path ref_gff

    output:
    tuple val(sample), path("${sample}_liftoff_B73.gff3"), path("${sample}_unmapped_B73.txt")

    script:
    """
    liftoff \
      -g ${ref_gff} \
      -o ${sample}_liftoff_B73.gff3 \
      -u ${sample}_unmapped_B73.txt \
      -dir intermediate_files \
      -p ${task.cpus} -s 0.5 -a 0.5 -flank 0.1 \
      -cds -copies \
      ${query_fa} ${ref_fa}
    """
}
