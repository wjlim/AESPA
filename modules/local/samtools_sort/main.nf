process BAM_SORT {
    tag "${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    label 'process_medium'

    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/bwamem2_mem":
        "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${meta.id}.sorted.bam") , path("${meta.id}.sorted.bam.bai"), emit: ch_sorted_bams

    script:
    """
    /mmfs1/lustre2/BI_Analysis/bi2/anaconda3/envs/bwamem2_mem/bin/samtools sort -@ ${task.cpus} ${bam} -o ${meta.id}.sorted.bam
    wait
    /mmfs1/lustre2/BI_Analysis/bi2/anaconda3/envs/bwamem2_mem/bin/samtools index ${meta.id}.sorted.bam
    """
}
