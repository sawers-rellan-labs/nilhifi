process RAGTAG_MERGE {
    tag "${sample}"
    label 'assembly'
    publishDir "${params.outdir}/${sample}/scaffold/merge", mode: 'copy'
    cpus 4
    memory '16 GB'
    time '2h'

    input:
    tuple val(sample), path(query_fa), path(agp_b73), path(agp_pt)

    output:
    tuple val(sample), path("ragtag.merge.fasta"), path("ragtag.merge.agp")

    script:
    """
    ragtag.py merge -u -o merge_out ${query_fa} ${agp_b73} ${agp_pt}
    cp merge_out/ragtag.merge.fasta .
    cp merge_out/ragtag.merge.agp .
    """
}
