process RAGTAG_SCAFFOLD {
    tag "${sample}_${ref_name}"
    label 'assembly'
    publishDir "${params.outdir}/${sample}/scaffold/${ref_name}", mode: 'copy'
    cpus 8
    memory '128 GB'
    time '8h'

    input:
    tuple val(sample), path(query_fa), val(ref_name), path(ref_fa)

    output:
    tuple val(sample), val(ref_name), path("ragtag.scaffold.agp"), path("ragtag.scaffold.fasta")

    script:
    """
    ragtag.py scaffold -u -t ${task.cpus} -o scaffold_out ${ref_fa} ${query_fa}
    cp scaffold_out/ragtag.scaffold.agp .
    cp scaffold_out/ragtag.scaffold.fasta .
    """
}
