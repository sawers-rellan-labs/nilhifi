process RAGTAG_MERGE {
    tag "${sample}"
    label 'assembly'
    publishDir "${params.outdir}/${sample}/scaffold/merge", mode: 'copy'
    cpus 4
    memory '16 GB'
    time '2h'

    input:
    tuple val(sample), path(query_fa),
          path('scaffold_B73/ragtag.scaffold.agp'), path('scaffold_B73/ragtag.scaffold.fasta'),
          path('scaffold_PT/ragtag.scaffold.agp'),  path('scaffold_PT/ragtag.scaffold.fasta')

    output:
    tuple val(sample), path("ragtag.merge.fasta"), path("ragtag.merge.agp")

    script:
    """
    ragtag.py merge -u -o merge_out ${query_fa} scaffold_B73 scaffold_PT
    cp merge_out/ragtag.merge.fasta .
    cp merge_out/ragtag.merge.agp .
    """
}
