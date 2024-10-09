process BAM_SORT {
    tag "$meta.id"
    label 'process_medium'

    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/bwamem2_mem":
        "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-e5d375990341c5aef3c9aff74f96f66f65375ef6:2d15960ccea84e249a150b7f5d4db3a42fc2d6c3-0' :
        'biocontainers/mulled-v2-e5d375990341c5aef3c9aff74f96f66f65375ef6:2d15960ccea84e249a150b7f5d4db3a42fc2d6c3-0' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${meta.id}.sorted.bam") , path("${meta.id}.sorted.bam.bai"), emit: ch_bams

    script:
    """
    /mmfs1/lustre2/BI_Analysis/bi2/anaconda3/envs/bwamem2_mem/bin/samtools sort -@ ${task.cpus} ${bam} -o ${meta.id}.sorted.bam
    wait
    /mmfs1/lustre2/BI_Analysis/bi2/anaconda3/envs/bwamem2_mem/bin/samtools index ${meta.id}.sorted.bam
    """
}
