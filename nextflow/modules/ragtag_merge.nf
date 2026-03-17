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
    if (params.skip_merge_samples?.contains(sample))
    """
    echo "Skipping merge for ${sample} — using B73-only scaffold"
    cp scaffold_B73/ragtag.scaffold.fasta ragtag.merge.fasta
    cp scaffold_B73/ragtag.scaffold.agp ragtag.merge.agp
    """
    else
    """
    ragtag.py merge -u -o merge_out ${query_fa} scaffold_B73/ragtag.scaffold.agp scaffold_PT/ragtag.scaffold.agp
    cp merge_out/ragtag.merge.fasta .
    cp merge_out/ragtag.merge.agp .
    """
}
