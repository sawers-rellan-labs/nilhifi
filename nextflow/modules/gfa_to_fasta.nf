process GFA_TO_FASTA {
    tag "${sample}"
    label 'io_task'
    publishDir "${params.outdir}/${sample}/assembly", mode: 'copy'
    cpus 1
    memory '4 GB'
    time '30m'

    input:
    tuple val(sample), path(gfa)

    output:
    tuple val(sample), path("${sample}.p_ctg.fa")

    script:
    """
    awk '/^S/{print ">"\$2; print \$3}' ${gfa} > ${sample}.p_ctg.fa
    """
}
