process ORIENT_MERGED_SCAFFOLDS {
    tag "${sample}"
    label 'anchorwave'
    publishDir "${params.outdir}/${sample}/scaffold/oriented", mode: 'copy'
    cpus 8
    memory '32 GB'
    time '2h'

    input:
    tuple val(sample), path(merge_fa), path(merge_agp)
    path ref_b73_fa
    path ref_b73_gff

    output:
    tuple val(sample), path("${sample}.oriented.fa"), path("scaffold_correspondence.tsv")

    script:
    """
    # 1. Extract B73 CDS anchors
    anchorwave gff2seq -i ${ref_b73_gff} -r ${ref_b73_fa} -o b73_cds.fa

    # 2. Map CDS to merged assembly, filter MAPQ>=60
    minimap2 -x splice -t ${task.cpus} -k 12 -a -p 0.4 -N 20 \
      ${merge_fa} b73_cds.fa > query.sam

    awk '\$1 ~ /^@/ || \$5 >= 60' query.sam > query_mq60.sam

    # 3. Generate dotplot.tab (refChr, refPos, scaffold, queryPos, strand)
    perl ${projectDir}/bin/alignmentToDotplot.pl ${ref_b73_gff} query_mq60.sam > dotplot.tab

    # 4. Orient, rename, and sort scaffolds based on B73 correspondence
    python3 ${projectDir}/bin/orient_scaffolds.py \
      --tab dotplot.tab \
      --fasta ${merge_fa} \
      --sample ${sample} \
      --out-fasta ${sample}.oriented.fa \
      --out-table scaffold_correspondence.tsv
    """
}
