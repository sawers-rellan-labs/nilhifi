process MERGE_FASTQ {
    tag "${sample}"
    label 'io_task'
    cpus 1
    memory '4 GB'
    time '2h'

    input:
    tuple val(sample), path(barcode1), path(barcode2)

    output:
    tuple val(sample), path("${sample}_merged.fastq.gz")

    script:
    """
    cat ${barcode1} ${barcode2} > ${sample}_merged.fastq.gz
    """
}
