process BWAMEM2_MEM {
    tag "BWAMEM2 aligning for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    label 'process_medium'

    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/bwamem2_mem":
        "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-e5d375990341c5aef3c9aff74f96f66f65375ef6:2d15960ccea84e249a150b7f5d4db3a42fc2d6c3-0' :
        'biocontainers/mulled-v2-e5d375990341c5aef3c9aff74f96f66f65375ef6:2d15960ccea84e249a150b7f5d4db3a42fc2d6c3-0' }"

    input:
    tuple val(meta), path(forward), path(reverse), path(index), path(fasta)

    output:
    tuple val(meta), path("${meta.id}.bam") , emit: ch_bam

    script:
    """
    bwa-mem2 \\
        mem \\
        -t ${task.cpus} \\
        -K 1000000 \\
        -R "@RG\tID:${meta.id}\tSM:${meta.id}" \\
        ${index}/genome.fa \\
        ${forward} ${reverse} \\
        | grep -v ^"@PG"|/mmfs1/lustre2/BI_Analysis/bi2/anaconda3/envs/bwamem2_mem/bin/samtools sort -@ ${task.cpus} > ${meta.id}.bam
    """
}