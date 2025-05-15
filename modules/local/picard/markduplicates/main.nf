process MARK_DUP {
    tag "MARK duplicates for ${meta.id}"
    label 'process_medium'

    conda (params.conda_env_path ?
        "${params.conda_env_path}/picard_env":
        "${moduleDir}/environment.yml"
    )

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${meta.id}_sorted.bam"), path("${meta.id}_sorted.bai"), emit: ch_dedup_bams
    tuple val(meta), path("*_metrics.txt"), emit: ch_metrics

    script:
    def avail_mem = 3
    if (!task.memory) {
        log.info '[Picard MarkDuplicates] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = task.memory.toGiga()
    }
    """
    picard MarkDuplicates \\
        -Xmx${avail_mem}g \\
        INPUT=${bam} \\
        OUTPUT=${meta.id}_sorted.bam \\
        METRICS_FILE=${meta.id}_metrics.txt \\
        CREATE_INDEX=true \\
        VALIDATION_STRINGENCY=LENIENT \\
        REMOVE_DUPLICATES=false
    """
}
