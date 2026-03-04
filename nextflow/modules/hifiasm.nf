process HIFIASM {
    tag "${sample}"
    label 'assembly'
    publishDir "${params.outdir}/${sample}/assembly", mode: 'copy'
    cpus 16
    memory '64 GB'
    time '16h'

    input:
    tuple val(sample), path(merged_fastq)

    output:
    tuple val(sample), path("${sample}_asm.bp.p_ctg.gfa"), emit: gfa
    tuple val(sample), path("${sample}_asm.bp.a_ctg.gfa"), emit: alt_gfa

    script:
    """
    hifiasm -o ${sample}_asm -t ${task.cpus} -l0 ${merged_fastq}
    """
}
