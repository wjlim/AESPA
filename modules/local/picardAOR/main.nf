process picard_add_or_replace_read_group {
    tag "${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    label "process_small"
    
    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("${meta.id}.AOR.bam"), emit:ch_picard_AOR_bam

    """
    picard -Xmx16G \\
        AddOrReplaceReadGroups \\
        --INPUT ${bam} \\
        --OUTPUT ${meta.id}.AOR.bam \\
        --RGLB ${meta.id} \\
        --RGPL ILLUMINA \\
        --RGPU ${meta.order} \\
        --RGSM ${meta.sample}
    """
}